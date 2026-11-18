-- Marketplace rules (2026-11-18 brief): verification, availability, slots, overlap,
-- vendor reject, customer cancel window, favorites, access summary.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data) values
  ('c0000000-0000-4000-8000-0000000000c1', 'mk.cust.a@test.local', '{"full_name":"Mk Cust A"}'),
  ('c0000000-0000-4000-8000-0000000000c2', 'mk.cust.b@test.local', '{"full_name":"Mk Cust B"}'),
  ('c0000000-0000-4000-8000-0000000000f1', 'mk.vend.a@test.local', '{"full_name":"Mk Vend A","role":"vendor"}'),
  ('c0000000-0000-4000-8000-0000000000f2', 'mk.vend.b@test.local', '{"full_name":"Mk Vend B","role":"vendor"}'),
  ('c0000000-0000-4000-8000-0000000000ad', 'mk.admin@test.local',  '{"full_name":"Mk Admin"}');
insert into public.admin_users (profile_id) values ('c0000000-0000-4000-8000-0000000000ad');

update public.vendors
   set base_location = extensions.st_setsrid(extensions.st_makepoint(77.39, 28.53), 4326)::extensions.geography,
       status = case when profile_id = 'c0000000-0000-4000-8000-0000000000f1' then 'verified'::public.vendor_status
                     else 'unverified'::public.vendor_status end,
       verified_at = case when profile_id = 'c0000000-0000-4000-8000-0000000000f1' then now() end
 where profile_id in ('c0000000-0000-4000-8000-0000000000f1', 'c0000000-0000-4000-8000-0000000000f2');

insert into public.vendor_availability (vendor_id, weekday, start_time, end_time)
select 'c0000000-0000-4000-8000-0000000000f1', d, '09:00', '13:00' from generate_series(0, 6) d;

insert into public.services (id, vendor_id, category_id, title, description, price_paise, duration_minutes, is_active) values
  ('c0000000-0000-4000-8000-00000000005a', 'c0000000-0000-4000-8000-0000000000f1',
   (select id from public.categories where slug = 'cleaning'), 'Mk sofa clean', 'Sofa shampoo and dry.', 99900, 120, true),
  ('c0000000-0000-4000-8000-00000000005b', 'c0000000-0000-4000-8000-0000000000f2',
   (select id from public.categories where slug = 'cleaning'), 'Mk bathroom clean', 'Bathroom deep clean.', 59900, 60, true);

insert into public.addresses (id, profile_id, line1, area, city, state, location_source, is_default) values
  ('c0000000-0000-4000-8000-0000000000a1', 'c0000000-0000-4000-8000-0000000000c1', '3 Mk Rd', 'Area', 'Noida', 'UP', 'manual_unverified', true),
  ('c0000000-0000-4000-8000-0000000000a2', 'c0000000-0000-4000-8000-0000000000c2', '4 Mk Rd', 'Area', 'Noida', 'UP', 'manual_unverified', true);

create temporary table ids (k text primary key, v uuid) on commit drop;
grant all on ids to authenticated;

-- A day 3 days out, at 10:00 in the vendor's timezone.
create temporary table t (k text primary key, v timestamptz) on commit drop;
grant all on t to authenticated, anon;
insert into t values
  ('d3_1000', (current_date + 3 + time '10:00') at time zone 'Asia/Kolkata'),
  ('d3_1030', (current_date + 3 + time '10:30') at time zone 'Asia/Kolkata'),
  ('d3_1200', (current_date + 3 + time '12:00') at time zone 'Asia/Kolkata'),
  ('d3_1230', (current_date + 3 + time '12:30') at time zone 'Asia/Kolkata'),
  ('d3_1500', (current_date + 3 + time '15:00') at time zone 'Asia/Kolkata');

-- ---------------------------------------------------------------------------
-- Slots (anon)
-- ---------------------------------------------------------------------------
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

-- 09:00-13:00 window, 120-minute service, 30-minute step: 09:00, 09:30, 10:00, 10:30, 11:00 = 5 slots
select is((select count(*) from public.get_available_slots('c0000000-0000-4000-8000-00000000005a', current_date + 3)),
          5::bigint, 'slots fill the availability window in 30-minute steps');
select throws_ok($$ select * from public.get_available_slots('c0000000-0000-4000-8000-00000000005b', current_date + 3) $$,
                 'P0002', null, 'no slots for an unverified vendor''s service');
select throws_ok($$ select * from public.get_available_slots('c0000000-0000-4000-8000-00000000005a', current_date - 1) $$,
                 '22023', null, 'slots cannot be requested for past dates');
select throws_ok($$ select * from public.vendor_time_off $$, '42501', null, 'anon cannot read vendor time off');

-- ---------------------------------------------------------------------------
-- Booking rules (customer A)
-- ---------------------------------------------------------------------------
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-0000000000c1","role":"authenticated"}', true);

select throws_ok($$ select public.create_booking('c0000000-0000-4000-8000-00000000005b',
                    (select v from t where k = 'd3_1000'), 'c0000000-0000-4000-8000-0000000000a1') $$,
                 'P0001', null, 'an unverified vendor cannot be booked');
select throws_ok($$ select public.create_booking('c0000000-0000-4000-8000-00000000005a',
                    (select v from t where k = 'd3_1500'), 'c0000000-0000-4000-8000-0000000000a1') $$,
                 'P0001', null, 'booking outside availability is rejected');
select throws_ok($$ select public.create_booking('c0000000-0000-4000-8000-00000000005a',
                    (select v from t where k = 'd3_1200'), 'c0000000-0000-4000-8000-0000000000a1') $$,
                 'P0001', null, 'booking that would run past the window end is rejected');

insert into ids select 'b1', (public.create_booking('c0000000-0000-4000-8000-00000000005a',
                    (select v from t where k = 'd3_1000'), 'c0000000-0000-4000-8000-0000000000a1')).id;
select is((select ends_at - scheduled_at from public.bookings where id = (select v from ids where k = 'b1')),
          interval '120 minutes', 'ends_at uses the service duration');

-- customer B tries an overlapping slot (10:30-12:30 overlaps 10:00-12:00)
select set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-0000000000c2","role":"authenticated"}', true);
select throws_ok($$ select public.create_booking('c0000000-0000-4000-8000-00000000005a',
                    (select v from t where k = 'd3_1030'), 'c0000000-0000-4000-8000-0000000000a2') $$,
                 '23P01', null, 'overlapping bookings for one vendor are rejected (capacity 1)');
select is((select count(*) from public.get_available_slots('c0000000-0000-4000-8000-00000000005a', current_date + 3)),
          0::bigint, 'taken time no longer appears in slots');

-- ---------------------------------------------------------------------------
-- Vendor rejects (frees the slot)
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-0000000000f1","role":"authenticated"}', true);
select is((public.transition_booking((select v from ids where k = 'b1'), 'rejected', 'Fully booked')).status::text,
          'rejected', 'vendor can reject a pending booking');
select is((select vendor_response from public.bookings where id = (select v from ids where k = 'b1')), 'Fully booked',
          'rejection reason is stored as vendor_response');
select throws_ok(format('select public.transition_booking(%L, %L)', (select v from ids where k = 'b1'), 'confirmed'),
                 'P0001', null, 'rejected is terminal');

select set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-0000000000c2","role":"authenticated"}', true);
select lives_ok($$ select public.create_booking('c0000000-0000-4000-8000-00000000005a',
                   (select v from t where k = 'd3_1030'), 'c0000000-0000-4000-8000-0000000000a2') $$,
                'a rejected booking frees the slot');

-- ---------------------------------------------------------------------------
-- Customer cancel window (2 hours)
-- ---------------------------------------------------------------------------
reset role;
insert into public.bookings (id, reference, service_id, customer_id, vendor_id, status, scheduled_at,
                             address_snapshot, price_paise, currency, confirmed_at)
values ('c0000000-0000-4000-8000-0000000000b9', 'VNY-MKWIN1', 'c0000000-0000-4000-8000-00000000005a',
        'c0000000-0000-4000-8000-0000000000c1', 'c0000000-0000-4000-8000-0000000000f1', 'confirmed',
        now() + interval '90 minutes', '{}', 99900, 'INR', now());
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-0000000000c1","role":"authenticated"}', true);
select throws_ok($$ select public.transition_booking('c0000000-0000-4000-8000-0000000000b9', 'cancelled') $$,
                 'P0001', null, 'customer cannot cancel a confirmed booking within 2 hours of the start');
select set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-0000000000f1","role":"authenticated"}', true);
select lives_ok($$ select public.transition_booking('c0000000-0000-4000-8000-0000000000b9', 'cancelled', 'Customer called') $$,
                'vendor can still cancel with a reason');

-- ---------------------------------------------------------------------------
-- Availability and time off (vendor RLS)
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-0000000000f1","role":"authenticated"}', true);
select throws_ok($$ insert into public.vendor_availability (weekday, start_time, end_time) values (1, '12:00', '14:00') $$,
                 '23P01', null, 'availability windows cannot overlap');
select lives_ok($$ insert into public.vendor_time_off (period, reason)
                   values (tstzrange((current_date + 4 + time '00:00') at time zone 'Asia/Kolkata',
                                     (current_date + 5 + time '00:00') at time zone 'Asia/Kolkata'), 'Holiday') $$,
                'vendor adds time off');
select is((select count(*) from public.get_available_slots('c0000000-0000-4000-8000-00000000005a', current_date + 4)),
          0::bigint, 'time off removes slots');

select set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-0000000000f2","role":"authenticated"}', true);
select throws_ok($$ insert into public.vendor_availability (vendor_id, weekday, start_time, end_time)
                    values ('c0000000-0000-4000-8000-0000000000f1', 2, '15:00', '16:00') $$,
                 '42501', null, 'a vendor cannot edit another vendor''s availability');
select is((select count(*) from public.vendor_time_off), 0::bigint, 'a vendor cannot read another vendor''s time off');

-- ---------------------------------------------------------------------------
-- Favorites
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-0000000000c1","role":"authenticated"}', true);
select lives_ok($$ insert into public.favorites (service_id) values ('c0000000-0000-4000-8000-00000000005a') $$,
                'customer favorites a service');
select throws_ok($$ insert into public.favorites (service_id) values ('c0000000-0000-4000-8000-00000000005a') $$,
                 '23505', null, 'a favorite cannot be duplicated');
select throws_ok($$ insert into public.favorites (service_id, vendor_id)
                    values ('c0000000-0000-4000-8000-00000000005a', 'c0000000-0000-4000-8000-0000000000f1') $$,
                 '23514', null, 'a favorite targets exactly one service or vendor');
select throws_ok($$ insert into public.favorites (profile_id, vendor_id)
                    values ('c0000000-0000-4000-8000-0000000000c2', 'c0000000-0000-4000-8000-0000000000f1') $$,
                 '42501', null, 'cannot add a favorite for someone else');
select set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-0000000000c2","role":"authenticated"}', true);
select is((select count(*) from public.favorites), 0::bigint, 'favorites are private');

-- ---------------------------------------------------------------------------
-- Verification flow
-- ---------------------------------------------------------------------------
reset role;
insert into storage.objects (bucket_id, name, owner_id)
values ('verification-docs', 'c0000000-0000-4000-8000-0000000000f2/licence.pdf', 'c0000000-0000-4000-8000-0000000000f2');
set local role authenticated;

select set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-0000000000c1","role":"authenticated"}', true);
select throws_ok($$ select public.submit_vendor_verification(array['c0000000-0000-4000-8000-0000000000c1/x.pdf']) $$,
                 '42501', null, 'customers cannot submit verification');

select set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-0000000000f2","role":"authenticated"}', true);
select throws_ok($$ select public.submit_vendor_verification(array['c0000000-0000-4000-8000-0000000000f2/missing.pdf']) $$,
                 '22023', null, 'documents must exist in the vendor''s storage folder');
insert into ids select 'v1', (public.submit_vendor_verification(
  array['c0000000-0000-4000-8000-0000000000f2/licence.pdf'], 'Trade licence')).id;
select is((select vendor_status::text from public.get_my_access()), 'pending', 'submitting sets the vendor to pending');
select throws_ok($$ select public.submit_vendor_verification(array['c0000000-0000-4000-8000-0000000000f2/licence.pdf']) $$,
                 'P0001', null, 'only one open submission at a time');
select throws_ok(format('select public.admin_review_verification(%L, true)', (select v from ids where k = 'v1')),
                 '42501', null, 'a vendor cannot approve themselves');

select set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-0000000000ad","role":"authenticated"}', true);
select is((select count(*) from public.vendor_verifications where status = 'submitted'
             and vendor_id = 'c0000000-0000-4000-8000-0000000000f2'), 1::bigint, 'admin sees the verification queue');
select throws_ok(format('select public.admin_review_verification(%L, false)', (select v from ids where k = 'v1')),
                 '22023', null, 'rejecting requires a note');
select is((public.admin_review_verification((select v from ids where k = 'v1'), true, 'Licence checked')).status,
          'approved', 'admin approves verification');
select is((select is_admin from public.get_my_access()), true, 'get_my_access reports admin');

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select is((select count(*) from public.services where id = 'c0000000-0000-4000-8000-00000000005b'), 1::bigint,
          'after approval the vendor''s services become public');

reset role;
select is((select count(*) from public.notifications
            where user_id = 'c0000000-0000-4000-8000-0000000000f2' and type = 'vendor_verified'), 1::bigint,
          'vendor is notified of approval');
select is((select count(*) from public.admin_audit_log where action = 'verification.approve'), 1::bigint,
          'approval is audited');

select * from finish();
rollback;
