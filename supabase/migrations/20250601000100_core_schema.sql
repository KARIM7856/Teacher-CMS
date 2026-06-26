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
