-- Fix for GoTrue "Database error querying schema" on login/signup.
-- The on_auth_user_created trigger on auth.users calls public.handle_new_user(),
-- but the supabase_auth_admin role (which GoTrue uses) wasn't granted access to
-- the public schema / that function. Run once in the SQL Editor.
grant usage on schema public to supabase_auth_admin;
grant execute on function public.handle_new_user() to supabase_auth_admin;
