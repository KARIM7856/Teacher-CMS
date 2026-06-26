-- 20250601000300_storage.sql
-- Storage buckets and object-level access policies.
--
--   media          : PRIVATE bucket for post attachments (video/pdf/other).
--                    Readable by anyone only when the owning post is published;
--                    writable by admins only.
--   public-assets  : PUBLIC bucket for non-sensitive images (category icons,
--                    playlist covers, avatars). World-readable; admin write.
--
-- Convention: media.storage_path holds the object's path (the storage.objects
-- "name") within the "media" bucket — that linkage is what gates read access.
-- Depends on: 20250601000100 (public.media / public.posts + public.is_admin()).

insert into storage.buckets (id, name, public)
values ('media', 'media', false)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('public-assets', 'public-assets', true)
on conflict (id) do nothing;

-- ── media bucket: read only published media (or admin) ────────────────────────
create policy "media_read_published_or_admin" on storage.objects
  for select to anon, authenticated
  using (
    bucket_id = 'media'
    and (
      public.is_admin()
      or exists (
        select 1
        from public.media m
        join public.posts p on p.id = m.post_id
        where m.storage_path = storage.objects.name
          and p.published
      )
    )
  );

create policy "media_admin_insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'media' and public.is_admin());

create policy "media_admin_update" on storage.objects
  for update to authenticated
  using (bucket_id = 'media' and public.is_admin())
  with check (bucket_id = 'media' and public.is_admin());

create policy "media_admin_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'media' and public.is_admin());

-- ── public-assets bucket: world read, admin write ─────────────────────────────
-- (Bucket is public=true, so reads are served via the public URL; this SELECT
-- policy covers the storage API / listing path.)
create policy "public_assets_read" on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'public-assets');

create policy "public_assets_admin_insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'public-assets' and public.is_admin());

create policy "public_assets_admin_update" on storage.objects
  for update to authenticated
  using (bucket_id = 'public-assets' and public.is_admin())
  with check (bucket_id = 'public-assets' and public.is_admin());

create policy "public_assets_admin_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'public-assets' and public.is_admin());
