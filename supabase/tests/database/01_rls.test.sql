-- RLS and privilege tests (RLS_AUTHORIZATION.md §9). Run with: supabase test db
-- Self-contained: creates its own users inside a transaction that is rolled back.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- ---------------------------------------------------------------------------
-- Fixtures (as postgres)
-- ---------------------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data) values
  ('a0000000-0000-4000-8000-0000000000c1', 'rls.cust.a@test.local',  '{"full_name":"Cust A","role":"customer"}'),
  ('a0000000-0000-4000-8000-0000000000c2', 'rls.cust.b@test.local',  '{"full_name":"Cust B"}'),
  ('a0000000-0000-4000-8000-0000000000f1', 'rls.vend.a@test.local',  '{"full_name":"Vend A","role":"vendor","business_name":"Vendor A Co"}'),
  ('a0000000-0000-4000-8000-0000000000f2', 'rls.vend.b@test.local',  '{"full_name":"Vend B","role":"vendor"}'),
  ('a0000000-0000-4000-8000-0000000000ad', 'rls.admin@test.local',   '{"full_name":"Admin","role":"admin"}'),
  ('a0000000-0000-4000-8000-0000000000e1', 'rls.sneaky@test.local',  '{"full_name":"Sneaky","role":"admin"}');
insert into public.admin_users (profile_id) values ('a0000000-0000-4000-8000-0000000000ad');

update public.vendors
   set base_location = extensions.st_setsrid(extensions.st_makepoint(77.39, 28.53), 4326)::extensions.geography,
       whatsapp_e164 = '+919800000001', status = 'verified', verified_at = now()
 where profile_id = 'a0000000-0000-4000-8000-0000000000f1';
update public.vendors
   set base_location = extensions.st_setsrid(extensions.st_makepoint(77.20, 28.61), 4326)::extensions.geography
 where profile_id = 'a0000000-0000-4000-8000-0000000000f2';

insert into public.services (id, vendor_id, category_id, title, description, price_paise, is_active) values
  ('a0000000-0000-4000-8000-00000000005a', 'a0000000-0000-4000-8000-0000000000f1',
   (select id from public.categories where slug = 'electrician'), 'Rlstest wiring', 'Wiring work for tests.', 50000, true),
  ('a0000000-0000-4000-8000-00000000005b', 'a0000000-0000-4000-8000-0000000000f1',
   (select id from public.categories where slug = 'repair'), 'Rlstest paused', 'Paused service for tests.', 10000, false),
  ('a0000000-0000-4000-8000-00000000005c', 'a0000000-0000-4000-8000-0000000000f2',
   (select id from public.categories where slug = 'salon'), 'Rlstest haircut', 'Haircut service for tests.', 30000, true);

insert into public.addresses (id, profile_id, line1, area, city, state, location_source, is_default) values
  ('a0000000-0000-4000-8000-0000000000a1', 'a0000000-0000-4000-8000-0000000000c1', '1 Test Rd', 'Area', 'Noida', 'UP', 'manual_unverified', true),
  ('a0000000-0000-4000-8000-0000000000a2', 'a0000000-0000-4000-8000-0000000000c2', '2 Test Rd', 'Area', 'Delhi', 'DL', 'manual_unverified', true);

insert into public.bookings (id, reference, service_id, customer_id, vendor_id, scheduled_at, address_snapshot, price_paise, currency)
values ('a0000000-0000-4000-8000-0000000000b1', 'VNY-RLS001', 'a0000000-0000-4000-8000-00000000005a',
        'a0000000-0000-4000-8000-0000000000c1', 'a0000000-0000-4000-8000-0000000000f1',
        now() + interval '2 days', '{"line1":"1 Test Rd"}', 50000, 'INR');

insert into public.notifications (id, user_id, type, title, body) values
  ('a0000000-0000-4000-8000-0000000000e9', 'a0000000-0000-4000-8000-0000000000c1', 'booking_confirmed', 'T', 'B');

-- ---------------------------------------------------------------------------
-- Sign-up trigger (PD-04: vendor self-selection; never admin)
-- ---------------------------------------------------------------------------
select is((select role::text from public.profiles where id = 'a0000000-0000-4000-8000-0000000000f1'), 'vendor',
          'signup with role=vendor creates a vendor profile');
select is((select slug from public.vendors where profile_id = 'a0000000-0000-4000-8000-0000000000f1'), 'vendor-a-co',
          'vendor row created with a slug from the business name');
select is((select status::text from public.vendors where profile_id = 'a0000000-0000-4000-8000-0000000000f2'), 'unverified',
          'new vendors start unverified');
select is((select role::text from public.profiles where id = 'a0000000-0000-4000-8000-0000000000e1'), 'customer',
          'signup with role=admin falls back to customer');
select ok(not exists (select 1 from public.admin_users where profile_id = 'a0000000-0000-4000-8000-0000000000e1'),
          'signup can never create an admin');

-- ---------------------------------------------------------------------------
-- anon
-- ---------------------------------------------------------------------------
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select is((select count(*) from public.search_services(p_q => 'rlstest')), 2::bigint,
          'anon search returns only active services');
select is((select count(*) from public.services where id = 'a0000000-0000-4000-8000-00000000005b'), 0::bigint,
          'anon cannot see a paused service');
select throws_ok($$ select * from public.profiles $$, '42501', null, 'anon cannot read profiles');
select throws_ok($$ select whatsapp_e164 from public.vendors $$, '42501', null, 'anon cannot read vendor WhatsApp');
select throws_ok($$ select base_location from public.vendors $$, '42501', null, 'anon cannot read vendor base location');
select lives_ok($$ select business_name, slug from public.vendors $$, 'anon can read public vendor columns');
select throws_ok($$ select * from public.bookings $$, '42501', null, 'anon cannot read bookings');
select throws_ok($$ select public.create_booking('a0000000-0000-4000-8000-00000000005a', now() + interval '2 days',
                                                 'a0000000-0000-4000-8000-0000000000a1') $$,
                 '42501', null, 'anon cannot call create_booking');

-- ---------------------------------------------------------------------------
-- customer B (not a participant)
-- ---------------------------------------------------------------------------
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-0000000000c2","role":"authenticated"}', true);

select is((select count(*) from public.bookings where id = 'a0000000-0000-4000-8000-0000000000b1'), 0::bigint,
          'customer B cannot read customer A''s booking');
select is((select count(*) from public.addresses where profile_id = 'a0000000-0000-4000-8000-0000000000c1'), 0::bigint,
          'customer B cannot read customer A''s addresses');
select is((select count(*) from public.profiles), 1::bigint, 'customer B sees only their own profile');
select is((select count(*) from public.booking_status_history where booking_id = 'a0000000-0000-4000-8000-0000000000b1'),
          0::bigint, 'customer B cannot read the booking history');
update public.notifications set read_at = now() where id = 'a0000000-0000-4000-8000-0000000000e9';
select throws_ok($$ insert into public.bookings (reference, service_id, customer_id, vendor_id, scheduled_at,
                                                 address_snapshot, price_paise, currency)
                    values ('VNY-HACK01', 'a0000000-0000-4000-8000-00000000005a', 'a0000000-0000-4000-8000-0000000000c2',
                            'a0000000-0000-4000-8000-0000000000f1', now() + interval '2 days', '{}', 1, 'INR') $$,
                 '42501', null, 'direct insert into bookings is denied');
select throws_ok($$ update public.profiles set role = 'vendor' where id = 'a0000000-0000-4000-8000-0000000000c2' $$,
                 '42501', null, 'a user cannot change their own role');
select throws_ok($$ insert into public.services (vendor_id, category_id, title, description, price_paise, location)
                    values ('a0000000-0000-4000-8000-0000000000c2', 1, 'Not a vendor', 'Customers cannot list.', 1,
                            extensions.st_setsrid(extensions.st_makepoint(77, 28), 4326)::extensions.geography) $$,
                 '42501', null, 'a customer cannot create a service');
select throws_ok($$ select * from public.get_booking_contact('a0000000-0000-4000-8000-0000000000b1') $$,
                 'P0002', null, 'a non-participant cannot read booking contact details');
select throws_ok($$ select public.admin_set_vendor_status('a0000000-0000-4000-8000-0000000000f2', 'verified') $$,
                 '42501', null, 'a non-admin cannot change vendor status');
select throws_ok($$ select * from public.admin_users $$, '42501', null, 'admin_users is not readable');
select is((select count(*) from public.admin_audit_log), 0::bigint, 'a non-admin sees no audit log rows');
select throws_ok($$ insert into public.notifications (user_id, type, title, body)
                    values ('a0000000-0000-4000-8000-0000000000c2', 'booking_new', 'x', 'y') $$,
                 '42501', null, 'clients cannot insert notifications');

-- ---------------------------------------------------------------------------
-- customer A (participant)
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-0000000000c1","role":"authenticated"}', true);

select is((select count(*) from public.bookings), 1::bigint, 'customer A sees their own booking');
select throws_ok($$ select * from public.get_booking_contact('a0000000-0000-4000-8000-0000000000b1') $$,
                 'P0001', null, 'contact details are hidden while the booking is pending');
select throws_ok($$ select public.create_review('a0000000-0000-4000-8000-0000000000b1', 5) $$,
                 'P0001', null, 'a booking that is not completed cannot be reviewed');
select throws_ok($$ update public.notifications set title = 'changed' where id = 'a0000000-0000-4000-8000-0000000000e9' $$,
                 '42501', null, 'only read_at is writable on notifications');
select is(public.mark_notifications_read(), 1, 'owner can mark their notification read');
select throws_ok($$ update public.bookings set status = 'cancelled' where id = 'a0000000-0000-4000-8000-0000000000b1' $$,
                 '42501', null, 'direct booking status update is denied');

-- ---------------------------------------------------------------------------
-- vendor A / vendor B
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-0000000000f1","role":"authenticated"}', true);

select is((select count(*) from public.bookings where id = 'a0000000-0000-4000-8000-0000000000b1'), 1::bigint,
          'vendor A sees bookings for their services');
select is((select count(*) from public.services where vendor_id = 'a0000000-0000-4000-8000-0000000000f1'), 2::bigint,
          'vendor A sees their own paused service (BE-07)');
select throws_ok($$ update public.vendors set status = 'verified' where profile_id = 'a0000000-0000-4000-8000-0000000000f1' $$,
                 '42501', null, 'a vendor cannot change their own status');
select throws_ok($$ update public.services set avg_rating = 5 where id = 'a0000000-0000-4000-8000-00000000005a' $$,
                 '42501', null, 'a vendor cannot write avg_rating (SEC-04)');
select throws_ok($$ insert into public.services (vendor_id, category_id, title, description, price_paise)
                    values ('a0000000-0000-4000-8000-0000000000f2', 1, 'For vendor B', 'Spoofed vendor id.', 1) $$,
                 '42501', null, 'a vendor cannot create a service for another vendor');
select is((select whatsapp_e164 from public.get_my_vendor()), '+919800000001', 'a vendor reads their own private fields');
select ok(private.owns_service_image_path('a0000000-0000-4000-8000-0000000000f1/a0000000-0000-4000-8000-00000000005a/x.webp'),
          'vendor A may upload to their own service image path');
select ok(not private.owns_service_image_path('a0000000-0000-4000-8000-0000000000f2/a0000000-0000-4000-8000-00000000005c/x.webp'),
          'vendor A may not upload to vendor B''s path');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-0000000000f2","role":"authenticated"}', true);
update public.services set title = 'Hijacked title' where id = 'a0000000-0000-4000-8000-00000000005a';
select throws_ok($$ select public.soft_delete_service('a0000000-0000-4000-8000-00000000005a') $$,
                 'P0002', null, 'vendor B cannot delete vendor A''s service');
select throws_ok($$ select public.transition_booking('a0000000-0000-4000-8000-0000000000b1', 'confirmed') $$,
                 'P0002', null, 'vendor B cannot transition vendor A''s booking');

-- ---------------------------------------------------------------------------
-- admin (PD-13 option b)
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-0000000000ad","role":"authenticated"}', true);

select is((select count(*) from public.bookings where id = 'a0000000-0000-4000-8000-0000000000b1'), 1::bigint,
          'admin can read all bookings');
select is(public.admin_set_vendor_status('a0000000-0000-4000-8000-0000000000f2', 'verified', 'Docs checked')::text,
          'verified', 'admin can verify a vendor');
select lives_ok($$ select public.admin_set_service_hidden('a0000000-0000-4000-8000-00000000005c', true, 'Policy') $$,
                'admin can hide a listing');
select is((select count(*) from public.admin_audit_log), 2::bigint, 'admin actions are written to the audit log');
select throws_ok($$ update public.profiles set role = 'vendor' where id = 'a0000000-0000-4000-8000-0000000000c1' $$,
                 '42501', null, 'admin cannot change user roles');
select throws_ok($$ insert into public.admin_users (profile_id) values ('a0000000-0000-4000-8000-0000000000c1') $$,
                 '42501', null, 'admin cannot grant admin rights');
select lives_ok($$ insert into public.categories (slug, name) values ('gardening', 'Gardening') $$,
                'admin can add a category');

-- ---------------------------------------------------------------------------
-- Effects checked as postgres
-- ---------------------------------------------------------------------------
reset role;
select is((select title from public.services where id = 'a0000000-0000-4000-8000-00000000005a'), 'Rlstest wiring',
          'vendor B''s update of vendor A''s service changed nothing');
select is((select read_at is not null from public.notifications where id = 'a0000000-0000-4000-8000-0000000000e9'), true,
          'notification read by its owner (customer B''s earlier update affected nothing)');
select is((select count(*) from public.admin_audit_log where action = 'category.insert'), 1::bigint,
          'category changes are audited');

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select is((select count(*) from public.search_services(p_q => 'rlstest')), 1::bigint,
          'a hidden listing disappears from public search');

select * from finish();
rollback;
