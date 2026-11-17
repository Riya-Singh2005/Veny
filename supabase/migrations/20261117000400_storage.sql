-- Veny: Storage buckets and policies (RLS_AUTHORIZATION.md §6).
-- Path conventions:
--   service-images: {vendor_id}/{service_id}/{uuid}.{ext}   public read, owner write
--   avatars:        {user_id}/{uuid}.{ext}                  public read, owner write
-- The private verification-docs bucket is deferred until PD-02 (vendor verification) is decided.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('service-images', 'service-images', true, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('avatars',        'avatars',        true, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- service-images: the vendor must own the service named in the path.
create policy service_images_obj_select_own on storage.objects
  for select to authenticated
  using (bucket_id = 'service-images' and (select private.owns_service_image_path(name)));
create policy service_images_obj_insert_own on storage.objects
  for insert to authenticated
  with check (bucket_id = 'service-images' and (select private.owns_service_image_path(name)));
create policy service_images_obj_update_own on storage.objects
  for update to authenticated
  using (bucket_id = 'service-images' and (select private.owns_service_image_path(name)))
  with check (bucket_id = 'service-images' and (select private.owns_service_image_path(name)));
create policy service_images_obj_delete_own on storage.objects
  for delete to authenticated
  using (bucket_id = 'service-images' and (select private.owns_service_image_path(name)));

-- avatars: first path segment is the user's id.
create policy avatars_obj_select_own on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy avatars_obj_insert_own on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy avatars_obj_update_own on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy avatars_obj_delete_own on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
