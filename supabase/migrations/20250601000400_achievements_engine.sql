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
