-- 20250601000200_rls_policies.sql
-- Row Level Security. Access model:
--   * anon + authenticated may READ published content (free, open access).
--   * admins (profiles.role = 'admin') may do everything.
--   * a student may read/write only their OWN view_history and user_achievements.
-- Depends on: 20250601000100 (tables + public.is_admin()).

alter table public.profiles          enable row level security;
alter table public.categories        enable row level security;
alter table public.subcategories     enable row level security;
alter table public.tags              enable row level security;
alter table public.posts             enable row level security;
alter table public.post_tags         enable row level security;
alter table public.media             enable row level security;
alter table public.playlists         enable row level security;
alter table public.playlist_items    enable row level security;
alter table public.view_history      enable row level security;
alter table public.achievements      enable row level security;
alter table public.user_achievements enable row level security;

-- ── profiles ──────────────────────────────────────────────────────────────────
-- Readable: your own row, any admin (teacher) row, and everything for admins.
create policy "profiles_select" on public.profiles
  for select to authenticated
  using (id = auth.uid() or role = 'admin' or public.is_admin());
create policy "profiles_insert_self" on public.profiles
  for insert to authenticated
  with check (id = auth.uid());
-- Self-updates allowed; the profiles_guard_role trigger still blocks role changes.
create policy "profiles_update_self_or_admin" on public.profiles
  for update to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());
create policy "profiles_delete_admin" on public.profiles
  for delete to authenticated
  using (public.is_admin());

-- ── Lookup tables: public read, admin write ───────────────────────────────────
create policy "categories_read" on public.categories
  for select to anon, authenticated using (true);
create policy "categories_admin_write" on public.categories
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "subcategories_read" on public.subcategories
  for select to anon, authenticated using (true);
create policy "subcategories_admin_write" on public.subcategories
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "tags_read" on public.tags
  for select to anon, authenticated using (true);
create policy "tags_admin_write" on public.tags
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "achievements_read" on public.achievements
  for select to anon, authenticated using (true);
create policy "achievements_admin_write" on public.achievements
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ── posts: read published (or admin), admin write ─────────────────────────────
create policy "posts_read_published_or_admin" on public.posts
  for select to anon, authenticated
  using (published or public.is_admin());
create policy "posts_admin_write" on public.posts
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ── post_tags / media: visible when the parent post is visible; admin write ───
create policy "post_tags_read" on public.post_tags
  for select to anon, authenticated
  using (exists (
    select 1 from public.posts p
    where p.id = post_id and (p.published or public.is_admin())
  ));
create policy "post_tags_admin_write" on public.post_tags
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "media_read" on public.media
  for select to anon, authenticated
  using (exists (
    select 1 from public.posts p
    where p.id = post_id and (p.published or public.is_admin())
  ));
create policy "media_admin_write" on public.media
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ── playlists / playlist_items: read published (or admin), admin write ────────
create policy "playlists_read_published_or_admin" on public.playlists
  for select to anon, authenticated
  using (published or public.is_admin());
create policy "playlists_admin_write" on public.playlists
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "playlist_items_read" on public.playlist_items
  for select to anon, authenticated
  using (exists (
    select 1 from public.playlists pl
    where pl.id = playlist_id and (pl.published or public.is_admin())
  ));
create policy "playlist_items_admin_write" on public.playlist_items
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ── view_history: a student owns their rows; admins may read/manage all ───────
create policy "view_history_select_own_or_admin" on public.view_history
  for select to authenticated
  using (student_id = auth.uid() or public.is_admin());
create policy "view_history_insert_own" on public.view_history
  for insert to authenticated
  with check (student_id = auth.uid());
create policy "view_history_update_own" on public.view_history
  for update to authenticated
  using (student_id = auth.uid())
  with check (student_id = auth.uid());
create policy "view_history_delete_own_or_admin" on public.view_history
  for delete to authenticated
  using (student_id = auth.uid() or public.is_admin());
create policy "view_history_admin_manage" on public.view_history
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ── user_achievements: a student owns their rows; admins may read/manage all ──
create policy "user_achievements_select_own_or_admin" on public.user_achievements
  for select to authenticated
  using (student_id = auth.uid() or public.is_admin());
create policy "user_achievements_insert_own" on public.user_achievements
  for insert to authenticated
  with check (student_id = auth.uid());
create policy "user_achievements_delete_own_or_admin" on public.user_achievements
  for delete to authenticated
  using (student_id = auth.uid() or public.is_admin());
create policy "user_achievements_admin_manage" on public.user_achievements
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
