-- ============================================================================
-- Teacher-CMS — full hosted DB setup (5 migrations + Arabic sample seed)
-- Generated helper. Run ONCE on the EMPTY hosted project via:
--   Supabase Dashboard -> SQL Editor -> New query -> paste -> Run.
-- Demo admin created by the seed:  teacher@example.com / password123
-- ============================================================================

-- ============================================================================
-- >>> migrations/20250601000000_init_extensions_and_helpers.sql
-- ============================================================================

-- 20250601000000_init_extensions_and_helpers.sql
-- Extensions, enum types, and table-independent helper functions.
-- This must run before the core schema (which uses these types/functions).

-- ── Extensions (Supabase keeps these in the "extensions" schema) ──────────────
create extension if not exists pgcrypto with schema extensions;  -- crypt(), gen_salt()
create extension if not exists pg_trgm  with schema extensions;  -- trigram search
create extension if not exists unaccent with schema extensions;  -- diacritic folding
-- gen_random_uuid() is built into Postgres 13+ (no extension needed).

-- ── Enum types ────────────────────────────────────────────────────────────────
do $$ begin
  create type public.user_role as enum ('student', 'admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.media_type as enum ('video', 'pdf', 'other');
exception when duplicate_object then null; end $$;

-- ── Arabic text normalization (search/sort helper) ────────────────────────────
-- Folds an Arabic string to a canonical form so search matches regardless of how
-- the text was typed:
--   * lowercases any embedded Latin characters
--   * unifies alef / hamza / yaa / taa-marbuta variants (alef forms->ا, ى ئ->ي, ؤ->و, ة->ه)
--   * strips tashkil (harakat, U+064B-U+065F, U+0670) and the tatweel mark (U+0640)
-- Marked IMMUTABLE so it can back a STORED generated column and a GIN index.
create or replace function public.normalize_arabic(input text)
returns text
language sql
immutable
as $$
  select case
    when input is null then null
    else regexp_replace(
           translate(lower(input), 'أإآٱىئؤةـ', 'ااااييوه'),
           E'[ً-ٰٟـ]', '', 'g'
         )
  end;
$$;

comment on function public.normalize_arabic(text)
  is 'Canonical Arabic form for search: folds alef/hamza/yaa/taa variants and strips diacritics.';

-- ── Generic updated_at bump trigger ───────────────────────────────────────────
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;


-- ============================================================================
-- >>> migrations/20250601000100_core_schema.sql
-- ============================================================================

-- 20250601000100_core_schema.sql
-- Core tables, foreign keys, indexes, and row-level triggers.
-- Depends on: 20250601000000 (enum types + helper functions).

-- ══════════════════════════════════════════════════════════════════════════════
-- profiles — one row per auth user; carries role (student/admin) and display info
-- ══════════════════════════════════════════════════════════════════════════════
create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  role         public.user_role not null default 'student',
  display_name text,
  avatar_url   text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index idx_profiles_role on public.profiles (role);

-- Is the *current* request an admin? SECURITY DEFINER so it reads profiles
-- without triggering RLS — this lets other tables' policies call it safely
-- (no recursion) and keeps the role check in one place.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

-- Auto-create a profile row whenever a new auth user signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', new.email))
  on conflict (id) do nothing;
  return new;
end;
$$;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Guard against privilege escalation: a signed-in non-admin cannot change a
-- profile's role. Trusted server contexts (no JWT -> auth.uid() is null, e.g.
-- the service role or seeding) are allowed through.
create or replace function public.enforce_profile_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.role is distinct from old.role
     and auth.uid() is not null
     and not public.is_admin() then
    raise exception 'only admins can change a profile role';
  end if;
  return new;
end;
$$;
create trigger profiles_guard_role
  before update on public.profiles
  for each row execute function public.enforce_profile_role();

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ══════════════════════════════════════════════════════════════════════════════
-- categories -> subcategories  (content taxonomy)
-- ══════════════════════════════════════════════════════════════════════════════
create table public.categories (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  slug       text not null unique,
  icon       text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index idx_categories_sort on public.categories (sort_order);

create trigger categories_set_updated_at
  before update on public.categories
  for each row execute function public.set_updated_at();

create table public.subcategories (
  id          uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.categories (id) on delete cascade,
  name        text not null,
  slug        text not null,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (category_id, slug)
);
create index idx_subcategories_category on public.subcategories (category_id);
create index idx_subcategories_sort on public.subcategories (sort_order);

create trigger subcategories_set_updated_at
  before update on public.subcategories
  for each row execute function public.set_updated_at();

-- ══════════════════════════════════════════════════════════════════════════════
-- tags — freeform labels
-- ══════════════════════════════════════════════════════════════════════════════
create table public.tags (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  slug       text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger tags_set_updated_at
  before update on public.tags
  for each row execute function public.set_updated_at();

-- ══════════════════════════════════════════════════════════════════════════════
-- posts — the main content unit
-- ══════════════════════════════════════════════════════════════════════════════
create table public.posts (
  id             uuid primary key default gen_random_uuid(),
  title          text not null,
  body           text,                    -- markdown / rich text
  subcategory_id uuid not null references public.subcategories (id) on delete restrict,
  author_id      uuid references public.profiles (id) on delete set null,
  published      boolean not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  -- Normalized title+body for Arabic-aware search (see normalize_arabic()).
  search_text    text generated always as (
    public.normalize_arabic(coalesce(title, '') || ' ' || coalesce(body, ''))
  ) stored
);
create index idx_posts_subcategory      on public.posts (subcategory_id);
create index idx_posts_author           on public.posts (author_id);
create index idx_posts_published_created on public.posts (published, created_at desc);
create index idx_posts_search           on public.posts using gin (search_text extensions.gin_trgm_ops);

create trigger posts_set_updated_at
  before update on public.posts
  for each row execute function public.set_updated_at();

-- ══════════════════════════════════════════════════════════════════════════════
-- post_tags — many-to-many posts <-> tags
-- ══════════════════════════════════════════════════════════════════════════════
create table public.post_tags (
  post_id uuid not null references public.posts (id) on delete cascade,
  tag_id  uuid not null references public.tags (id) on delete cascade,
  primary key (post_id, tag_id)
);
create index idx_post_tags_tag on public.post_tags (tag_id);

-- ══════════════════════════════════════════════════════════════════════════════
-- media — files attached to a post (video / pdf / other)
-- ══════════════════════════════════════════════════════════════════════════════
create table public.media (
  id           uuid primary key default gen_random_uuid(),
  post_id      uuid not null references public.posts (id) on delete cascade,
  type         public.media_type not null,
  storage_path text,        -- object path within the "media" storage bucket, or
  external_url text,        -- an external/embedded URL — at least one is required
  display_name text,
  sort_order   integer not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint media_has_source check (storage_path is not null or external_url is not null)
);
create index idx_media_post      on public.media (post_id);
create index idx_media_post_sort on public.media (post_id, sort_order);

create trigger media_set_updated_at
  before update on public.media
  for each row execute function public.set_updated_at();

-- ══════════════════════════════════════════════════════════════════════════════
-- playlists -> playlist_items  (ordered collections of posts)
-- ══════════════════════════════════════════════════════════════════════════════
create table public.playlists (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  description text,
  cover_image text,
  published   boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index idx_playlists_published on public.playlists (published);

create trigger playlists_set_updated_at
  before update on public.playlists
  for each row execute function public.set_updated_at();

create table public.playlist_items (
  id          uuid primary key default gen_random_uuid(),
  playlist_id uuid not null references public.playlists (id) on delete cascade,
  post_id     uuid not null references public.posts (id) on delete cascade,
  position    integer not null,
  created_at  timestamptz not null default now(),
  unique (playlist_id, post_id),
  -- Deferrable so a whole playlist can be re-ordered inside one transaction.
  constraint playlist_items_position_unique unique (playlist_id, position)
    deferrable initially deferred
);
create index idx_playlist_items_playlist on public.playlist_items (playlist_id, position);
create index idx_playlist_items_post     on public.playlist_items (post_id);

-- ══════════════════════════════════════════════════════════════════════════════
-- view_history — one row per (student, post); "continue where you left off"
-- ══════════════════════════════════════════════════════════════════════════════
create table public.view_history (
  student_id       uuid not null references public.profiles (id) on delete cascade,
  post_id          uuid not null references public.posts (id) on delete cascade,
  progress_seconds integer not null default 0 check (progress_seconds >= 0),
  created_at       timestamptz not null default now(),
  last_viewed_at   timestamptz not null default now(),
  primary key (student_id, post_id)
);
create index idx_view_history_recent on public.view_history (student_id, last_viewed_at desc);
create index idx_view_history_post   on public.view_history (post_id);

-- Bump last_viewed_at on every update (re-view or progress change).
create or replace function public.touch_last_viewed()
returns trigger
language plpgsql
as $$
begin
  new.last_viewed_at = now();
  return new;
end;
$$;
create trigger view_history_touch
  before update on public.view_history
  for each row execute function public.touch_last_viewed();

-- ══════════════════════════════════════════════════════════════════════════════
-- achievements -> user_achievements
-- ══════════════════════════════════════════════════════════════════════════════
create table public.achievements (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,    -- stable identifier the app references
  title       text not null,
  description text,
  icon        text,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create trigger achievements_set_updated_at
  before update on public.achievements
  for each row execute function public.set_updated_at();

create table public.user_achievements (
  student_id     uuid not null references public.profiles (id) on delete cascade,
  achievement_id uuid not null references public.achievements (id) on delete cascade,
  unlocked_at    timestamptz not null default now(),
  primary key (student_id, achievement_id)
);
create index idx_user_achievements_achievement on public.user_achievements (achievement_id);

-- ══════════════════════════════════════════════════════════════════════════════
-- Base privileges for the API roles. Row visibility is governed by RLS, which is
-- enabled in the next migration; these grants just let the roles attempt access.
-- ══════════════════════════════════════════════════════════════════════════════
grant usage on schema public to anon, authenticated;
grant select on all tables in schema public to anon;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant all on all tables in schema public to service_role;
grant execute on function public.is_admin()        to anon, authenticated;
grant execute on function public.normalize_arabic(text) to anon, authenticated;


-- ============================================================================
-- >>> migrations/20250601000200_rls_policies.sql
-- ============================================================================

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


-- ============================================================================
-- >>> migrations/20250601000300_storage.sql
-- ============================================================================

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


-- ============================================================================
-- >>> migrations/20250601000400_achievements_engine.sql
-- ============================================================================

-- 20250601000400_achievements_engine.sql
-- Server-side achievement detection.
--
-- Adds a lightweight daily-activity log (for streaks), ensures the starter
-- achievement set exists, and exposes claim_achievements(): the app calls it
-- after activity, and it records today's activity, grants any newly-earned
-- achievements, and RETURNS the freshly granted ones so the client can
-- celebrate exactly what was just unlocked.
--
-- Detection lives in Postgres (authoritative): the client cannot fabricate an
-- unlock — it can only ask the server to evaluate the rules for the current user.
--
-- Depends on: 20250601000100 (tables + is_admin()), 20250601000200 (RLS).

-- ── student_activity: one row per (student, calendar day) of activity ─────────
-- view_history keeps only the latest timestamp per post, which can't express a
-- multi-day streak; this small log records each active day instead.
create table if not exists public.student_activity (
  student_id    uuid not null references public.profiles (id) on delete cascade,
  activity_date date not null default current_date,
  primary key (student_id, activity_date)
);
create index if not exists idx_student_activity_student
  on public.student_activity (student_id, activity_date desc);

alter table public.student_activity enable row level security;

create policy "student_activity_select_own_or_admin" on public.student_activity
  for select to authenticated
  using (student_id = auth.uid() or public.is_admin());
create policy "student_activity_insert_own" on public.student_activity
  for insert to authenticated
  with check (student_id = auth.uid());
create policy "student_activity_admin_manage" on public.student_activity
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

grant select, insert on public.student_activity to authenticated;

-- ── Starter achievement definitions (idempotent; the app keys off `code`) ─────
-- The two codes that also appear in seed.sql reuse the seed UUIDs, so seed's
-- `on conflict (id) do nothing` stays correct and no seed edit is needed.
insert into public.achievements (id, code, title, description, icon, sort_order) values
  ('fa111111-1111-1111-1111-111111111111', 'first_view',     'الخطوة الأولى',      'شاهدت أول درس لك.',        'star',   1),
  ('fa444444-4444-4444-4444-444444444444', 'views_25',       'متعلّم مثابر',       'شاهدت 25 درسًا.',          'school', 2),
  ('fa555555-5555-5555-5555-555555555555', 'streak_5_days',  'خمسة أيام متتالية',  'تعلّمت 5 أيام متتالية.',   'fire',   3),
  ('fa333333-3333-3333-3333-333333333333', 'first_playlist', 'رحلة منظَّمة',        'أكملت أول قائمة تشغيل.',   'trophy', 4)
on conflict (code) do nothing;

-- ── claim_achievements(): record activity, grant newly-earned, return them ────
-- SECURITY DEFINER so it can write user_achievements regardless of the caller's
-- RLS; it always acts on the current user (auth.uid()) and never trusts input.
create or replace function public.claim_achievements()
returns table (code text, title text, description text, icon text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student uuid := auth.uid();
begin
  if v_student is null then
    return; -- not signed in: nothing to claim
  end if;

  -- Record today's activity (drives the streak rule).
  insert into public.student_activity (student_id, activity_date)
  values (v_student, current_date)
  on conflict do nothing;

  return query
  with viewed as (
    select count(distinct vh.post_id) as n
    from public.view_history vh
    where vh.student_id = v_student
  ),
  days as (
    select distinct activity_date as d
    from public.student_activity
    where student_id = v_student
  ),
  -- Gaps-and-islands: consecutive days share the same (date - row_number()).
  islands as (
    select d, d - (row_number() over (order by d))::int as grp
    from days
  ),
  streak as (
    select count(*) as len
    from islands
    where grp = (select grp from islands where d = current_date)
  ),
  completed_playlist as (
    select exists (
      select 1
      from public.playlists pl
      where pl.published
        and exists (
          select 1 from public.playlist_items pi where pi.playlist_id = pl.id
        )
        and not exists (
          select 1
          from public.playlist_items pi
          where pi.playlist_id = pl.id
            and pi.post_id not in (
              select vh.post_id
              from public.view_history vh
              where vh.student_id = v_student
            )
        )
    ) as done
  ),
  earned as (
    select a.id
    from public.achievements a
    where (a.code = 'first_view'     and (select n   from viewed) >= 1)
       or (a.code = 'five_views'     and (select n   from viewed) >= 5)
       or (a.code = 'views_25'       and (select n   from viewed) >= 25)
       or (a.code = 'streak_5_days'  and (select len from streak) >= 5)
       or (a.code = 'first_playlist' and (select done from completed_playlist))
  ),
  inserted as (
    insert into public.user_achievements (student_id, achievement_id)
    select v_student, e.id from earned e
    on conflict (student_id, achievement_id) do nothing
    returning achievement_id
  )
  select a.code, a.title, a.description, a.icon
  from inserted i
  join public.achievements a on a.id = i.achievement_id
  order by a.sort_order;
end;
$$;

grant execute on function public.claim_achievements() to authenticated;


-- ============================================================================
-- >>> seed.sql
-- ============================================================================

-- seed.sql — sample content so the apps have something to show.
-- Runs automatically on `supabase db reset` (local dev only; not applied by
-- `supabase db push`). Safe to re-run: every insert is idempotent.
--
-- Seed admin (teacher) login:  teacher@example.com  /  password123

-- ── Seed admin auth user ──────────────────────────────────────────────────────
-- Inserts directly into auth.users so sample posts have a real author. The
-- on_auth_user_created trigger creates the matching profile (as 'student');
-- we then promote it to 'admin' below. auth.uid() is null while seeding, so the
-- role-guard trigger permits this.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data
)
values (
  '00000000-0000-0000-0000-000000000000',
  'a1111111-1111-1111-1111-111111111111',
  'authenticated', 'authenticated',
  'teacher@example.com',
  extensions.crypt('password123', extensions.gen_salt('bf')),
  now(), now(), now(),
  '{"provider":"email","providers":["email"]}',
  '{"display_name":"الأستاذ"}'
)
on conflict (id) do nothing;

insert into public.profiles (id, role, display_name)
values ('a1111111-1111-1111-1111-111111111111', 'admin', 'الأستاذ')
on conflict (id) do update
  set role = excluded.role, display_name = excluded.display_name;

-- ── Categories ────────────────────────────────────────────────────────────────
insert into public.categories (id, name, slug, icon, sort_order) values
  ('c1111111-1111-1111-1111-111111111111', 'الرياضيات', 'math',    'calculator', 1),
  ('c2222222-2222-2222-2222-222222222222', 'العلوم',    'science', 'flask',      2)
on conflict (id) do nothing;

-- ── Subcategories ─────────────────────────────────────────────────────────────
insert into public.subcategories (id, category_id, name, slug, sort_order) values
  ('b1111111-1111-1111-1111-111111111111', 'c1111111-1111-1111-1111-111111111111', 'الجبر',    'algebra',  1),
  ('b2222222-2222-2222-2222-222222222222', 'c1111111-1111-1111-1111-111111111111', 'الهندسة',  'geometry', 2),
  ('b3333333-3333-3333-3333-333333333333', 'c2222222-2222-2222-2222-222222222222', 'الفيزياء', 'physics',  1),
  ('b4444444-4444-4444-4444-444444444444', 'c2222222-2222-2222-2222-222222222222', 'الأحياء',  'biology',  2)
on conflict (id) do nothing;

-- ── Tags ──────────────────────────────────────────────────────────────────────
insert into public.tags (id, name, slug) values
  ('f1111111-1111-1111-1111-111111111111', 'مهم',    'important'),
  ('f2222222-2222-2222-2222-222222222222', 'مراجعة', 'revision')
on conflict (id) do nothing;

-- ── Posts (all published) ─────────────────────────────────────────────────────
insert into public.posts (id, title, body, subcategory_id, author_id, published) values
  ('d1111111-1111-1111-1111-111111111111',
   'مقدمة في الجبر',
   'الجبر فرع من فروع الرياضيات يستخدم الرموز لتمثيل الأعداد والعلاقات بينها.',
   'b1111111-1111-1111-1111-111111111111',
   'a1111111-1111-1111-1111-111111111111', true),
  ('d2222222-2222-2222-2222-222222222222',
   'نظرية فيثاغورس',
   'في المثلث القائم الزاوية، مربع طول الوتر يساوي مجموع مربعي طولَي الضلعين الآخرين.',
   'b2222222-2222-2222-2222-222222222222',
   'a1111111-1111-1111-1111-111111111111', true),
  ('d3333333-3333-3333-3333-333333333333',
   'قوانين نيوتن للحركة',
   'تصف قوانين نيوتن الثلاثة العلاقة بين حركة الجسم والقوى المؤثرة عليه.',
   'b3333333-3333-3333-3333-333333333333',
   'a1111111-1111-1111-1111-111111111111', true)
on conflict (id) do nothing;

-- ── Post <-> Tag links ────────────────────────────────────────────────────────
insert into public.post_tags (post_id, tag_id) values
  ('d1111111-1111-1111-1111-111111111111', 'f1111111-1111-1111-1111-111111111111'),
  ('d2222222-2222-2222-2222-222222222222', 'f1111111-1111-1111-1111-111111111111'),
  ('d2222222-2222-2222-2222-222222222222', 'f2222222-2222-2222-2222-222222222222'),
  ('d3333333-3333-3333-3333-333333333333', 'f2222222-2222-2222-2222-222222222222')
on conflict do nothing;

-- ── Sample media (external URLs) ──────────────────────────────────────────────
insert into public.media (id, post_id, type, external_url, display_name, sort_order) values
  ('0a111111-1111-1111-1111-111111111111', 'd1111111-1111-1111-1111-111111111111', 'video',
   'https://www.youtube.com/watch?v=NybHckSEQBI', 'شرح مرئي: مقدمة في الجبر', 1),
  ('0a222222-2222-2222-2222-222222222222', 'd2222222-2222-2222-2222-222222222222', 'pdf',
   'https://example.com/pythagoras.pdf', 'ملف PDF: نظرية فيثاغورس', 1)
on conflict (id) do nothing;

-- ── Playlist + ordered items ──────────────────────────────────────────────────
insert into public.playlists (id, title, description, published) values
  ('e1111111-1111-1111-1111-111111111111', 'أساسيات الرياضيات',
   'سلسلة مرتبة تغطي المفاهيم الأساسية في الجبر والهندسة.', true)
on conflict (id) do nothing;

insert into public.playlist_items (id, playlist_id, post_id, position) values
  ('0b111111-1111-1111-1111-111111111111',
   'e1111111-1111-1111-1111-111111111111', 'd1111111-1111-1111-1111-111111111111', 1),
  ('0b222222-2222-2222-2222-222222222222',
   'e1111111-1111-1111-1111-111111111111', 'd2222222-2222-2222-2222-222222222222', 2)
on conflict (id) do nothing;

-- ── Achievement definitions ───────────────────────────────────────────────────
insert into public.achievements (id, code, title, description, icon, sort_order) values
  ('fa111111-1111-1111-1111-111111111111', 'first_view',     'الخطوة الأولى', 'شاهدت أول درس لك.',      'star',   1),
  ('fa222222-2222-2222-2222-222222222222', 'five_views',     'متعلم نشِط',    'شاهدت خمسة دروس.',       'fire',   2),
  ('fa333333-3333-3333-3333-333333333333', 'first_playlist', 'رحلة منظَّمة',  'أكملت أول قائمة تشغيل.', 'trophy', 3)
on conflict (id) do nothing;

