-- ============================================================================
-- FULL RESET → single super admin.
--
-- ⚠️  DESTRUCTIVE AND IRREVERSIBLE. This:
--       1. deletes ALL auth users
--       2. drops the entire `public` schema (all tables, functions, types, data)
--       3. rebuilds the schema fresh (the 5 migrations, NO sample seed content)
--       4. grants the auth role what it needs (fixes the login/signup 500)
--       5. creates exactly ONE account — the super admin below
--
-- NOTE: uploaded files in Storage are NOT cleared here — Supabase blocks direct
-- SQL deletes on storage.objects (storage.protect_delete). If you have files to
-- remove, delete them from Dashboard → Storage. A fresh project has none.
--
-- Run ONCE, on its own, in the SQL Editor. Log in afterwards with:
--       mohamedhassan9082@gmail.com  /  password123
-- ============================================================================

-- ── 0) WIPE ──────────────────────────────────────────────────────────────────
-- Remove all auth users (cascades to identities / sessions / refresh_tokens).
delete from auth.users;

-- Storage policies live in the `storage` schema, so a public-schema drop won't
-- remove the ones that don't reference public objects. Drop them all so the
-- rebuild's CREATE POLICY statements can't collide.
drop policy if exists "media_read_published_or_admin" on storage.objects;
drop policy if exists "media_admin_insert"            on storage.objects;
drop policy if exists "media_admin_update"            on storage.objects;
drop policy if exists "media_admin_delete"            on storage.objects;
drop policy if exists "public_assets_read"            on storage.objects;
drop policy if exists "public_assets_admin_insert"    on storage.objects;
drop policy if exists "public_assets_admin_update"    on storage.objects;
drop policy if exists "public_assets_admin_delete"    on storage.objects;

-- Nuke and recreate the app schema.
drop schema if exists public cascade;
create schema public;
grant usage  on schema public to postgres, anon, authenticated, service_role, supabase_auth_admin;
grant create on schema public to postgres, service_role;
grant all    on schema public to postgres, service_role;

-- ============================================================================
-- 1) EXTENSIONS, TYPES, HELPERS  (migration 20250601000000)
-- ============================================================================
create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_trgm  with schema extensions;
create extension if not exists unaccent with schema extensions;

do $$ begin
  create type public.user_role as enum ('student', 'admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.media_type as enum ('video', 'pdf', 'other');
exception when duplicate_object then null; end $$;

create or replace function public.normalize_arabic(input text)
returns text language sql immutable as $$
  select case
    when input is null then null
    else regexp_replace(
           translate(lower(input), 'أإآٱىئؤةـ', 'ااااييوه'),
           E'[ً-ٰٟـ]', '', 'g'
         )
  end;
$$;

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ============================================================================
-- 2) CORE SCHEMA  (migration 20250601000100)
-- ============================================================================
create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  role         public.user_role not null default 'student',
  display_name text,
  avatar_url   text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index idx_profiles_role on public.profiles (role);

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles where id = auth.uid() and role = 'admin'
  );
$$;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
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

create or replace function public.enforce_profile_role()
returns trigger language plpgsql security definer set search_path = public as $$
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
  before update on public.categories for each row execute function public.set_updated_at();

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
create index idx_subcategories_sort     on public.subcategories (sort_order);
create trigger subcategories_set_updated_at
  before update on public.subcategories for each row execute function public.set_updated_at();

create table public.tags (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  slug       text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger tags_set_updated_at
  before update on public.tags for each row execute function public.set_updated_at();

create table public.posts (
  id             uuid primary key default gen_random_uuid(),
  title          text not null,
  body           text,
  subcategory_id uuid not null references public.subcategories (id) on delete restrict,
  author_id      uuid references public.profiles (id) on delete set null,
  published      boolean not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  search_text    text generated always as (
    public.normalize_arabic(coalesce(title, '') || ' ' || coalesce(body, ''))
  ) stored
);
create index idx_posts_subcategory       on public.posts (subcategory_id);
create index idx_posts_author            on public.posts (author_id);
create index idx_posts_published_created on public.posts (published, created_at desc);
create index idx_posts_search            on public.posts using gin (search_text extensions.gin_trgm_ops);
create trigger posts_set_updated_at
  before update on public.posts for each row execute function public.set_updated_at();

create table public.post_tags (
  post_id uuid not null references public.posts (id) on delete cascade,
  tag_id  uuid not null references public.tags (id) on delete cascade,
  primary key (post_id, tag_id)
);
create index idx_post_tags_tag on public.post_tags (tag_id);

create table public.media (
  id           uuid primary key default gen_random_uuid(),
  post_id      uuid not null references public.posts (id) on delete cascade,
  type         public.media_type not null,
  storage_path text,
  external_url text,
  display_name text,
  sort_order   integer not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint media_has_source check (storage_path is not null or external_url is not null)
);
create index idx_media_post      on public.media (post_id);
create index idx_media_post_sort on public.media (post_id, sort_order);
create trigger media_set_updated_at
  before update on public.media for each row execute function public.set_updated_at();

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
  before update on public.playlists for each row execute function public.set_updated_at();

create table public.playlist_items (
  id          uuid primary key default gen_random_uuid(),
  playlist_id uuid not null references public.playlists (id) on delete cascade,
  post_id     uuid not null references public.posts (id) on delete cascade,
  position    integer not null,
  created_at  timestamptz not null default now(),
  unique (playlist_id, post_id),
  constraint playlist_items_position_unique unique (playlist_id, position)
    deferrable initially deferred
);
create index idx_playlist_items_playlist on public.playlist_items (playlist_id, position);
create index idx_playlist_items_post     on public.playlist_items (post_id);

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

create or replace function public.touch_last_viewed()
returns trigger language plpgsql as $$
begin
  new.last_viewed_at = now();
  return new;
end;
$$;
create trigger view_history_touch
  before update on public.view_history for each row execute function public.touch_last_viewed();

create table public.achievements (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,
  title       text not null,
  description text,
  icon        text,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create trigger achievements_set_updated_at
  before update on public.achievements for each row execute function public.set_updated_at();

create table public.user_achievements (
  student_id     uuid not null references public.profiles (id) on delete cascade,
  achievement_id uuid not null references public.achievements (id) on delete cascade,
  unlocked_at    timestamptz not null default now(),
  primary key (student_id, achievement_id)
);
create index idx_user_achievements_achievement on public.user_achievements (achievement_id);

grant usage on schema public to anon, authenticated;
grant select on all tables in schema public to anon;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant all on all tables in schema public to service_role;
grant execute on function public.is_admin()             to anon, authenticated;
grant execute on function public.normalize_arabic(text) to anon, authenticated;

-- ============================================================================
-- 3) ROW LEVEL SECURITY  (migration 20250601000200)
-- ============================================================================
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

create policy "profiles_select" on public.profiles
  for select to authenticated
  using (id = auth.uid() or role = 'admin' or public.is_admin());
create policy "profiles_insert_self" on public.profiles
  for insert to authenticated with check (id = auth.uid());
create policy "profiles_update_self_or_admin" on public.profiles
  for update to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());
create policy "profiles_delete_admin" on public.profiles
  for delete to authenticated using (public.is_admin());

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

create policy "posts_read_published_or_admin" on public.posts
  for select to anon, authenticated using (published or public.is_admin());
create policy "posts_admin_write" on public.posts
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "post_tags_read" on public.post_tags
  for select to anon, authenticated
  using (exists (select 1 from public.posts p where p.id = post_id and (p.published or public.is_admin())));
create policy "post_tags_admin_write" on public.post_tags
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "media_read" on public.media
  for select to anon, authenticated
  using (exists (select 1 from public.posts p where p.id = post_id and (p.published or public.is_admin())));
create policy "media_admin_write" on public.media
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "playlists_read_published_or_admin" on public.playlists
  for select to anon, authenticated using (published or public.is_admin());
create policy "playlists_admin_write" on public.playlists
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "playlist_items_read" on public.playlist_items
  for select to anon, authenticated
  using (exists (select 1 from public.playlists pl where pl.id = playlist_id and (pl.published or public.is_admin())));
create policy "playlist_items_admin_write" on public.playlist_items
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "view_history_select_own_or_admin" on public.view_history
  for select to authenticated using (student_id = auth.uid() or public.is_admin());
create policy "view_history_insert_own" on public.view_history
  for insert to authenticated with check (student_id = auth.uid());
create policy "view_history_update_own" on public.view_history
  for update to authenticated using (student_id = auth.uid()) with check (student_id = auth.uid());
create policy "view_history_delete_own_or_admin" on public.view_history
  for delete to authenticated using (student_id = auth.uid() or public.is_admin());
create policy "view_history_admin_manage" on public.view_history
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "user_achievements_select_own_or_admin" on public.user_achievements
  for select to authenticated using (student_id = auth.uid() or public.is_admin());
create policy "user_achievements_insert_own" on public.user_achievements
  for insert to authenticated with check (student_id = auth.uid());
create policy "user_achievements_delete_own_or_admin" on public.user_achievements
  for delete to authenticated using (student_id = auth.uid() or public.is_admin());
create policy "user_achievements_admin_manage" on public.user_achievements
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ============================================================================
-- 4) STORAGE  (migration 20250601000300)
-- ============================================================================
insert into storage.buckets (id, name, public)
values ('media', 'media', false) on conflict (id) do nothing;
insert into storage.buckets (id, name, public)
values ('public-assets', 'public-assets', true) on conflict (id) do nothing;

create policy "media_read_published_or_admin" on storage.objects
  for select to anon, authenticated
  using (
    bucket_id = 'media'
    and (
      public.is_admin()
      or exists (
        select 1 from public.media m
        join public.posts p on p.id = m.post_id
        where m.storage_path = storage.objects.name and p.published
      )
    )
  );
create policy "media_admin_insert" on storage.objects
  for insert to authenticated with check (bucket_id = 'media' and public.is_admin());
create policy "media_admin_update" on storage.objects
  for update to authenticated using (bucket_id = 'media' and public.is_admin())
  with check (bucket_id = 'media' and public.is_admin());
create policy "media_admin_delete" on storage.objects
  for delete to authenticated using (bucket_id = 'media' and public.is_admin());

create policy "public_assets_read" on storage.objects
  for select to anon, authenticated using (bucket_id = 'public-assets');
create policy "public_assets_admin_insert" on storage.objects
  for insert to authenticated with check (bucket_id = 'public-assets' and public.is_admin());
create policy "public_assets_admin_update" on storage.objects
  for update to authenticated using (bucket_id = 'public-assets' and public.is_admin())
  with check (bucket_id = 'public-assets' and public.is_admin());
create policy "public_assets_admin_delete" on storage.objects
  for delete to authenticated using (bucket_id = 'public-assets' and public.is_admin());

-- ============================================================================
-- 5) ACHIEVEMENTS ENGINE  (migration 20250601000400)
-- ============================================================================
create table if not exists public.student_activity (
  student_id    uuid not null references public.profiles (id) on delete cascade,
  activity_date date not null default current_date,
  primary key (student_id, activity_date)
);
create index if not exists idx_student_activity_student
  on public.student_activity (student_id, activity_date desc);

alter table public.student_activity enable row level security;
create policy "student_activity_select_own_or_admin" on public.student_activity
  for select to authenticated using (student_id = auth.uid() or public.is_admin());
create policy "student_activity_insert_own" on public.student_activity
  for insert to authenticated with check (student_id = auth.uid());
create policy "student_activity_admin_manage" on public.student_activity
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
grant select, insert on public.student_activity to authenticated;

-- Achievement DEFINITIONS are app config (not sample content), so they stay.
insert into public.achievements (id, code, title, description, icon, sort_order) values
  ('fa111111-1111-1111-1111-111111111111', 'first_view',     'الخطوة الأولى',     'شاهدت أول درس لك.',      'star',   1),
  ('fa222222-2222-2222-2222-222222222222', 'five_views',     'متعلم نشِط',        'شاهدت خمسة دروس.',       'fire',   2),
  ('fa444444-4444-4444-4444-444444444444', 'views_25',       'متعلّم مثابر',      'شاهدت 25 درسًا.',        'school', 3),
  ('fa555555-5555-5555-5555-555555555555', 'streak_5_days',  'خمسة أيام متتالية', 'تعلّمت 5 أيام متتالية.', 'fire',   4),
  ('fa333333-3333-3333-3333-333333333333', 'first_playlist', 'رحلة منظَّمة',       'أكملت أول قائمة تشغيل.', 'trophy', 5)
on conflict (code) do nothing;

create or replace function public.claim_achievements()
returns table (code text, title text, description text, icon text)
language plpgsql security definer set search_path = public as $$
declare
  v_student uuid := auth.uid();
begin
  if v_student is null then
    return;
  end if;

  insert into public.student_activity (student_id, activity_date)
  values (v_student, current_date)
  on conflict do nothing;

  return query
  with viewed as (
    select count(distinct vh.post_id) as n
    from public.view_history vh where vh.student_id = v_student
  ),
  days as (
    select distinct activity_date as d
    from public.student_activity where student_id = v_student
  ),
  islands as (
    select d, d - (row_number() over (order by d))::int as grp from days
  ),
  streak as (
    select count(*) as len from islands
    where grp = (select grp from islands where d = current_date)
  ),
  completed_playlist as (
    select exists (
      select 1 from public.playlists pl
      where pl.published
        and exists (select 1 from public.playlist_items pi where pi.playlist_id = pl.id)
        and not exists (
          select 1 from public.playlist_items pi
          where pi.playlist_id = pl.id
            and pi.post_id not in (
              select vh.post_id from public.view_history vh where vh.student_id = v_student
            )
        )
    ) as done
  ),
  earned as (
    select a.id from public.achievements a
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
  from inserted i join public.achievements a on a.id = i.achievement_id
  order by a.sort_order;
end;
$$;
grant execute on function public.claim_achievements() to authenticated;

-- ============================================================================
-- 6) AUTH-ADMIN GRANTS  (the fix for the signup/login 500)
-- ============================================================================
grant usage on schema public to supabase_auth_admin;
grant execute on function public.handle_new_user() to supabase_auth_admin;
alter function public.handle_new_user() owner to postgres;

-- ============================================================================
-- 7) CREATE THE ONE SUPER ADMIN
-- ============================================================================
do $$
declare
  v_email    text := 'mohamedhassan9082@gmail.com';
  v_password text := 'password123';
  v_name     text := 'محمد حسن';
  v_user_id  uuid := gen_random_uuid();
begin
  -- Inserting fires on_auth_user_created → creates the profile (as 'student').
  -- NOTE: the token columns MUST be '' not NULL. GoTrue scans them into Go
  -- strings; a NULL makes every login 500 with "Database error querying schema".
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    is_sso_user, is_anonymous,
    confirmation_token, recovery_token, email_change,
    email_change_token_new, email_change_token_current,
    phone_change, phone_change_token, reauthentication_token
  ) values (
    '00000000-0000-0000-0000-000000000000',
    v_user_id, 'authenticated', 'authenticated',
    v_email,
    extensions.crypt(v_password, extensions.gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}',
    jsonb_build_object('display_name', v_name),
    false, false,
    '', '', '',
    '', '',
    '', '', ''
  );

  -- Email identity — required by GoTrue for password sign-in.
  insert into auth.identities (
    provider_id, user_id, identity_data, provider,
    last_sign_in_at, created_at, updated_at
  ) values (
    v_user_id::text, v_user_id,
    jsonb_build_object('sub', v_user_id::text, 'email', v_email, 'email_verified', true),
    'email', now(), now(), now()
  );

  -- Promote to admin (auth.uid() is null here, so the role guard allows it).
  insert into public.profiles (id, role, display_name)
  values (v_user_id, 'admin', v_name)
  on conflict (id) do update set role = 'admin', display_name = excluded.display_name;
end $$;

-- ── VERIFY ───────────────────────────────────────────────────────────────────
select u.email, p.role, p.display_name,
       u.email_confirmed_at is not null as confirmed,
       i.provider
from auth.users u
join public.profiles p on p.id = u.id
left join auth.identities i on i.user_id = u.id;
