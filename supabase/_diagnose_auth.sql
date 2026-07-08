-- Diagnostic for "Database error querying schema".
-- Runs a couple of statements AS the role GoTrue uses (supabase_auth_admin) to
-- surface the real underlying Postgres error. Paste the FULL output/error back.

-- A) Can the auth role read its own core table?
set role supabase_auth_admin;
select count(*) as auth_users_visible from auth.users;
reset role;

-- B) Do our objects actually exist (did the big script fully apply)?
select
  (select count(*) from pg_proc  where proname = 'handle_new_user')            as fn_handle_new_user,
  (select count(*) from pg_trigger where tgname = 'on_auth_user_created')       as trg_on_auth_user_created,
  (select count(*) from information_schema.tables
     where table_schema = 'public' and table_name = 'profiles')                 as tbl_profiles,
  (select count(*) from information_schema.tables
     where table_schema = 'public' and table_name = 'posts')                    as tbl_posts;
