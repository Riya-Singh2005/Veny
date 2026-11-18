-- Booking lifecycle, reviews and ratings (DATABASE_ARCHITECTURE.md §5 transition table).
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data) values
  ('b0000000-0000-4000-8000-0000000000c1', 'bk.cust.a@test.local', '{"full_name":"Priya Nair"}'),
  ('b0000000-0000-4000-8000-0000000000c2', 'bk.cust.b@test.local', '{"full_name":"Cust B"}'),
  ('b0000000-0000-4000-8000-0000000000f1', 'bk.vend.a@test.local', '{"full_name":"Vend A","role":"vendor"}'),
  ('b0000000-0000-4000-8000-0000000000ad', 'bk.admin@test.local',  '{"full_name":"Admin"}');
insert into public.admin_users (profile_id) values ('b0000000-0000-4000-8000-0000000000ad');
update public.vendors
   set base_location = extensions.st_setsrid(extensions.st_makepoint(77.39, 28.53), 4326)::extensions.geography,
       status = 'verified', verified_at = now()
 where profile_id = 'b0000000-0000-4000-8000-0000000000f1';
insert into public.vendor_availability (vendor_id, weekday, start_time, end_time)
select 'b0000000-0000-4000-8000-0000000000f1', d, '08:00', '20:00' from generate_series(0, 6) d;

insert into public.services (id, vendor_id, category_id, title, description, price_paise, is_active) values
  ('b0000000-0000-4000-8000-00000000005a', 'b0000000-0000-4000-8000-0000000000f1',
   (select id from public.categories where slug = 'plumber'), 'Tap repair', 'Fix leaking taps and mixers.', 29900, true),
  ('b0000000-0000-4000-8000-00000000005b', 'b0000000-0000-4000-8000-0000000000f1',
   (select id from public.categories where slug = 'plumber'), 'Paused job', 'Not currently offered here.', 9900, false);

insert into public.addresses (id, profile_id, line1, area, city, state, postal_code, location_source, is_default) values
  ('b0000000-0000-4000-8000-0000000000a1', 'b0000000-0000-4000-8000-0000000000c1', '7 Park St', 'Sector 18', 'Noida', 'UP', '201301', 'geocoded', true),
  ('b0000000-0000-4000-8000-0000000000a2', 'b0000000-0000-4000-8000-0000000000c2', '9 Ring Rd', 'Saket', 'Delhi', 'DL', '110017', 'gps', true),
  ('b0000000-0000-4000-8000-0000000000a3', 'b0000000-0000-4000-8000-0000000000f1', '1 Vendor Ln', 'Sector 5', 'Noida', 'UP', null, 'gps', true);

create temporary table ids (k text primary key, v uuid) on commit drop;
grant all on ids to authenticated;

-- ---------------------------------------------------------------------------
-- create_booking (customer A)
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b0000000-0000-4000-8000-0000000000c1","role":"authenticated"}', true);

select throws_ok($$ select public.create_booking('b0000000-0000-4000-8000-00000000005a', now() + interval '10 minutes',
                                                 'b0000000-0000-4000-8000-0000000000a1') $$,
                 '22023', null, 'bookings must be at least 1 hour ahead');
select throws_ok($$ select public.create_booking('b0000000-0000-4000-8000-00000000005a', (current_date + 2 + time '10:00') at time zone 'Asia/Kolkata',
                                                 'b0000000-0000-4000-8000-0000000000a2') $$,
                 'P0002', null, 'cannot book with another user''s address (BUG-02)');
select throws_ok($$ select public.create_booking('b0000000-0000-4000-8000-00000000005b', (current_date + 2 + time '10:00') at time zone 'Asia/Kolkata',
                                                 'b0000000-0000-4000-8000-0000000000a1') $$,
                 'P0001', null, 'cannot book a paused service');

insert into ids select 'b1', (public.create_booking('b0000000-0000-4000-8000-00000000005a', (current_date + 2 + time '10:00') at time zone 'Asia/Kolkata',
                                                    'b0000000-0000-4000-8000-0000000000a1', '  Ring the bell  ')).id;
insert into ids select 'b2', (public.create_booking('b0000000-0000-4000-8000-00000000005a', (current_date + 3 + time '10:00') at time zone 'Asia/Kolkata',
                                                    'b0000000-0000-4000-8000-0000000000a1')).id;

select is((select status::text from public.bookings where id = (select v from ids where k = 'b1')), 'pending',
          'new booking is pending');
select is((select vendor_id from public.bookings where id = (select v from ids where k = 'b1')),
          'b0000000-0000-4000-8000-0000000000f1'::uuid, 'vendor_id is taken from the service, not the client');
select is((select price_paise from public.bookings where id = (select v from ids where k = 'b1')), 29900,
          'price is snapshotted');
select is((select address_snapshot ->> 'postal_code' from public.bookings where id = (select v from ids where k = 'b1')),
          '201301', 'address is snapshotted');
select is((select customer_notes from public.bookings where id = (select v from ids where k = 'b1')), 'Ring the bell',
          'notes are trimmed');
select matches((select reference from public.bookings where id = (select v from ids where k = 'b1')), '^VNY-[0-9A-Z]{6}$',
               'booking gets a readable reference');
select throws_ok(format('select public.transition_booking(%L, %L)', (select v from ids where k = 'b1'), 'confirmed'),
                 'P0001', null, 'a customer cannot confirm a booking');

-- vendor cannot book their own service
select set_config('request.jwt.claims', '{"sub":"b0000000-0000-4000-8000-0000000000f1","role":"authenticated"}', true);
select throws_ok($$ select public.create_booking('b0000000-0000-4000-8000-00000000005a', (current_date + 2 + time '10:00') at time zone 'Asia/Kolkata',
                                                 'b0000000-0000-4000-8000-0000000000a3') $$,
                 'P0001', null, 'a vendor cannot book their own service');
select is((select count(*) from public.notifications where type = 'booking_new'), 2::bigint,
          'vendor is notified of each new booking');

-- ---------------------------------------------------------------------------
-- Vendor drives b1 through the happy path
-- ---------------------------------------------------------------------------
select throws_ok(format('select public.transition_booking(%L, %L)', (select v from ids where k = 'b1'), 'completed'),
                 'P0001', null, 'pending -> completed is not allowed');
select throws_ok(format('select public.transition_booking(%L, %L)', (select v from ids where k = 'b1'), 'cancelled'),
                 '22023', null, 'a vendor must give a reason to cancel');
select is((public.transition_booking((select v from ids where k = 'b1'), 'confirmed')).status::text, 'confirmed',
          'vendor confirms');
select is((public.transition_booking((select v from ids where k = 'b1'), 'in_progress')).status::text, 'in_progress',
          'vendor starts the job');

select set_config('request.jwt.claims', '{"sub":"b0000000-0000-4000-8000-0000000000c1","role":"authenticated"}', true);
select is((select name from public.get_booking_contact((select v from ids where k = 'b1'))), 'Vend A',
          'customer sees vendor contact while the job is active');
select throws_ok(format('select public.transition_booking(%L, %L)', (select v from ids where k = 'b1'), 'cancelled'),
                 'P0001', null, 'a customer cannot cancel a job in progress');
select throws_ok(format('select public.create_review(%L, 5)', (select v from ids where k = 'b1')),
                 'P0001', null, 'cannot review before completion');

select set_config('request.jwt.claims', '{"sub":"b0000000-0000-4000-8000-0000000000f1","role":"authenticated"}', true);
select is((public.transition_booking((select v from ids where k = 'b1'), 'completed')).status::text, 'completed',
          'vendor completes the job');
select isnt((select completed_at from public.bookings where id = (select v from ids where k = 'b1')), null,
            'completed_at is set (BE-08)');
select throws_ok(format('select public.transition_booking(%L, %L, %L)', (select v from ids where k = 'b1'), 'cancelled', 'x'),
                 'P0001', null, 'completed is terminal');

-- ---------------------------------------------------------------------------
-- Reviews and ratings
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"b0000000-0000-4000-8000-0000000000c2","role":"authenticated"}', true);
select throws_ok(format('select public.create_review(%L, 5)', (select v from ids where k = 'b1')),
                 'P0001', null, 'another customer cannot review the booking');

select set_config('request.jwt.claims', '{"sub":"b0000000-0000-4000-8000-0000000000c1","role":"authenticated"}', true);
select throws_ok(format('select public.create_review(%L, 6)', (select v from ids where k = 'b1')),
                 '22023', null, 'rating must be 1-5');
insert into ids select 'r1', (public.create_review((select v from ids where k = 'b1'), 4, 'Good job')).id;
select is((select author_name from public.reviews where id = (select v from ids where k = 'r1')), 'Priya N.',
          'review author is shown as first name + initial');
select throws_ok(format('select public.create_review(%L, 5)', (select v from ids where k = 'b1')),
                 '23505', null, 'one review per booking');
select is((select avg_rating from public.services where id = 'b0000000-0000-4000-8000-00000000005a'), 4.0,
          'rating is recalculated on insert');
update public.reviews set rating = 2 where id = (select v from ids where k = 'r1');
select is((select avg_rating from public.services where id = 'b0000000-0000-4000-8000-00000000005a'), 2.0,
          'rating is recalculated when the author edits');

-- Customer cancels b2 (no reason required)
select is((public.transition_booking((select v from ids where k = 'b2'), 'cancelled')).status::text, 'cancelled',
          'customer cancels a pending booking');

-- ---------------------------------------------------------------------------
-- Admin
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"b0000000-0000-4000-8000-0000000000ad","role":"authenticated"}', true);
select lives_ok(format('select public.admin_set_review_hidden(%L, true, %L)', (select v from ids where k = 'r1'), 'Spam'),
                'admin hides a review');

reset role;
select is((select review_count from public.services where id = 'b0000000-0000-4000-8000-00000000005a'), 0,
          'hidden reviews are excluded from the count');
select is((select count(*) from public.booking_status_history where booking_id = (select v from ids where k = 'b1')),
          4::bigint, 'every transition is recorded in history');
select is((select changed_by from public.booking_status_history
            where booking_id = (select v from ids where k = 'b2') and to_status = 'cancelled'),
          'b0000000-0000-4000-8000-0000000000c1'::uuid, 'history records who cancelled');

-- Admin cancels an in-progress booking (PD-13 b)
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b0000000-0000-4000-8000-0000000000c2","role":"authenticated"}', true);
insert into ids select 'b3', (public.create_booking('b0000000-0000-4000-8000-00000000005a', (current_date + 1 + time '10:00') at time zone 'Asia/Kolkata',
                                                    'b0000000-0000-4000-8000-0000000000a2')).id;
select set_config('request.jwt.claims', '{"sub":"b0000000-0000-4000-8000-0000000000f1","role":"authenticated"}', true);
select lives_ok(format('select public.transition_booking(%L, %L)', (select v from ids where k = 'b3'), 'confirmed'), 'confirm b3');
select lives_ok(format('select public.transition_booking(%L, %L)', (select v from ids where k = 'b3'), 'in_progress'), 'start b3');
select set_config('request.jwt.claims', '{"sub":"b0000000-0000-4000-8000-0000000000ad","role":"authenticated"}', true);
select throws_ok(format('select public.transition_booking(%L, %L)', (select v from ids where k = 'b3'), 'cancelled'),
                 '22023', null, 'admin must give a reason');
select throws_ok(format('select public.transition_booking(%L, %L, %L)', (select v from ids where k = 'b3'), 'completed', 'x'),
                 'P0001', null, 'admin cannot complete a booking');
select is((public.transition_booking((select v from ids where k = 'b3'), 'cancelled', 'Dispute')).status::text, 'cancelled',
          'admin cancels an in-progress booking');

reset role;
select is((select count(*) from public.admin_audit_log where action = 'booking.cancel'), 1::bigint,
          'admin cancellation is audited');
select is((select count(*) from public.notifications
            where booking_id = (select v from ids where k = 'b3') and type = 'booking_cancelled'), 2::bigint,
          'both parties are notified of an admin cancellation');

select * from finish();
rollback;
