-- Veny: functions and triggers.
-- Rules for every SECURITY DEFINER function (RLS_AUTHORIZATION.md §8):
--   * set search_path = '' and fully qualified names
--   * explicit auth.uid() check; never trust a user id passed as a parameter
--   * EXECUTE granted explicitly in the RLS migration (revoked from public by default)
-- Errors use stable SQLSTATE + HINT codes, mapped by lib/errors.ts (API_DOCUMENTATION.md B3):
--   42501/unauthenticated, P0002/not_found, P0001/<rule>, 22023/<invalid_param>, 23505/<conflict>

-- ===========================================================================
-- Generic helpers (private schema: not exposed through the Data API)
-- ===========================================================================
create function private.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end $$;

create function private.slugify(p_text text)
returns text language sql immutable set search_path = '' as $$
  select left(trim(both '-' from regexp_replace(lower(coalesce(p_text, '')), '[^a-z0-9]+', '-', 'g')), 60);
$$;

-- Returns p_base slugified, with a short random suffix when the slug is already taken.
create function private.unique_slug(p_table regclass, p_base text, p_fallback text)
returns text language plpgsql volatile set search_path = '' as $$
declare
  v_base   text := coalesce(nullif(private.slugify(p_base), ''), p_fallback);
  v_slug   text := v_base;
  v_exists boolean;
begin
  loop
    execute format('select exists (select 1 from %s where slug = $1)', p_table) into v_exists using v_slug;
    exit when not v_exists;
    v_slug := v_base || '-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 6);
  end loop;
  return v_slug;
end $$;

-- Unambiguous uppercase code for booking references (no 0/O, 1/I).
create function private.random_code(p_len int)
returns text language plpgsql volatile set search_path = '' as $$
declare
  v_alphabet constant text := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  v_out text := '';
begin
  for i in 1..p_len loop
    v_out := v_out || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
  end loop;
  return v_out;
end $$;

-- ===========================================================================
-- Authorization helpers used by RLS policies
-- ===========================================================================
create function private.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.admin_users a where a.profile_id = (select auth.uid()));
$$;

-- True when the caller has a vendors row that is not suspended.
create function private.is_vendor()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.vendors v
                 where v.profile_id = (select auth.uid()) and v.status <> 'suspended');
$$;

create function private.owns_service(p_service_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.services s
                 where s.id = p_service_id and s.vendor_id = (select auth.uid()) and s.deleted_at is null);
$$;

-- Storage path convention for service images: {vendor_id}/{service_id}/{file}
create function private.owns_service_image_path(p_name text)
returns boolean language plpgsql stable security definer set search_path = '' as $$
declare
  v_parts text[] := string_to_array(p_name, '/');
begin
  if array_length(v_parts, 1) <> 3
     or v_parts[1] <> (select auth.uid())::text
     or v_parts[2] !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return false;
  end if;
  return private.owns_service(v_parts[2]::uuid);
end $$;

create function private.notify(p_user uuid, p_type public.notification_type, p_title text,
                               p_body text, p_link text, p_booking uuid)
returns void language sql security definer set search_path = '' as $$
  insert into public.notifications (user_id, type, title, body, link, booking_id)
  values (p_user, p_type, left(p_title, 120), left(p_body, 1000), p_link, p_booking);
$$;

-- ===========================================================================
-- Sign-up: create profile (+ vendor row). PD-04: users may choose vendor.
-- Only 'customer' and 'vendor' are accepted; anything else falls back to customer.
-- This trigger can never create an admin.
-- ===========================================================================
create function private.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_meta  jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_role  public.user_role := case when v_meta ->> 'role' = 'vendor' then 'vendor' else 'customer' end;
  v_name  text := left(btrim(coalesce(v_meta ->> 'full_name', '')), 80);
  v_bname text := left(btrim(coalesce(v_meta ->> 'business_name', '')), 100);
begin
  if char_length(v_name) < 2 then v_name := 'Veny user'; end if;
  insert into public.profiles (id, role, full_name) values (new.id, v_role, v_name);
  if v_role = 'vendor' then
    if char_length(v_bname) < 2 then v_bname := v_name; end if;
    insert into public.vendors (profile_id, business_name) values (new.id, v_bname);
  end if;
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- ===========================================================================
-- profiles
-- ===========================================================================
-- Second layer behind the column privilege: API roles can never change the role.
create function private.guard_profile_role()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.role is distinct from old.role and current_user in ('authenticated', 'anon') then
    raise exception 'The role cannot be changed' using errcode = '42501', hint = 'role_immutable';
  end if;
  return new;
end $$;

create trigger profiles_guard_role before update on public.profiles
  for each row execute function private.guard_profile_role();
create trigger profiles_set_updated_at before update on public.profiles
  for each row execute function private.set_updated_at();

-- ===========================================================================
-- vendors
-- ===========================================================================
-- SECURITY INVOKER on purpose: current_user must reflect the API role for the status guard.
create function private.vendors_before_write()
returns trigger language plpgsql set search_path = '' as $$
begin
  if not exists (select 1 from public.profiles p where p.id = new.profile_id and p.role = 'vendor') then
    raise exception 'Profile is not a vendor' using errcode = 'P0001', hint = 'not_a_vendor';
  end if;
  if tg_op = 'INSERT' and new.slug is null then
    new.slug := private.unique_slug('public.vendors'::regclass, new.business_name, 'vendor');
  end if;
  if current_user in ('authenticated', 'anon') and tg_op = 'UPDATE'
     and (new.status is distinct from old.status or new.verified_at is distinct from old.verified_at) then
    raise exception 'Vendor status is admin-only' using errcode = '42501', hint = 'admin_only';
  end if;
  return new;
end $$;

create trigger vendors_before_write before insert or update on public.vendors
  for each row execute function private.vendors_before_write();
create trigger vendors_set_updated_at before update on public.vendors
  for each row execute function private.set_updated_at();

-- ===========================================================================
-- services
-- ===========================================================================
create function private.services_before_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.slug is null then
    new.slug := private.unique_slug('public.services'::regclass, new.title, 'service');
  end if;
  if new.location is null then
    select v.base_location into new.location from public.vendors v where v.profile_id = new.vendor_id;
    if new.location is null then
      raise exception 'Set a service location or a vendor base location first'
        using errcode = '22023', hint = 'location_required';
    end if;
  end if;
  return new;
end $$;

create trigger services_before_insert before insert on public.services
  for each row execute function private.services_before_insert();
create trigger services_set_updated_at before update on public.services
  for each row execute function private.set_updated_at();

create function public.soft_delete_service(p_service_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '42501', hint = 'unauthenticated';
  end if;
  update public.services
     set deleted_at = now(), is_active = false
   where id = p_service_id and vendor_id = v_uid and deleted_at is null;
  if not found then
    raise exception 'Service not found' using errcode = 'P0002', hint = 'not_found';
  end if;
end $$;

-- ===========================================================================
-- addresses, reviews, notifications: updated_at
-- ===========================================================================
create trigger addresses_set_updated_at before update on public.addresses
  for each row execute function private.set_updated_at();
create trigger reviews_set_updated_at before update on public.reviews
  for each row execute function private.set_updated_at();

-- ===========================================================================
-- bookings
-- ===========================================================================
-- Status may only change inside transition_booking (SECURITY DEFINER, runs as owner).
create function private.guard_booking_status()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user in ('authenticated', 'anon') then
    raise exception 'Use transition_booking to change a booking' using errcode = '42501', hint = 'rpc_only';
  end if;
  return new;
end $$;

create trigger bookings_guard_status before update on public.bookings
  for each row execute function private.guard_booking_status();
create trigger bookings_set_updated_at before update on public.bookings
  for each row execute function private.set_updated_at();

create function public.create_booking(p_service_id uuid, p_scheduled_at timestamptz,
                                      p_address_id uuid, p_notes text default null)
returns public.bookings language plpgsql security definer set search_path = '' as $$
declare
  v_uid     uuid := auth.uid();
  v_service public.services;
  v_vstatus public.vendor_status;
  v_addr    public.addresses;
  v_booking public.bookings;
  v_ref     text;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '42501', hint = 'unauthenticated';
  end if;
  if p_scheduled_at is null or p_scheduled_at < now() + interval '1 hour' then
    raise exception 'Choose a time at least 1 hour from now' using errcode = '22023', hint = 'schedule_too_soon';
  end if;
  if p_scheduled_at > now() + interval '180 days' then
    raise exception 'Choose a time within the next 180 days' using errcode = '22023', hint = 'schedule_too_far';
  end if;

  select * into v_service from public.services where id = p_service_id;
  if not found then
    raise exception 'Service not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  select status into v_vstatus from public.vendors where profile_id = v_service.vendor_id;
  if not v_service.is_active or v_service.deleted_at is not null or v_service.hidden_at is not null
     or v_vstatus = 'suspended' then
    raise exception 'This service is not available' using errcode = 'P0001', hint = 'service_unavailable';
  end if;
  if v_service.vendor_id = v_uid then
    raise exception 'You cannot book your own service' using errcode = 'P0001', hint = 'own_service';
  end if;

  select * into v_addr from public.addresses where id = p_address_id and profile_id = v_uid;
  if not found then
    raise exception 'Address not found' using errcode = 'P0002', hint = 'address_not_found';
  end if;

  loop
    v_ref := 'VNY-' || private.random_code(6);
    exit when not exists (select 1 from public.bookings where reference = v_ref);
  end loop;

  insert into public.bookings (reference, service_id, customer_id, vendor_id, scheduled_at, customer_notes,
                               address_snapshot, address_location, price_paise, currency)
  values (v_ref, v_service.id, v_uid, v_service.vendor_id, p_scheduled_at, nullif(btrim(p_notes), ''),
          jsonb_build_object('label', v_addr.label, 'line1', v_addr.line1, 'line2', v_addr.line2,
                             'area', v_addr.area, 'city', v_addr.city, 'state', v_addr.state,
                             'postal_code', v_addr.postal_code, 'country_code', v_addr.country_code,
                             'location_source', v_addr.location_source),
          v_addr.location, v_service.price_paise, v_service.currency)
  returning * into v_booking;

  insert into public.booking_status_history (booking_id, from_status, to_status, changed_by)
  values (v_booking.id, null, 'pending', v_uid);

  perform private.notify(v_service.vendor_id, 'booking_new', 'New booking request',
                         format('Booking %s for "%s".', v_booking.reference, v_service.title),
                         '/dashboard/vendor/bookings/' || v_booking.id, v_booking.id);
  return v_booking;
end $$;

-- Transition table (DATABASE_ARCHITECTURE.md §5):
--   pending     -> confirmed    vendor
--   pending     -> cancelled    customer, vendor (reason required), admin (reason required)
--   confirmed   -> in_progress  vendor
--   confirmed   -> cancelled    customer, vendor (reason required), admin (reason required)
--   in_progress -> completed    vendor
--   in_progress -> cancelled    admin only (reason required)          [PD-13 option b]
create function public.transition_booking(p_booking_id uuid, p_to public.booking_status,
                                          p_reason text default null)
returns public.bookings language plpgsql security definer set search_path = '' as $$
declare
  v_uid    uuid := auth.uid();
  v_old    public.bookings;
  v_new    public.bookings;
  v_actor  text;
  v_reason text := nullif(btrim(p_reason), '');
  v_title  text;
  v_cust_link text;
  v_vend_link text;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '42501', hint = 'unauthenticated';
  end if;

  select * into v_old from public.bookings where id = p_booking_id for update;
  if not found then
    raise exception 'Booking not found' using errcode = 'P0002', hint = 'not_found';
  end if;

  if v_uid = v_old.vendor_id then v_actor := 'vendor';
  elsif v_uid = v_old.customer_id then v_actor := 'customer';
  elsif private.is_admin() then v_actor := 'admin';
  else
    -- Same error as a missing row, so booking ids cannot be probed.
    raise exception 'Booking not found' using errcode = 'P0002', hint = 'not_found';
  end if;

  if not (
       (v_old.status = 'pending'     and p_to = 'confirmed'   and v_actor = 'vendor')
    or (v_old.status = 'pending'     and p_to = 'cancelled'   and v_actor in ('customer', 'vendor', 'admin'))
    or (v_old.status = 'confirmed'   and p_to = 'in_progress' and v_actor = 'vendor')
    or (v_old.status = 'confirmed'   and p_to = 'cancelled'   and v_actor in ('customer', 'vendor', 'admin'))
    or (v_old.status = 'in_progress' and p_to = 'completed'   and v_actor = 'vendor')
    or (v_old.status = 'in_progress' and p_to = 'cancelled'   and v_actor = 'admin')
  ) then
    raise exception 'Cannot change this booking from % to %', v_old.status, p_to
      using errcode = 'P0001', hint = 'invalid_transition';
  end if;

  if p_to = 'cancelled' and v_actor in ('vendor', 'admin') and v_reason is null then
    raise exception 'A reason is required to cancel' using errcode = '22023', hint = 'reason_required';
  end if;

  update public.bookings set
    status        = p_to,
    confirmed_at  = case when p_to = 'confirmed'   then now() else confirmed_at end,
    started_at    = case when p_to = 'in_progress' then now() else started_at end,
    completed_at  = case when p_to = 'completed'   then now() else completed_at end,
    cancelled_at  = case when p_to = 'cancelled'   then now() else cancelled_at end,
    cancelled_by  = case when p_to = 'cancelled'   then v_uid else cancelled_by end,
    cancel_reason = case when p_to = 'cancelled'   then v_reason else cancel_reason end
  where id = p_booking_id
  returning * into v_new;

  insert into public.booking_status_history (booking_id, from_status, to_status, changed_by, reason)
  values (p_booking_id, v_old.status, p_to, v_uid, v_reason);

  select s.title into v_title from public.services s where s.id = v_new.service_id;
  v_cust_link := '/dashboard/customer/bookings/' || v_new.id;
  v_vend_link := '/dashboard/vendor/bookings/' || v_new.id;

  if p_to = 'confirmed' then
    perform private.notify(v_new.customer_id, 'booking_confirmed', 'Booking confirmed',
      format('Your booking %s for "%s" is confirmed.', v_new.reference, v_title), v_cust_link, v_new.id);
  elsif p_to = 'in_progress' then
    perform private.notify(v_new.customer_id, 'booking_in_progress', 'Work has started',
      format('Booking %s for "%s" is in progress.', v_new.reference, v_title), v_cust_link, v_new.id);
  elsif p_to = 'completed' then
    perform private.notify(v_new.customer_id, 'booking_completed', 'Booking completed',
      format('Booking %s for "%s" is complete. You can now leave a review.', v_new.reference, v_title),
      v_cust_link, v_new.id);
  elsif p_to = 'cancelled' then
    if v_actor <> 'customer' then
      perform private.notify(v_new.customer_id, 'booking_cancelled', 'Booking cancelled',
        format('Booking %s for "%s" was cancelled.', v_new.reference, v_title), v_cust_link, v_new.id);
    end if;
    if v_actor <> 'vendor' then
      perform private.notify(v_new.vendor_id, 'booking_cancelled', 'Booking cancelled',
        format('Booking %s for "%s" was cancelled.', v_new.reference, v_title), v_vend_link, v_new.id);
    end if;
  end if;

  if v_actor = 'admin' then
    insert into public.admin_audit_log (actor_id, action, target_table, target_id, before, after, note)
    values (v_uid, 'booking.cancel', 'bookings', v_new.id::text,
            jsonb_build_object('status', v_old.status), jsonb_build_object('status', v_new.status), v_reason);
  end if;

  return v_new;
end $$;

-- Contact details only for participants, only while the job is active (RLS_AUTHORIZATION.md §5).
create function public.get_booking_contact(p_booking_id uuid)
returns table (name text, phone_e164 text, whatsapp_e164 text, email text)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := auth.uid();
  v_b   public.bookings;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '42501', hint = 'unauthenticated';
  end if;
  select * into v_b from public.bookings b where b.id = p_booking_id;
  if not found or v_uid not in (v_b.customer_id, v_b.vendor_id) then
    raise exception 'Booking not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if v_b.status not in ('confirmed', 'in_progress') then
    raise exception 'Contact details are shared only for confirmed or in-progress bookings'
      using errcode = 'P0001', hint = 'contact_unavailable';
  end if;

  if v_uid = v_b.customer_id then
    return query
      select v.business_name, p.phone_e164, v.whatsapp_e164, u.email::text
        from public.vendors v
        join public.profiles p on p.id = v.profile_id
        join auth.users u on u.id = v.profile_id
       where v.profile_id = v_b.vendor_id;
  else
    return query
      select p.full_name, p.phone_e164, null::text, u.email::text
        from public.profiles p
        join auth.users u on u.id = p.id
       where p.id = v_b.customer_id;
  end if;
end $$;

-- ===========================================================================
-- reviews
-- ===========================================================================
create function private.recalc_service_rating()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_ids uuid[];
begin
  if tg_op = 'DELETE' then v_ids := array[old.service_id];
  elsif tg_op = 'UPDATE' then v_ids := array[old.service_id, new.service_id];
  else v_ids := array[new.service_id];
  end if;

  update public.services s set
    avg_rating   = coalesce((select round(avg(r.rating)::numeric, 1) from public.reviews r
                             where r.service_id = s.id and not r.is_hidden), 0),
    review_count = (select count(*) from public.reviews r where r.service_id = s.id and not r.is_hidden)
  where s.id = any (v_ids);
  return null;
end $$;

create trigger reviews_recalc_rating
  after insert or delete or update of rating, is_hidden, service_id on public.reviews
  for each row execute function private.recalc_service_rating();

create function public.create_review(p_booking_id uuid, p_rating int, p_comment text default null)
returns public.reviews language plpgsql security definer set search_path = '' as $$
declare
  v_uid    uuid := auth.uid();
  v_b      public.bookings;
  v_name   text;
  v_author text;
  v_review public.reviews;
  v_title  text;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '42501', hint = 'unauthenticated';
  end if;
  if p_rating is null or p_rating not between 1 and 5 then
    raise exception 'Rating must be between 1 and 5' using errcode = '22023', hint = 'invalid_rating';
  end if;

  select * into v_b from public.bookings where id = p_booking_id for update;
  if not found or v_b.customer_id <> v_uid then
    raise exception 'Only the customer of a completed booking can review it'
      using errcode = 'P0001', hint = 'not_eligible';
  end if;
  if v_b.status <> 'completed' then
    raise exception 'Only completed bookings can be reviewed' using errcode = 'P0001', hint = 'not_eligible';
  end if;
  if exists (select 1 from public.reviews where booking_id = p_booking_id) then
    raise exception 'This booking has already been reviewed' using errcode = '23505', hint = 'already_reviewed';
  end if;

  -- Public display name: first name + last initial ("Asha K."). Customer profiles stay private.
  select p.full_name into v_name from public.profiles p where p.id = v_uid;
  v_author := split_part(btrim(v_name), ' ', 1);
  if position(' ' in btrim(v_name)) > 0 then
    v_author := v_author || ' ' || upper(left(regexp_replace(btrim(v_name), '^.*\s', ''), 1)) || '.';
  end if;

  insert into public.reviews (booking_id, service_id, customer_id, author_name, rating, comment)
  values (v_b.id, v_b.service_id, v_uid, left(v_author, 40), p_rating, nullif(btrim(p_comment), ''))
  returning * into v_review;

  select s.title into v_title from public.services s where s.id = v_b.service_id;
  perform private.notify(v_b.vendor_id, 'review_new', 'New review',
                         format('%s-star review on "%s".', p_rating, v_title),
                         '/dashboard/vendor/reviews', v_b.id);
  return v_review;
end $$;

-- ===========================================================================
-- notifications
-- ===========================================================================
create function public.mark_notifications_read(p_ids uuid[] default null)
returns integer language plpgsql security invoker set search_path = '' as $$
declare
  v_count integer;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '42501', hint = 'unauthenticated';
  end if;
  update public.notifications
     set read_at = now()
   where user_id = (select auth.uid()) and read_at is null
     and (p_ids is null or id = any (p_ids));
  get diagnostics v_count = row_count;
  return v_count;
end $$;

-- ===========================================================================
-- Vendor self-service: private fields not covered by the public column grant
-- ===========================================================================
create function public.get_my_vendor()
returns table (profile_id uuid, business_name text, slug text, whatsapp_e164 text, bio text, logo_path text,
               lng float8, lat float8, service_radius_m integer, status public.vendor_status,
               verified_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select v.profile_id, v.business_name, v.slug, v.whatsapp_e164, v.bio, v.logo_path,
         extensions.st_x(v.base_location::extensions.geometry), extensions.st_y(v.base_location::extensions.geometry),
         v.service_radius_m, v.status, v.verified_at
    from public.vendors v
   where v.profile_id = (select auth.uid());
$$;

-- ===========================================================================
-- Search (SECURITY INVOKER: RLS applies). Fixes SEC-03, BUG-04, F-02.
-- Returns the storage path of the cover image; the client builds the public URL.
-- ===========================================================================
create function public.search_services(
  p_q text default null, p_category text default null,
  p_min_paise int default null, p_max_paise int default null,
  p_lng float8 default null, p_lat float8 default null, p_radius_m int default 10000,
  p_sort text default 'newest', p_limit int default 20, p_offset int default 0)
returns table (id uuid, slug text, title text, price_paise integer, currency char(3), avg_rating numeric,
               review_count integer, duration_minutes integer, category_slug text, vendor_name text,
               vendor_slug text, vendor_status public.vendor_status, cover_path text,
               distance_m float8, total_count bigint)
language plpgsql stable security invoker set search_path = '' as $$
#variable_conflict use_column
declare
  v_limit  int  := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_offset int  := least(greatest(coalesce(p_offset, 0), 0), 10000);
  v_radius int  := least(greatest(coalesce(p_radius_m, 10000), 100), 50000);
  v_sort   text := coalesce(p_sort, 'newest');
  v_point  extensions.geography;
  v_q      tsquery;
begin
  if v_sort not in ('newest', 'price_asc', 'price_desc', 'rating', 'distance') then
    raise exception 'Unknown sort' using errcode = '22023', hint = 'invalid_sort';
  end if;
  if (p_lng is null) <> (p_lat is null) then
    raise exception 'Provide both longitude and latitude' using errcode = '22023', hint = 'invalid_location';
  end if;
  if p_lng is not null then
    if p_lng not between -180 and 180 or p_lat not between -90 and 90 then
      raise exception 'Invalid coordinates' using errcode = '22023', hint = 'invalid_location';
    end if;
    v_point := extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography;
  elsif v_sort = 'distance' then
    raise exception 'Distance sort needs a location' using errcode = '22023', hint = 'invalid_location';
  end if;
  if p_min_paise is not null and p_max_paise is not null and p_min_paise > p_max_paise then
    raise exception 'Minimum price is above maximum price' using errcode = '22023', hint = 'invalid_price_range';
  end if;
  if nullif(btrim(p_q), '') is not null then
    v_q := websearch_to_tsquery('simple'::regconfig, left(p_q, 200));
  end if;

  return query
  select s.id, s.slug, s.title, s.price_paise, s.currency, s.avg_rating, s.review_count, s.duration_minutes,
         c.slug, v.business_name, v.slug, v.status,
         (select si.storage_path from public.service_images si
           where si.service_id = s.id order by si.position limit 1),
         case when v_point is null then null else extensions.st_distance(s.location, v_point) end,
         count(*) over ()
    from public.services s
    join public.categories c on c.id = s.category_id
    join public.vendors v on v.profile_id = s.vendor_id
   where s.is_active and s.deleted_at is null and s.hidden_at is null
     and v.status <> 'suspended' and c.is_active
     and (p_category is null or c.slug = p_category)
     and (v_q is null or s.search_tsv @@ v_q)
     and (p_min_paise is null or s.price_paise >= p_min_paise)
     and (p_max_paise is null or s.price_paise <= p_max_paise)
     and (v_point is null or extensions.st_dwithin(s.location, v_point, v_radius))
   order by
     case when v_sort = 'distance'   then extensions.st_distance(s.location, v_point) end asc,
     case when v_sort = 'price_asc'  then s.price_paise end asc,
     case when v_sort = 'price_desc' then s.price_paise end desc,
     case when v_sort = 'rating'     then s.avg_rating end desc,
     s.created_at desc, s.id
   limit v_limit offset v_offset;
end $$;

-- ===========================================================================
-- Admin RPCs (PD-13 option b). Each checks is_admin() and writes admin_audit_log.
-- Admins cannot change roles, grant admin, or edit other users' content.
-- ===========================================================================
create function private.require_admin()
returns uuid language plpgsql stable security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '42501', hint = 'unauthenticated';
  end if;
  if not private.is_admin() then
    raise exception 'Admin only' using errcode = '42501', hint = 'admin_only';
  end if;
  return v_uid;
end $$;

create function public.admin_set_vendor_status(p_vendor_id uuid, p_status public.vendor_status,
                                               p_note text default null)
returns public.vendor_status language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := private.require_admin();
  v_old public.vendor_status;
begin
  select status into v_old from public.vendors where profile_id = p_vendor_id for update;
  if not found then
    raise exception 'Vendor not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if p_status = 'suspended' and nullif(btrim(p_note), '') is null then
    raise exception 'A note is required to suspend a vendor' using errcode = '22023', hint = 'reason_required';
  end if;
  update public.vendors
     set status = p_status,
         verified_at = case when p_status = 'verified' then now()
                            when p_status = 'unverified' then null
                            else verified_at end
   where profile_id = p_vendor_id;
  insert into public.admin_audit_log (actor_id, action, target_table, target_id, before, after, note)
  values (v_uid, 'vendor.set_status', 'vendors', p_vendor_id::text,
          jsonb_build_object('status', v_old), jsonb_build_object('status', p_status), nullif(btrim(p_note), ''));
  return p_status;
end $$;

create function public.admin_set_review_hidden(p_review_id uuid, p_hidden boolean, p_note text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := private.require_admin();
  v_old boolean;
begin
  select is_hidden into v_old from public.reviews where id = p_review_id for update;
  if not found then
    raise exception 'Review not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  update public.reviews set is_hidden = p_hidden where id = p_review_id;
  insert into public.admin_audit_log (actor_id, action, target_table, target_id, before, after, note)
  values (v_uid, case when p_hidden then 'review.hide' else 'review.unhide' end, 'reviews', p_review_id::text,
          jsonb_build_object('is_hidden', v_old), jsonb_build_object('is_hidden', p_hidden), nullif(btrim(p_note), ''));
end $$;

create function public.admin_set_service_hidden(p_service_id uuid, p_hidden boolean, p_note text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := private.require_admin();
  v_old timestamptz;
begin
  select hidden_at into v_old from public.services where id = p_service_id for update;
  if not found then
    raise exception 'Service not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  update public.services
     set hidden_at = case when p_hidden then coalesce(hidden_at, now()) else null end
   where id = p_service_id;
  insert into public.admin_audit_log (actor_id, action, target_table, target_id, before, after, note)
  values (v_uid, case when p_hidden then 'service.hide' else 'service.unhide' end, 'services', p_service_id::text,
          jsonb_build_object('hidden', v_old is not null), jsonb_build_object('hidden', p_hidden),
          nullif(btrim(p_note), ''));
end $$;

-- Category writes go through RLS (admin policies); this trigger records them.
create function private.audit_category_change()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.admin_audit_log (actor_id, action, target_table, target_id, before, after)
  values (auth.uid(), 'category.' || lower(tg_op), 'categories',
          coalesce(new.id, old.id)::text,
          case when tg_op <> 'INSERT' then to_jsonb(old) end,
          case when tg_op <> 'DELETE' then to_jsonb(new) end);
  return null;
end $$;

create trigger categories_audit after insert or update or delete on public.categories
  for each row execute function private.audit_category_change();
