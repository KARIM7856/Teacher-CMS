-- ============================================================================
-- Repair: 500 on POST /auth/v1/token?grant_type=password
--         (GoTrue "Database error querying schema").
--
-- Run this ON ITS OWN in the SQL Editor. Every statement below is valid for the
-- hosted `postgres` role, so the whole thing COMMITS (nothing rolls back).
--
-- Note: on hosted Supabase you CANNOT `set role supabase_auth_admin` from the
-- SQL editor (permission denied) — so we verify grants with has_*_privilege()
-- instead of impersonating the role.
-- ============================================================================

-- 1) GoTrue runs as supabase_auth_admin. Give it public-schema access + execute
--    on the signup trigger function, and make that SECURITY DEFINER function
--    owned by a superuser role.
grant usage on schema public to supabase_auth_admin;
grant execute on function public.handle_new_user() to supabase_auth_admin;
alter function public.handle_new_user() owner to postgres;

-- 2) Re-assert API-role grants (lost in the earlier rolled-back run) and reload
--    PostgREST's cache so /rest/v1/* stops 404-ing.
grant usage on schema public to anon, authenticated;
grant select on all tables in schema public to anon;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant all on all tables in schema public to service_role;
notify pgrst, 'reload schema';

-- ── VERIFY (all run fine as postgres) ────────────────────────────────────────

-- A) Did the grants stick? Expect: usage = true, execute = true, owner = postgres.
select
  has_schema_privilege('supabase_auth_admin', 'public', 'usage')                as auth_admin_usage,
  has_function_privilege('supabase_auth_admin', 'public.handle_new_user()', 'execute') as auth_admin_execute,
  (select pg_get_userbyid(proowner) from pg_proc where proname = 'handle_new_user') as fn_owner;

-- B) Inspect the accounts GoTrue is choking on. Watch for: email_confirmed_at
--    NULL, is_anonymous NULL (should be false), or a MISSING identity row.
select
  u.email,
  u.email_confirmed_at is not null as confirmed,
  u.is_sso_user,
  u.is_anonymous,
  i.provider,
  i.provider_id
from auth.users u
left join auth.identities i on i.user_id = u.id
order by u.email;
