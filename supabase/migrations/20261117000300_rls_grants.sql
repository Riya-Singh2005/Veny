-- Veny: privileges and row level security (RLS_AUTHORIZATION.md §4).
-- Model: start from zero privileges for the API roles (anon, authenticated), then grant
-- exactly what each table needs. RLS decides which rows; column grants decide which columns.
-- service_role keeps Supabase's default full access (server-only key).

-- ===========================================================================
-- 1. Reset privileges for API roles
-- ===========================================================================
revoke all on all tables    in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;
revoke all on all functions in schema private from public, anon, authenticated;

-- Future objects created by migrations get no API privileges until granted explicitly.
alter default privileges for role postgres in schema public revoke all on tables    from anon, authenticated;
alter default privileges for role postgres in schema public revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema public revoke all on functions from public, anon, authenticated;
alter default privileges for role postgres in schema private revoke all on functions from public, anon, authenticated;

-- ===========================================================================
-- 2. Function EXECUTE grants
-- ===========================================================================
-- Policy helpers (evaluated inside policies, so the API roles need EXECUTE).
grant execute on function private.is_admin()                     to anon, authenticated;
grant execute on function private.is_vendor()                    to authenticated;
grant execute on function private.owns_service(uuid)             to authenticated;
grant execute on function private.owns_service_image_path(text)  to authenticated;
-- Helpers used by SECURITY INVOKER trigger functions.
grant execute on function private.set_updated_at()               to authenticated;
grant execute on function private.guard_profile_role()           to authenticated;
grant execute on function private.vendors_before_write()         to authenticated;
grant execute on function private.guard_booking_status()         to authenticated;
grant execute on function private.slugify(text)                  to authenticated;

-- Public RPCs.
grant execute on function public.search_services(text, text, int, int, float8, float8, int, text, int, int)
  to anon, authenticated;
grant execute on function public.create_booking(uuid, timestamptz, uuid, text)          to authenticated;
grant execute on function public.transition_booking(uuid, public.booking_status, text)  to authenticated;
grant execute on function public.create_review(uuid, int, text)                         to authenticated;
grant execute on function public.soft_delete_service(uuid)                              to authenticated;
grant execute on function public.get_booking_contact(uuid)                              to authenticated;
grant execute on function public.mark_notifications_read(uuid[])                        to authenticated;
grant execute on function public.get_my_vendor()                                        to authenticated;
grant execute on function public.admin_set_vendor_status(uuid, public.vendor_status, text) to authenticated;
grant execute on function public.admin_set_review_hidden(uuid, boolean, text)           to authenticated;
grant execute on function public.admin_set_service_hidden(uuid, boolean, text)          to authenticated;

-- ===========================================================================
-- 3. profiles: own row; admin reads all. Role is never client-writable.
-- ===========================================================================
grant select on public.profiles to authenticated;
grant update (full_name, phone_e164, avatar_path) on public.profiles to authenticated;

create policy profiles_select_own on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy profiles_select_admin on public.profiles
  for select to authenticated using ((select private.is_admin()));
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- ===========================================================================
-- 4. vendors: public profile columns only; contact/location via get_my_vendor()
-- ===========================================================================
grant select (profile_id, business_name, slug, bio, logo_path, status, verified_at, created_at)
  on public.vendors to anon, authenticated;
grant update (business_name, whatsapp_e164, bio, logo_path, base_location, service_radius_m)
  on public.vendors to authenticated;

create policy vendors_select_public on public.vendors
  for select to anon, authenticated using (status <> 'suspended');
create policy vendors_select_own on public.vendors
  for select to authenticated using (profile_id = (select auth.uid()));
create policy vendors_select_admin on public.vendors
  for select to authenticated using ((select private.is_admin()));
create policy vendors_update_own on public.vendors
  for update to authenticated
  using (profile_id = (select auth.uid())) with check (profile_id = (select auth.uid()));
-- vendors.status changes only through admin_set_vendor_status().

-- ===========================================================================
-- 5. categories: public read of active rows; admin manages (PD-13)
-- ===========================================================================
grant select on public.categories to anon, authenticated;
grant insert (slug, name, icon, sort_order, is_active) on public.categories to authenticated;
grant update (slug, name, icon, sort_order, is_active) on public.categories to authenticated;
grant delete on public.categories to authenticated;

create policy categories_select_active on public.categories
  for select to anon, authenticated using (is_active);
create policy categories_select_admin on public.categories
  for select to authenticated using ((select private.is_admin()));
create policy categories_insert_admin on public.categories
  for insert to authenticated with check ((select private.is_admin()));
create policy categories_update_admin on public.categories
  for update to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy categories_delete_admin on public.categories
  for delete to authenticated using ((select private.is_admin()));

-- ===========================================================================
-- 6. addresses: owner only; admin read
-- ===========================================================================
grant select, delete on public.addresses to authenticated;
grant insert (profile_id, label, line1, line2, area, city, state, postal_code, country_code,
              location, location_source, is_default) on public.addresses to authenticated;
grant update (label, line1, line2, area, city, state, postal_code, country_code,
              location, location_source, is_default) on public.addresses to authenticated;

create policy addresses_select_own on public.addresses
  for select to authenticated using (profile_id = (select auth.uid()));
create policy addresses_select_admin on public.addresses
  for select to authenticated using ((select private.is_admin()));
create policy addresses_insert_own on public.addresses
  for insert to authenticated with check (profile_id = (select auth.uid()));
create policy addresses_update_own on public.addresses
  for update to authenticated
  using (profile_id = (select auth.uid())) with check (profile_id = (select auth.uid()));
create policy addresses_delete_own on public.addresses
  for delete to authenticated using (profile_id = (select auth.uid()));

-- ===========================================================================
-- 7. services: public catalogue; owner manages editable columns (fixes SEC-04, BE-07)
-- ===========================================================================
grant select on public.services to anon, authenticated;
grant insert (vendor_id, category_id, slug, title, description, price_paise, duration_minutes,
              location, is_active) on public.services to authenticated;
grant update (category_id, title, description, price_paise, duration_minutes, location, is_active, slug)
  on public.services to authenticated;

create policy services_select_public on public.services
  for select to anon, authenticated
  using (is_active and deleted_at is null and hidden_at is null
         and exists (select 1 from public.vendors v
                      where v.profile_id = services.vendor_id and v.status <> 'suspended'));
create policy services_select_own on public.services
  for select to authenticated using (vendor_id = (select auth.uid()));
create policy services_select_admin on public.services
  for select to authenticated using ((select private.is_admin()));
create policy services_insert_own on public.services
  for insert to authenticated
  with check (vendor_id = (select auth.uid()) and (select private.is_vendor()));
create policy services_update_own on public.services
  for update to authenticated
  using (vendor_id = (select auth.uid()) and deleted_at is null)
  with check (vendor_id = (select auth.uid()));
-- Delete: soft_delete_service(). Hide/unhide: admin_set_service_hidden().

-- ===========================================================================
-- 8. service_images: visible when the parent service is visible; owner manages
-- ===========================================================================
grant select on public.service_images to anon, authenticated;
grant delete on public.service_images to authenticated;
grant insert (service_id, storage_path, alt_text, position) on public.service_images to authenticated;
grant update (alt_text, position) on public.service_images to authenticated;

create policy service_images_select on public.service_images
  for select to anon, authenticated
  using (exists (select 1 from public.services s where s.id = service_images.service_id));
create policy service_images_insert_own on public.service_images
  for insert to authenticated
  with check ((select private.owns_service(service_id))
              and storage_path like (select auth.uid())::text || '/' || service_id::text || '/%');
create policy service_images_update_own on public.service_images
  for update to authenticated
  using ((select private.owns_service(service_id))) with check ((select private.owns_service(service_id)));
create policy service_images_delete_own on public.service_images
  for delete to authenticated using ((select private.owns_service(service_id)));

-- ===========================================================================
-- 9. bookings: participants read; admin reads all; writes only via RPC
-- ===========================================================================
grant select on public.bookings to authenticated;

create policy bookings_select_participant on public.bookings
  for select to authenticated
  using (customer_id = (select auth.uid()) or vendor_id = (select auth.uid()));
create policy bookings_select_admin on public.bookings
  for select to authenticated using ((select private.is_admin()));

-- ===========================================================================
-- 10. booking_status_history: readable when the booking is readable
-- ===========================================================================
grant select on public.booking_status_history to authenticated;

create policy booking_history_select on public.booking_status_history
  for select to authenticated
  using (exists (select 1 from public.bookings b where b.id = booking_status_history.booking_id));

-- ===========================================================================
-- 11. reviews: public read of visible rows; author edits within 7 days; author deletes
-- ===========================================================================
grant select on public.reviews to anon, authenticated;
grant update (rating, comment) on public.reviews to authenticated;
grant delete on public.reviews to authenticated;

create policy reviews_select_visible on public.reviews
  for select to anon, authenticated using (not is_hidden);
create policy reviews_select_own on public.reviews
  for select to authenticated using (customer_id = (select auth.uid()));
create policy reviews_select_admin on public.reviews
  for select to authenticated using ((select private.is_admin()));
create policy reviews_update_own on public.reviews
  for update to authenticated
  using (customer_id = (select auth.uid()) and created_at > now() - interval '7 days')
  with check (customer_id = (select auth.uid()));
create policy reviews_delete_own on public.reviews
  for delete to authenticated using (customer_id = (select auth.uid()));
-- Insert: create_review(). Hide/unhide: admin_set_review_hidden().

-- ===========================================================================
-- 12. notifications: owner only; only read_at is writable (fixes SEC-09)
-- ===========================================================================
grant select, delete on public.notifications to authenticated;
grant update (read_at) on public.notifications to authenticated;

create policy notifications_select_own on public.notifications
  for select to authenticated using (user_id = (select auth.uid()));
create policy notifications_update_own on public.notifications
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy notifications_delete_own on public.notifications
  for delete to authenticated using (user_id = (select auth.uid()));

-- ===========================================================================
-- 13. admin tables
-- ===========================================================================
-- admin_users: RLS on, no policies, no grants. Service role / migrations only.
grant select on public.admin_audit_log to authenticated;
create policy admin_audit_log_select_admin on public.admin_audit_log
  for select to authenticated using ((select private.is_admin()));

-- ===========================================================================
-- 14. Realtime: only notifications and bookings (RLS_AUTHORIZATION.md §7)
-- ===========================================================================
alter publication supabase_realtime add table public.notifications, public.bookings;
