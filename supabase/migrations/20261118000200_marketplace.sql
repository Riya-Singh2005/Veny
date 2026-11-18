-- Veny: marketplace rules from the 2026-11-18 brief.
--   * PD-02: vendor verification REQUIRED. Services of unverified vendors are hidden and unbookable.
--   * Capacity: one booking at a time per vendor (exclusion constraint).
--   * Availability: weekly hours + time off; slots computed by get_available_slots().
--   * Vendor may reject a pending booking (new status 'rejected').
--   * Customer may cancel 'confirmed' only until 2 hours before the start.
--   * Favorites (services or vendors).

create extension if not exists btree_gist with schema extensions;

-- ===========================================================================
-- Settings
-- ===========================================================================
create function private.customer_cancel_window()
returns interval language sql immutable set search_path = '' as $$ select interval '2 hours' $$;

create function private.slot_step()
returns interval language sql immutable set search_path = '' as $$ select interval '30 minutes' $$;

-- ===========================================================================
-- vendors.timezone
-- ===========================================================================
alter table public.vendors
  add column timezone text not null default 'Asia/Kolkata' check (char_length(timezone) between 3 and 64);
grant select (timezone) on public.vendors to anon, authenticated;
grant update (timezone) on public.vendors to authenticated;

-- ===========================================================================
-- bookings: end time, vendor response, rejection, no overlaps
-- ===========================================================================
alter table public.bookings
  add column ends_at         timestamptz,
  add column vendor_response text check (char_length(vendor_response) <= 500),
  add column rejected_at     timestamptz;

update public.bookings b
   set ends_at = b.scheduled_at + make_interval(mins => coalesce(s.duration_minutes, 60))
  from public.services s
 where s.id = b.service_id and b.ends_at is null;

alter table public.bookings
  alter column ends_at set not null,
  add constraint bookings_ends_after_start_chk check (ends_at > scheduled_at),
  add constraint bookings_rejected_chk check ((status = 'rejected') = (rejected_at is not null)),
  add constraint bookings_no_overlap exclude using gist (
    vendor_id with =,
    tstzrange(scheduled_at, ends_at, '[)') with &&
  ) where (status in ('pending', 'confirmed', 'in_progress'));

-- ends_at defaults from the service duration (60 minutes when the service has none).
create function private.bookings_set_ends_at()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.ends_at is null then
    select new.scheduled_at + make_interval(mins => coalesce(s.duration_minutes, 60))
      into new.ends_at from public.services s where s.id = new.service_id;
  end if;
  return new;
end $$;
create trigger bookings_set_ends_at before insert on public.bookings
  for each row execute function private.bookings_set_ends_at();

-- ===========================================================================
-- Availability
-- ===========================================================================
create table public.vendor_availability (
  id         uuid primary key default gen_random_uuid(),
  vendor_id  uuid not null default auth.uid() references public.vendors (profile_id) on delete cascade,
  weekday    smallint not null check (weekday between 0 and 6),   -- 0 = Sunday (extract(dow))
  start_time time not null,
  end_time   time not null,
  created_at timestamptz not null default now(),
  constraint vendor_availability_range_chk check (end_time > start_time),
  constraint vendor_availability_no_overlap exclude using gist (
    vendor_id with =, weekday with =,
    int4range(extract(epoch from start_time)::int, extract(epoch from end_time)::int) with &&
  )
);
create index vendor_availability_vendor_idx on public.vendor_availability (vendor_id, weekday);
alter table public.vendor_availability enable row level security;

create table public.vendor_time_off (
  id         uuid primary key default gen_random_uuid(),
  vendor_id  uuid not null default auth.uid() references public.vendors (profile_id) on delete cascade,
  period     tstzrange not null check (not isempty(period) and not lower_inf(period) and not upper_inf(period)),
  reason     text check (char_length(reason) <= 200),
  created_at timestamptz not null default now()
);
create index vendor_time_off_vendor_period_gix on public.vendor_time_off using gist (vendor_id, period);
alter table public.vendor_time_off enable row level security;

grant select on public.vendor_availability to anon, authenticated;
grant insert (vendor_id, weekday, start_time, end_time) on public.vendor_availability to authenticated;
grant update (weekday, start_time, end_time) on public.vendor_availability to authenticated;
grant delete on public.vendor_availability to authenticated;
create policy vendor_availability_select_public on public.vendor_availability
  for select to anon, authenticated using (true);
create policy vendor_availability_insert_own on public.vendor_availability
  for insert to authenticated with check (vendor_id = (select auth.uid()) and (select private.is_vendor()));
create policy vendor_availability_update_own on public.vendor_availability
  for update to authenticated using (vendor_id = (select auth.uid())) with check (vendor_id = (select auth.uid()));
create policy vendor_availability_delete_own on public.vendor_availability
  for delete to authenticated using (vendor_id = (select auth.uid()));

-- Time off is private (the reason may be personal); slots are computed by a definer RPC.
grant select, delete on public.vendor_time_off to authenticated;
grant insert (vendor_id, period, reason) on public.vendor_time_off to authenticated;
grant update (period, reason) on public.vendor_time_off to authenticated;
create policy vendor_time_off_select_own on public.vendor_time_off
  for select to authenticated using (vendor_id = (select auth.uid()));
create policy vendor_time_off_insert_own on public.vendor_time_off
  for insert to authenticated with check (vendor_id = (select auth.uid()) and (select private.is_vendor()));
create policy vendor_time_off_update_own on public.vendor_time_off
  for update to authenticated using (vendor_id = (select auth.uid())) with check (vendor_id = (select auth.uid()));
create policy vendor_time_off_delete_own on public.vendor_time_off
  for delete to authenticated using (vendor_id = (select auth.uid()));

-- ===========================================================================
-- Visibility: only VERIFIED vendors are public (PD-02)
-- ===========================================================================
drop policy vendors_select_public on public.vendors;
create policy vendors_select_public on public.vendors
  for select to anon, authenticated using (status = 'verified');
-- A customer keeps seeing the vendor of their own bookings even if it is later suspended.
create policy vendors_select_booked on public.vendors
  for select to authenticated
  using (exists (select 1 from public.bookings b
                  where b.vendor_id = vendors.profile_id and b.customer_id = (select auth.uid())));

drop policy services_select_public on public.services;
create policy services_select_public on public.services
  for select to anon, authenticated
  using (is_active and deleted_at is null and hidden_at is null
         and exists (select 1 from public.vendors v
                      where v.profile_id = services.vendor_id and v.status = 'verified'));
create policy services_select_booked on public.services
  for select to authenticated
  using (exists (select 1 from public.bookings b
                  where b.service_id = services.id and b.customer_id = (select auth.uid())));

-- ===========================================================================
-- Slots
-- ===========================================================================
create function public.get_available_slots(p_service_id uuid, p_date date)
returns table (slot_start timestamptz, slot_end timestamptz)
language plpgsql stable security definer set search_path = '' as $$
declare
  v_vendor uuid;
  v_tz     text;
  v_dur    interval;
begin
  if p_date is null or p_date < current_date or p_date > current_date + 180 then
    raise exception 'Choose a date within the next 180 days' using errcode = '22023', hint = 'invalid_date';
  end if;

  select s.vendor_id, v.timezone, make_interval(mins => coalesce(s.duration_minutes, 60))
    into v_vendor, v_tz, v_dur
    from public.services s join public.vendors v on v.profile_id = s.vendor_id
   where s.id = p_service_id and s.is_active and s.deleted_at is null and s.hidden_at is null
     and v.status = 'verified';
  if not found then
    raise exception 'Service not found' using errcode = 'P0002', hint = 'not_found';
  end if;

  return query
  with windows as (
    select (p_date + a.start_time) at time zone v_tz as ws,
           (p_date + a.end_time)   at time zone v_tz as we
      from public.vendor_availability a
     where a.vendor_id = v_vendor and a.weekday = extract(dow from p_date)
  ), slots as (
    select gs as st, gs + v_dur as en
      from windows w, generate_series(w.ws, w.we - v_dur, private.slot_step()) gs
  )
  select sl.st, sl.en
    from slots sl
   where sl.st >= now() + interval '1 hour'
     and not exists (select 1 from public.bookings b
                      where b.vendor_id = v_vendor
                        and b.status in ('pending', 'confirmed', 'in_progress')
                        and tstzrange(b.scheduled_at, b.ends_at, '[)') && tstzrange(sl.st, sl.en, '[)'))
     and not exists (select 1 from public.vendor_time_off t
                      where t.vendor_id = v_vendor and t.period && tstzrange(sl.st, sl.en, '[)'))
   order by sl.st;
end $$;

-- ===========================================================================
-- create_booking: verified vendor, availability, time off, overlap -> friendly error
-- ===========================================================================
create or replace function public.create_booking(p_service_id uuid, p_scheduled_at timestamptz,
                                                 p_address_id uuid, p_notes text default null)
returns public.bookings language plpgsql security definer set search_path = '' as $$
declare
  v_uid     uuid := auth.uid();
  v_service public.services;
  v_vendor  public.vendors;
  v_addr    public.addresses;
  v_booking public.bookings;
  v_ref     text;
  v_end     timestamptz;
  v_local_start timestamp;
  v_local_end   timestamp;
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
  select * into v_vendor from public.vendors where profile_id = v_service.vendor_id;
  if not v_service.is_active or v_service.deleted_at is not null or v_service.hidden_at is not null
     or v_vendor.status <> 'verified' then
    raise exception 'This service is not available' using errcode = 'P0001', hint = 'service_unavailable';
  end if;
  if v_service.vendor_id = v_uid then
    raise exception 'You cannot book your own service' using errcode = 'P0001', hint = 'own_service';
  end if;

  v_end := p_scheduled_at + make_interval(mins => coalesce(v_service.duration_minutes, 60));
  v_local_start := p_scheduled_at at time zone v_vendor.timezone;
  v_local_end   := v_end at time zone v_vendor.timezone;
  if v_local_end::date <> v_local_start::date
     or not exists (select 1 from public.vendor_availability a
                     where a.vendor_id = v_vendor.profile_id
                       and a.weekday = extract(dow from v_local_start)
                       and v_local_start::time >= a.start_time
                       and v_local_end::time   <= a.end_time) then
    raise exception 'The vendor is not available at this time' using errcode = 'P0001', hint = 'outside_availability';
  end if;
  if exists (select 1 from public.vendor_time_off t
              where t.vendor_id = v_vendor.profile_id and t.period && tstzrange(p_scheduled_at, v_end, '[)')) then
    raise exception 'The vendor is not available at this time' using errcode = 'P0001', hint = 'outside_availability';
  end if;

  select * into v_addr from public.addresses where id = p_address_id and profile_id = v_uid;
  if not found then
    raise exception 'Address not found' using errcode = 'P0002', hint = 'address_not_found';
  end if;

  loop
    v_ref := 'VNY-' || private.random_code(6);
    exit when not exists (select 1 from public.bookings where reference = v_ref);
  end loop;

  begin
    insert into public.bookings (reference, service_id, customer_id, vendor_id, scheduled_at, ends_at, customer_notes,
                                 address_snapshot, address_location, price_paise, currency)
    values (v_ref, v_service.id, v_uid, v_service.vendor_id, p_scheduled_at, v_end, nullif(btrim(p_notes), ''),
            jsonb_build_object('label', v_addr.label, 'line1', v_addr.line1, 'line2', v_addr.line2,
                               'area', v_addr.area, 'city', v_addr.city, 'state', v_addr.state,
                               'postal_code', v_addr.postal_code, 'country_code', v_addr.country_code,
                               'location_source', v_addr.location_source),
            v_addr.location, v_service.price_paise, v_service.currency)
    returning * into v_booking;
  exception when exclusion_violation then
    raise exception 'This time slot was just taken. Please choose another.'
      using errcode = '23P01', hint = 'slot_taken';
  end;

  insert into public.booking_status_history (booking_id, from_status, to_status, changed_by)
  values (v_booking.id, null, 'pending', v_uid);

  perform private.notify(v_service.vendor_id, 'booking_new', 'New booking request',
                         format('Booking %s for "%s".', v_booking.reference, v_service.title),
                         '/vendor/bookings/' || v_booking.id, v_booking.id);
  return v_booking;
end $$;

-- ===========================================================================
-- transition_booking: + reject, + customer cancel window
--   pending     -> confirmed    vendor
--   pending     -> rejected     vendor (optional reason -> vendor_response)
--   pending     -> cancelled    customer (any time), vendor (reason), admin (reason)
--   confirmed   -> in_progress  vendor
--   confirmed   -> cancelled    customer (until 2h before start), vendor (reason), admin (reason)
--   in_progress -> completed    vendor
--   in_progress -> cancelled    admin (reason)
-- ===========================================================================
create or replace function public.transition_booking(p_booking_id uuid, p_to public.booking_status,
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
    raise exception 'Booking not found' using errcode = 'P0002', hint = 'not_found';
  end if;

  if not (
       (v_old.status = 'pending'     and p_to = 'confirmed'   and v_actor = 'vendor')
    or (v_old.status = 'pending'     and p_to = 'rejected'    and v_actor = 'vendor')
    or (v_old.status = 'pending'     and p_to = 'cancelled'   and v_actor in ('customer', 'vendor', 'admin'))
    or (v_old.status = 'confirmed'   and p_to = 'in_progress' and v_actor = 'vendor')
    or (v_old.status = 'confirmed'   and p_to = 'cancelled'   and v_actor in ('customer', 'vendor', 'admin'))
    or (v_old.status = 'in_progress' and p_to = 'completed'   and v_actor = 'vendor')
    or (v_old.status = 'in_progress' and p_to = 'cancelled'   and v_actor = 'admin')
  ) then
    raise exception 'Cannot change this booking from % to %', v_old.status, p_to
      using errcode = 'P0001', hint = 'invalid_transition';
  end if;

  if p_to = 'cancelled' and v_actor = 'customer' and v_old.status = 'confirmed'
     and v_old.scheduled_at - now() <= private.customer_cancel_window() then
    raise exception 'Confirmed bookings can be cancelled up to 2 hours before the start. Please contact the vendor.'
      using errcode = 'P0001', hint = 'cancel_window_passed';
  end if;
  if p_to = 'cancelled' and v_actor in ('vendor', 'admin') and v_reason is null then
    raise exception 'A reason is required to cancel' using errcode = '22023', hint = 'reason_required';
  end if;

  update public.bookings set
    status          = p_to,
    confirmed_at    = case when p_to = 'confirmed'   then now() else confirmed_at end,
    started_at      = case when p_to = 'in_progress' then now() else started_at end,
    completed_at    = case when p_to = 'completed'   then now() else completed_at end,
    cancelled_at    = case when p_to = 'cancelled'   then now() else cancelled_at end,
    cancelled_by    = case when p_to = 'cancelled'   then v_uid else cancelled_by end,
    cancel_reason   = case when p_to = 'cancelled'   then v_reason else cancel_reason end,
    rejected_at     = case when p_to = 'rejected'    then now() else rejected_at end,
    vendor_response = case when p_to = 'rejected'    then v_reason else vendor_response end
  where id = p_booking_id
  returning * into v_new;

  insert into public.booking_status_history (booking_id, from_status, to_status, changed_by, reason)
  values (p_booking_id, v_old.status, p_to, v_uid, v_reason);

  select s.title into v_title from public.services s where s.id = v_new.service_id;
  v_cust_link := '/account/bookings/' || v_new.id;
  v_vend_link := '/vendor/bookings/' || v_new.id;

  if p_to = 'confirmed' then
    perform private.notify(v_new.customer_id, 'booking_confirmed', 'Booking confirmed',
      format('Your booking %s for "%s" is confirmed.', v_new.reference, v_title), v_cust_link, v_new.id);
  elsif p_to = 'rejected' then
    perform private.notify(v_new.customer_id, 'booking_rejected', 'Booking declined',
      format('Your booking %s for "%s" was declined by the vendor.', v_new.reference, v_title), v_cust_link, v_new.id);
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

-- Paths in notifications for the SPA routes.
create or replace function public.create_review(p_booking_id uuid, p_rating int, p_comment text default null)
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
                         '/vendor/reviews', v_b.id);
  return v_review;
end $$;

-- ===========================================================================
-- search_services: verified vendors only
-- ===========================================================================
create or replace function public.search_services(
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
     and v.status = 'verified' and c.is_active
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
-- Favorites
-- ===========================================================================
create table public.favorites (
  id         uuid primary key default gen_random_uuid(),
  profile_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  service_id uuid references public.services (id) on delete cascade,
  vendor_id  uuid references public.vendors (profile_id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint favorites_one_target_chk check (num_nonnulls(service_id, vendor_id) = 1)
);
create unique index favorites_service_uniq on public.favorites (profile_id, service_id) where service_id is not null;
create unique index favorites_vendor_uniq  on public.favorites (profile_id, vendor_id)  where vendor_id is not null;
create index favorites_profile_created_idx on public.favorites (profile_id, created_at desc);
create index favorites_service_idx on public.favorites (service_id);
create index favorites_vendor_idx  on public.favorites (vendor_id);
alter table public.favorites enable row level security;

grant select, delete on public.favorites to authenticated;
grant insert (profile_id, service_id, vendor_id) on public.favorites to authenticated;
create policy favorites_select_own on public.favorites
  for select to authenticated using (profile_id = (select auth.uid()));
create policy favorites_insert_own on public.favorites
  for insert to authenticated with check (profile_id = (select auth.uid()));
create policy favorites_delete_own on public.favorites
  for delete to authenticated using (profile_id = (select auth.uid()));

-- ===========================================================================
-- Vendor verification (PD-02: required)
-- ===========================================================================
create table public.vendor_verifications (
  id             uuid primary key default gen_random_uuid(),
  vendor_id      uuid not null references public.vendors (profile_id) on delete cascade,
  document_paths text[] not null check (cardinality(document_paths) between 1 and 5),
  vendor_note    text check (char_length(vendor_note) <= 1000),
  status         text not null default 'submitted' check (status in ('submitted', 'approved', 'rejected')),
  reviewer_id    uuid references public.profiles (id) on delete set null,
  reviewer_notes text check (char_length(reviewer_notes) <= 1000),
  submitted_at   timestamptz not null default now(),
  reviewed_at    timestamptz,
  constraint vendor_verifications_reviewed_chk check ((status = 'submitted') = (reviewed_at is null))
);
create unique index vendor_verifications_one_open on public.vendor_verifications (vendor_id) where status = 'submitted';
create index vendor_verifications_vendor_idx   on public.vendor_verifications (vendor_id, submitted_at desc);
create index vendor_verifications_status_idx   on public.vendor_verifications (status, submitted_at);
create index vendor_verifications_reviewer_idx on public.vendor_verifications (reviewer_id);
alter table public.vendor_verifications enable row level security;

grant select on public.vendor_verifications to authenticated;
create policy vendor_verifications_select_own on public.vendor_verifications
  for select to authenticated using (vendor_id = (select auth.uid()));
create policy vendor_verifications_select_admin on public.vendor_verifications
  for select to authenticated using ((select private.is_admin()));

create function public.submit_vendor_verification(p_document_paths text[], p_note text default null)
returns public.vendor_verifications language plpgsql security definer set search_path = '' as $$
declare
  v_uid    uuid := auth.uid();
  v_status public.vendor_status;
  v_row    public.vendor_verifications;
  v_path   text;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '42501', hint = 'unauthenticated';
  end if;
  select status into v_status from public.vendors where profile_id = v_uid for update;
  if not found then
    raise exception 'Only vendors can submit verification' using errcode = '42501', hint = 'not_a_vendor';
  end if;
  if v_status <> 'unverified' then
    raise exception 'Verification is already %', v_status using errcode = 'P0001', hint = 'invalid_state';
  end if;
  if p_document_paths is null or cardinality(p_document_paths) not between 1 and 5 then
    raise exception 'Upload between 1 and 5 documents' using errcode = '22023', hint = 'invalid_documents';
  end if;
  foreach v_path in array p_document_paths loop
    if split_part(v_path, '/', 1) <> v_uid::text
       or not exists (select 1 from storage.objects o where o.bucket_id = 'verification-docs' and o.name = v_path) then
      raise exception 'Document not found: %', v_path using errcode = '22023', hint = 'invalid_documents';
    end if;
  end loop;

  insert into public.vendor_verifications (vendor_id, document_paths, vendor_note)
  values (v_uid, p_document_paths, nullif(btrim(p_note), ''))
  returning * into v_row;
  update public.vendors set status = 'pending' where profile_id = v_uid;
  return v_row;
end $$;

create function public.admin_review_verification(p_verification_id uuid, p_approve boolean, p_note text default null)
returns public.vendor_verifications language plpgsql security definer set search_path = '' as $$
declare
  v_uid  uuid := private.require_admin();
  v_row  public.vendor_verifications;
  v_note text := nullif(btrim(p_note), '');
begin
  select * into v_row from public.vendor_verifications where id = p_verification_id for update;
  if not found then
    raise exception 'Verification not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if v_row.status <> 'submitted' then
    raise exception 'This submission was already reviewed' using errcode = 'P0001', hint = 'invalid_state';
  end if;
  if not p_approve and v_note is null then
    raise exception 'A note is required to reject' using errcode = '22023', hint = 'reason_required';
  end if;

  update public.vendor_verifications
     set status = case when p_approve then 'approved' else 'rejected' end,
         reviewer_id = v_uid, reviewer_notes = v_note, reviewed_at = now()
   where id = p_verification_id
  returning * into v_row;

  update public.vendors
     set status = case when p_approve then 'verified'::public.vendor_status else 'unverified'::public.vendor_status end,
         verified_at = case when p_approve then now() else null end
   where profile_id = v_row.vendor_id;

  if p_approve then
    perform private.notify(v_row.vendor_id, 'vendor_verified', 'You are verified',
      'Your business is verified. Your active services are now visible to customers.', '/vendor', null);
  else
    perform private.notify(v_row.vendor_id, 'vendor_rejected', 'Verification needs changes',
      'Your verification was not approved: ' || v_note, '/vendor/verification', null);
  end if;

  insert into public.admin_audit_log (actor_id, action, target_table, target_id, before, after, note)
  values (v_uid, case when p_approve then 'verification.approve' else 'verification.reject' end,
          'vendor_verifications', v_row.id::text, jsonb_build_object('status', 'submitted'),
          jsonb_build_object('status', v_row.status), v_note);
  return v_row;
end $$;

-- Private verification documents bucket: {vendor_id}/{uuid}.{ext}
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('verification-docs', 'verification-docs', false, 10485760,
   array['application/pdf', 'image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = excluded.public, file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create policy verification_docs_insert_own on storage.objects
  for insert to authenticated
  with check (bucket_id = 'verification-docs'
              and (storage.foldername(name))[1] = (select auth.uid())::text
              and exists (select 1 from public.vendors v where v.profile_id = (select auth.uid())));
create policy verification_docs_select_own on storage.objects
  for select to authenticated
  using (bucket_id = 'verification-docs' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy verification_docs_select_admin on storage.objects
  for select to authenticated
  using (bucket_id = 'verification-docs' and (select private.is_admin()));
create policy verification_docs_delete_own on storage.objects
  for delete to authenticated
  using (bucket_id = 'verification-docs' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- ===========================================================================
-- Session access summary for route guards (SECURITY INVOKER: RLS applies)
-- ===========================================================================
create function public.get_my_access()
returns table (user_id uuid, role public.user_role, full_name text, is_admin boolean,
               vendor_status public.vendor_status)
language sql stable security invoker set search_path = '' as $$
  select p.id, p.role, p.full_name, private.is_admin(), v.status
    from public.profiles p
    left join public.vendors v on v.profile_id = p.id
   where p.id = (select auth.uid());
$$;

-- Notification links follow the SPA routes from now on.
create or replace function public.mark_notifications_read(p_ids uuid[] default null)
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
-- EXECUTE grants for new functions (default privileges grant nothing)
-- ===========================================================================
grant execute on function private.customer_cancel_window() to authenticated;
grant execute on function private.slot_step() to anon, authenticated;
grant execute on function public.get_available_slots(uuid, date) to anon, authenticated;
grant execute on function public.submit_vendor_verification(text[], text) to authenticated;
grant execute on function public.admin_review_verification(uuid, boolean, text) to authenticated;
grant execute on function public.get_my_access() to authenticated;
