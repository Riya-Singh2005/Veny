-- Veny: LOCAL DEVELOPMENT fixtures only. `supabase db reset` runs this file; it is never
-- applied to staging or production by `supabase db push`.
-- All accounts use the password: VenyDev2026   (local stack only)
-- Categories are production reference data and live in the schema migration, not here.
-- Production's first admin is created per PD-14, never from this file.

-- ---------------------------------------------------------------------------
-- Auth users (the on_auth_user_created trigger creates profiles + vendors rows)
-- ---------------------------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                        confirmation_token, recovery_token, email_change_token_new, email_change,
                        email_change_token_current, phone_change, phone_change_token, reauthentication_token)
select '00000000-0000-0000-0000-000000000000', u.id, 'authenticated', 'authenticated', u.email,
       extensions.crypt('VenyDev2026', extensions.gen_salt('bf')), now(),
       '{"provider":"email","providers":["email"]}'::jsonb, u.meta, now(), now(),
       '', '', '', '', '', '', '', ''
from (values
  ('11111111-1111-4111-8111-111111111111'::uuid, 'customer.a@veny.test', '{"full_name":"Asha Kumar","role":"customer"}'::jsonb),
  ('22222222-2222-4222-8222-222222222222'::uuid, 'customer.b@veny.test', '{"full_name":"Bilal Shah","role":"customer"}'::jsonb),
  ('33333333-3333-4333-8333-333333333333'::uuid, 'vendor.a@veny.test',   '{"full_name":"Ravi Verma","role":"vendor","business_name":"Ravi Electricals"}'::jsonb),
  ('44444444-4444-4444-8444-444444444444'::uuid, 'vendor.b@veny.test',   '{"full_name":"Meera Iyer","role":"vendor","business_name":"Meera Home Salon"}'::jsonb),
  ('55555555-5555-4555-8555-555555555555'::uuid, 'admin@veny.test',      '{"full_name":"Veny Admin","role":"customer"}'::jsonb)
) as u (id, email, meta);

insert into auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
select gen_random_uuid(), u.id, u.id::text, 'email',
       jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
       now(), now(), now()
from auth.users u
where u.email like '%@veny.test';

-- Dev admin (PD-01). The only way to create an admin is a direct insert like this one.
insert into public.admin_users (profile_id) values ('55555555-5555-4555-8555-555555555555');

-- ---------------------------------------------------------------------------
-- Profiles and vendors
-- ---------------------------------------------------------------------------
update public.profiles set phone_e164 = '+919810000001' where id = '11111111-1111-4111-8111-111111111111';
update public.profiles set phone_e164 = '+919810000002' where id = '22222222-2222-4222-8222-222222222222';
update public.profiles set phone_e164 = '+919810000003' where id = '33333333-3333-4333-8333-333333333333';
update public.profiles set phone_e164 = '+919810000004' where id = '44444444-4444-4444-8444-444444444444';

update public.vendors set
  whatsapp_e164 = '+919810000003', bio = 'Licensed electrician serving Noida and Greater Noida.',
  base_location = extensions.st_setsrid(extensions.st_makepoint(77.3910, 28.5355), 4326)::extensions.geography,
  service_radius_m = 15000, status = 'verified', verified_at = now()
where profile_id = '33333333-3333-4333-8333-333333333333';

update public.vendors set
  whatsapp_e164 = '+919810000004', bio = 'Salon services at home.',
  base_location = extensions.st_setsrid(extensions.st_makepoint(77.2090, 28.6139), 4326)::extensions.geography,
  service_radius_m = 10000
where profile_id = '44444444-4444-4444-8444-444444444444';

-- ---------------------------------------------------------------------------
-- Addresses
-- ---------------------------------------------------------------------------
insert into public.addresses (id, profile_id, label, line1, area, city, state, postal_code, location, location_source, is_default) values
  ('a1111111-1111-4111-8111-111111111111', '11111111-1111-4111-8111-111111111111', 'Home', 'B-12, Tower 4',
   'Sector 62', 'Noida', 'Uttar Pradesh', '201309',
   extensions.st_setsrid(extensions.st_makepoint(77.3650, 28.6270), 4326)::extensions.geography, 'gps', true),
  ('a2222222-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222', 'Home', '45 Lajpat Nagar II',
   'Lajpat Nagar', 'New Delhi', 'Delhi', '110024', null, 'manual_unverified', true);

-- ---------------------------------------------------------------------------
-- Services (vendor A: two active; vendor B: one active, one paused)
-- ---------------------------------------------------------------------------
insert into public.services (id, vendor_id, category_id, slug, title, description, price_paise, duration_minutes, is_active)
select s.id, s.vendor_id, c.id, s.slug, s.title, s.description, s.price_paise, s.duration, s.active
from (values
  ('5e000001-0000-4000-8000-000000000001'::uuid, '33333333-3333-4333-8333-333333333333'::uuid, 'electrician',
   'fan-and-light-installation', 'Fan and light installation', 'Ceiling fan, light fixture and switchboard installation.', 49900, 60, true),
  ('5e000002-0000-4000-8000-000000000002'::uuid, '33333333-3333-4333-8333-333333333333'::uuid, 'repair',
   'home-wiring-repair', 'Home wiring repair', 'Fault finding and repair of household wiring and MCBs.', 79900, 120, true),
  ('5e000003-0000-4000-8000-000000000003'::uuid, '44444444-4444-4444-8444-444444444444'::uuid, 'salon',
   'haircut-at-home', 'Haircut at home', 'Haircut and styling at your home by a trained stylist.', 39900, 45, true),
  ('5e000004-0000-4000-8000-000000000004'::uuid, '44444444-4444-4444-8444-444444444444'::uuid, 'cleaning',
   'kitchen-deep-clean', 'Kitchen deep clean', 'Degreasing of hob, chimney exterior, tiles and cabinets.', 149900, 180, false)
) as s (id, vendor_id, category_slug, slug, title, description, price_paise, duration, active)
join public.categories c on c.slug = s.category_slug;

insert into public.service_images (service_id, storage_path, alt_text, position) values
  ('5e000001-0000-4000-8000-000000000001', '33333333-3333-4333-8333-333333333333/5e000001-0000-4000-8000-000000000001/cover.webp', 'Ceiling fan installation', 0);

-- ---------------------------------------------------------------------------
-- Bookings for customer A on vendor A's services: one in every status
-- ---------------------------------------------------------------------------
insert into public.bookings (id, reference, service_id, customer_id, vendor_id, status, scheduled_at,
                             address_snapshot, address_location, price_paise, currency,
                             confirmed_at, started_at, completed_at, cancelled_at, cancelled_by, cancel_reason, created_at)
select b.id, b.ref, b.service_id, '11111111-1111-4111-8111-111111111111', '33333333-3333-4333-8333-333333333333',
       b.status::public.booking_status, b.scheduled_at,
       jsonb_build_object('label', a.label, 'line1', a.line1, 'line2', a.line2, 'area', a.area, 'city', a.city,
                          'state', a.state, 'postal_code', a.postal_code, 'country_code', a.country_code,
                          'location_source', a.location_source),
       a.location, s.price_paise, s.currency,
       b.confirmed_at, b.started_at, b.completed_at, b.cancelled_at, b.cancelled_by, b.cancel_reason,
       b.scheduled_at - interval '3 days'
from (values
  ('b0000001-0000-4000-8000-000000000001'::uuid, 'VNY-PEND01', '5e000001-0000-4000-8000-000000000001'::uuid, 'pending',
   now() + interval '3 days', null::timestamptz, null::timestamptz, null::timestamptz, null::timestamptz, null::uuid, null::text),
  ('b0000002-0000-4000-8000-000000000002'::uuid, 'VNY-CONF02', '5e000002-0000-4000-8000-000000000002'::uuid, 'confirmed',
   now() + interval '2 days', now() - interval '1 hour', null, null, null, null, null),
  ('b0000003-0000-4000-8000-000000000003'::uuid, 'VNY-PROG03', '5e000001-0000-4000-8000-000000000001'::uuid, 'in_progress',
   now() - interval '30 minutes', now() - interval '1 day', now() - interval '20 minutes', null, null, null, null),
  ('b0000004-0000-4000-8000-000000000004'::uuid, 'VNY-DONE04', '5e000002-0000-4000-8000-000000000002'::uuid, 'completed',
   now() - interval '5 days', now() - interval '6 days', now() - interval '5 days', now() - interval '5 days' + interval '2 hours', null, null, null),
  ('b0000005-0000-4000-8000-000000000005'::uuid, 'VNY-CANC05', '5e000001-0000-4000-8000-000000000001'::uuid, 'cancelled',
   now() + interval '4 days', null, null, null, now() - interval '2 hours', '11111111-1111-4111-8111-111111111111'::uuid, 'Plans changed')
) as b (id, ref, service_id, status, scheduled_at, confirmed_at, started_at, completed_at, cancelled_at, cancelled_by, cancel_reason)
join public.services s on s.id = b.service_id
join public.addresses a on a.id = 'a1111111-1111-4111-8111-111111111111';

insert into public.booking_status_history (booking_id, from_status, to_status, changed_by, reason, created_at)
select b.id, null, 'pending', b.customer_id, null, b.created_at from public.bookings b;

insert into public.reviews (booking_id, service_id, customer_id, author_name, rating, comment)
values ('b0000004-0000-4000-8000-000000000004', '5e000002-0000-4000-8000-000000000002',
        '11111111-1111-4111-8111-111111111111', 'Asha K.', 5, 'Quick and tidy work.');

insert into public.notifications (user_id, type, title, body, link, booking_id) values
  ('33333333-3333-4333-8333-333333333333', 'booking_new', 'New booking request',
   'Booking VNY-PEND01 for "Fan and light installation".', '/dashboard/vendor/bookings/b0000001-0000-4000-8000-000000000001',
   'b0000001-0000-4000-8000-000000000001'),
  ('11111111-1111-4111-8111-111111111111', 'booking_confirmed', 'Booking confirmed',
   'Your booking VNY-CONF02 for "Home wiring repair" is confirmed.', '/dashboard/customer/bookings/b0000002-0000-4000-8000-000000000002',
   'b0000002-0000-4000-8000-000000000002');
