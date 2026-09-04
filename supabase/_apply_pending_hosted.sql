-- ============================================================================
-- Teacher-CMS — pending hosted-DB migrations (000600, 000700, 000800)
--
-- The hosted project already has 000000-000500. These three are the ones listed
-- as pending in /CLAUDE.md. Run ONCE via:
--   Supabase Dashboard -> SQL Editor -> New query -> paste -> Run.
--
-- All three are idempotent (create ... if not exists, drop policy if exists,
-- on conflict do nothing), so re-running is harmless. That matters here: the
-- hosted SQL Editor treats a pasted script as ONE transaction, so any error
-- rolls back the whole thing and you simply paste again after fixing it.
--
-- *** READ BEFORE RUNNING ***
-- 000600 switches content visibility to group-based. The moment it lands, every
-- student sees NOTHING until they are put in a group that has been granted
-- categories. Plan to create the groups and assign students immediately after,
-- in the admin portal (المجموعات then الطلاب).
--
-- This file is a verbatim concatenation of the three migrations below, in order.
-- They remain the source of truth: edit them, then rebuild this file by pasting
-- their contents again in the same order. Nothing here is rewritten or reordered,
-- so a diff against the migrations should show only these header comments.
-- ============================================================================


-- ============================================================================
-- >>> migrations/20250601000600_content_groups.sql
-- ============================================================================

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

-- ============================================================================
-- >>> migrations/20250601000700_student_import_fields.sql
-- ============================================================================

-- 20250601000700_student_import_fields.sql
-- Roster fields for bulk student import from the teacher's Excel sheets.
--
-- The admin portal can import a workbook (one sheet per class) and create the
-- student accounts in bulk. Two identifying fields from that sheet are worth
-- keeping on the profile so an app account can later be reconciled with the
-- teacher's own roster:
--   • serial_number — الرقم التسلسلي (the student's serial in the class list)
--   • request_code  — كود الطلب     (the per-student request/enrolment code)
-- Both are free-form text (they may carry leading zeros or non-numeric forms),
-- nullable (pre-existing and manually-created students won't have them), and
-- admin-facing only — the student app never reads them.
-- Depends on: 20250601000100 (profiles table).

alter table public.profiles
  add column if not exists serial_number text,
  add column if not exists request_code  text;

comment on column public.profiles.serial_number is
  'الرقم التسلسلي from the teacher''s class sheet (bulk import). Free-form text.';
comment on column public.profiles.request_code is
  'كود الطلب from the teacher''s class sheet (bulk import). Free-form text.';

-- No RLS change needed: profiles policies already let admins read/write every
-- column and let a student read only their own row. These columns inherit that.

-- ============================================================================
-- >>> migrations/20250601000800_guest_content.sql
-- ============================================================================

-- 20250601000800_guest_content.sql
-- Guest access: a single shared "guest" student can browse one public category.
--
-- The app's sign-in screen has a "الدخول كضيف" (log in as guest) button that
-- signs in with a shared guest account. Content visibility is entirely
-- group-based (see 20250601000600_content_groups.sql): a student sees the union
-- of the categories/subcategories granted to their groups. So the "guest" is
-- just an ordinary student whose one group grants a single "guest" category.
--
-- This migration provisions the data side of that: the guest category, the
-- guest group, and the grant linking them. It is idempotent (fixed UUIDs +
-- `on conflict do nothing`), matching the style of seed.sql.
--
-- TWO MANUAL FOLLOW-UPS (can't be done safely in SQL):
--   (a) In the admin portal, author a subcategory + at least one PUBLISHED post
--       under the "guest" category. The category grant already covers any
--       subcategories added later, so no further grant is needed.
--   (b) In the الطلاب (Students) page, create the guest student account
--       (username = the app's GUEST_USERNAME dart-define, password = its
--       GUEST_PASSWORD) and assign it to the "الضيوف" group created below.
--       Auth users must be created via the Admin API — a raw auth.users insert
--       leaves NULL token columns and breaks login (the known login-500).
-- Depends on: 20250601000100 (categories) and 20250601000600 (groups + grants).

-- The public "guest" category. Renameable from the admin portal; the slug is
-- what matters as a stable handle.
insert into public.categories (id, name, slug, sort_order) values
  ('cccccccc-0000-4000-8000-000000000001', 'محتوى الضيف', 'guest', 1000)
on conflict (slug) do nothing;

-- The group every guest belongs to. sort_order 1000 keeps it out of the way in
-- the admin group list.
insert into public.groups (id, name, description, sort_order) values
  ('a0000000-0000-4000-8000-000000000001', 'الضيوف',
   'المجموعة الافتراضية لحساب الضيف — تمنح الوصول إلى فئة «محتوى الضيف».', 1000)
on conflict (id) do nothing;

-- Grant the whole guest category (incl. future subcategories) to the guest
-- group. Looked up by slug so it still works if a "guest" category already
-- existed under a different id (the insert above was then a no-op).
insert into public.group_categories (group_id, category_id)
select 'a0000000-0000-4000-8000-000000000001', c.id
from public.categories c
where c.slug = 'guest'
on conflict do nothing;
