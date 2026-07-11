-- 20250601000600_content_groups.sql
-- Group-based content visibility. A student belongs to zero or more GROUPS; each
-- group is granted access to whole CATEGORIES and/or individual SUBCATEGORIES. A
-- student sees the UNION of what all their groups allow. A student in no group (or
-- whose groups grant nothing) sees NO content — access is opt-in.
--
-- Visibility is enforced in RLS (authoritative): the app's queries can't widen it.
-- Admins (profiles.role = 'admin') bypass all of it and see everything.
-- Depends on: 20250601000100 (tables, is_admin(), set_updated_at()).

-- ══════════════════════════════════════════════════════════════════════════════
-- Tables
-- ══════════════════════════════════════════════════════════════════════════════
create table if not exists public.groups (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  description text,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists idx_groups_sort on public.groups (sort_order);

drop trigger if exists groups_set_updated_at on public.groups;
create trigger groups_set_updated_at
  before update on public.groups
  for each row execute function public.set_updated_at();

-- Which students belong to a group (many-to-many).
create table if not exists public.group_members (
  group_id   uuid not null references public.groups (id) on delete cascade,
  student_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (group_id, student_id)
);
create index if not exists idx_group_members_student on public.group_members (student_id);

-- A group granted a WHOLE category — includes every current and future
-- subcategory under it.
create table if not exists public.group_categories (
  group_id    uuid not null references public.groups (id) on delete cascade,
  category_id uuid not null references public.categories (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (group_id, category_id)
);
create index if not exists idx_group_categories_category on public.group_categories (category_id);

-- A group granted a single subcategory (from a category it does not hold wholesale).
create table if not exists public.group_subcategories (
  group_id       uuid not null references public.groups (id) on delete cascade,
  subcategory_id uuid not null references public.subcategories (id) on delete cascade,
  created_at     timestamptz not null default now(),
  primary key (group_id, subcategory_id)
);
create index if not exists idx_group_subcategories_subcategory
  on public.group_subcategories (subcategory_id);

-- ══════════════════════════════════════════════════════════════════════════════
-- Visibility helpers. SECURITY DEFINER so they read the group tables without
-- tripping RLS (no recursion when a table's own policy calls them). STABLE so the
-- planner can cache within a statement. Both return true for admins.
-- ══════════════════════════════════════════════════════════════════════════════

-- Can the current user see this subcategory (and therefore posts inside it)?
create or replace function public.can_see_subcategory(subcat_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin() or exists (
    select 1
    from public.group_members gm
    join public.subcategories s on s.id = subcat_id
    where gm.student_id = auth.uid()
      and (
        exists (
          select 1 from public.group_categories gc
          where gc.group_id = gm.group_id and gc.category_id = s.category_id
        )
        or exists (
          select 1 from public.group_subcategories gs
          where gs.group_id = gm.group_id and gs.subcategory_id = subcat_id
        )
      )
  );
$$;

-- Can the current user see this category at all? True if any of their groups holds
-- the whole category or any subcategory within it — used so Browse hides empty
-- categories.
create or replace function public.can_see_category(cat_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin() or exists (
    select 1
    from public.group_members gm
    where gm.student_id = auth.uid()
      and (
        exists (
          select 1 from public.group_categories gc
          where gc.group_id = gm.group_id and gc.category_id = cat_id
        )
        or exists (
          select 1 from public.group_subcategories gs
          join public.subcategories s on s.id = gs.subcategory_id
          where gs.group_id = gm.group_id and s.category_id = cat_id
        )
      )
  );
$$;

-- ══════════════════════════════════════════════════════════════════════════════
-- Privileges (blanket grants in 000100 predate these tables, so grant explicitly).
-- Row visibility is still governed by the RLS policies below.
-- ══════════════════════════════════════════════════════════════════════════════
grant select on public.groups, public.group_members,
                 public.group_categories, public.group_subcategories to anon;
grant select, insert, update, delete on public.groups, public.group_members,
                 public.group_categories, public.group_subcategories to authenticated;
grant all on public.groups, public.group_members,
             public.group_categories, public.group_subcategories to service_role;
grant execute on function public.can_see_subcategory(uuid) to anon, authenticated;
grant execute on function public.can_see_category(uuid)    to anon, authenticated;

-- ══════════════════════════════════════════════════════════════════════════════
-- RLS on the new tables: only admins manage them from the client. (The student
-- serverless function uses service_role, which bypasses RLS, to assign members.)
-- ══════════════════════════════════════════════════════════════════════════════
alter table public.groups              enable row level security;
alter table public.group_members       enable row level security;
alter table public.group_categories    enable row level security;
alter table public.group_subcategories enable row level security;

drop policy if exists "groups_admin_all" on public.groups;
create policy "groups_admin_all" on public.groups
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "group_members_admin_all" on public.group_members;
create policy "group_members_admin_all" on public.group_members
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "group_categories_admin_all" on public.group_categories;
create policy "group_categories_admin_all" on public.group_categories
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "group_subcategories_admin_all" on public.group_subcategories;
create policy "group_subcategories_admin_all" on public.group_subcategories
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ══════════════════════════════════════════════════════════════════════════════
-- Re-gate content reads by group visibility. These REPLACE the open "read
-- published" policies from 000200 (which let every signed-in user see everything).
-- ══════════════════════════════════════════════════════════════════════════════

-- categories: only those the user's groups can reach (admins: all).
drop policy if exists "categories_read" on public.categories;
create policy "categories_read" on public.categories
  for select to anon, authenticated
  using (public.can_see_category(id));

-- subcategories: only granted ones (admins: all).
drop policy if exists "subcategories_read" on public.subcategories;
create policy "subcategories_read" on public.subcategories
  for select to anon, authenticated
  using (public.can_see_subcategory(id));

-- posts: published AND in a visible subcategory (admins: all, incl. drafts).
drop policy if exists "posts_read_published_or_admin" on public.posts;
create policy "posts_read_published_or_admin" on public.posts
  for select to anon, authenticated
  using (public.is_admin() or (published and public.can_see_subcategory(subcategory_id)));

-- post_tags: visible when the parent post is visible.
drop policy if exists "post_tags_read" on public.post_tags;
create policy "post_tags_read" on public.post_tags
  for select to anon, authenticated
  using (exists (
    select 1 from public.posts p
    where p.id = post_id
      and (public.is_admin() or (p.published and public.can_see_subcategory(p.subcategory_id)))
  ));

-- media: visible when the parent post is visible.
drop policy if exists "media_read" on public.media;
create policy "media_read" on public.media
  for select to anon, authenticated
  using (exists (
    select 1 from public.posts p
    where p.id = post_id
      and (public.is_admin() or (p.published and public.can_see_subcategory(p.subcategory_id)))
  ));

-- playlist_items: a playlist stays readable, but only surfaces posts the student
-- is allowed to see (published playlist + published, visible post).
drop policy if exists "playlist_items_read" on public.playlist_items;
create policy "playlist_items_read" on public.playlist_items
  for select to anon, authenticated
  using (
    public.is_admin() or (
      exists (
        select 1 from public.playlists pl
        where pl.id = playlist_id and pl.published
      )
      and exists (
        select 1 from public.posts p
        where p.id = post_id
          and p.published
          and public.can_see_subcategory(p.subcategory_id)
      )
    )
  );
