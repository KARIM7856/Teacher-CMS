-- 20250601000500_view_history_seen.sql
-- Separate "seen" from "progress" on view_history.
--
-- Until now a row's mere existence meant "seen", which coupled the two: saving a
-- video resume position implicitly marked a post seen. This adds an explicit
-- `seen` flag so the two are independent:
--   * progress_seconds — video resume position, saved automatically as you watch
--   * seen             — the student's deliberate "I've seen this" (the app button)
--
-- A post can therefore have resume progress without being "seen", and marking it
-- seen no longer depends on having watched anything.
--
-- Depends on: 20250601000100 (view_history), 20250601000400 (claim_achievements).

-- Add the column and backfill only on first apply, so existing rows (which meant
-- "seen" under the old model) become seen = true while new rows default to false.
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'view_history'
      and column_name = 'seen'
  ) then
    alter table public.view_history add column seen boolean;
    update public.view_history set seen = true;
    alter table public.view_history alter column seen set default false;
    alter table public.view_history alter column seen set not null;
  end if;
end $$;

-- Speeds up the "how many seen" / playlist-completion checks below.
create index if not exists idx_view_history_seen
  on public.view_history (student_id) where seen;

-- Recount views and playlist completion from SEEN rows only (was: any row).
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
    where vh.student_id = v_student and vh.seen
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
              where vh.student_id = v_student and vh.seen
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
