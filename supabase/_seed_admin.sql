-- ============================================================================
-- Seed / promote a single ADMIN (teacher) account.
--   email:    mohamedhassan9082@gmail.com
--   password: password123
--
-- Run ONCE on the hosted project:
--   Supabase Dashboard -> SQL Editor -> New query -> paste -> Run.
--
-- Idempotent: safe to re-run. If the user already exists, it just resets the
-- password, confirms the email, and (re)promotes the profile to 'admin'.
-- Depends on: pgcrypto in the "extensions" schema + the on_auth_user_created
-- trigger (both created by the core migrations / _full_setup_hosted.sql).
-- ============================================================================

do $$
declare
  v_email    text := 'mohamedhassan9082@gmail.com';
  v_password text := 'password123';
  v_name     text := 'محمد حسن';
  v_user_id  uuid;
begin
  select id into v_user_id from auth.users where email = v_email;

  if v_user_id is null then
    v_user_id := gen_random_uuid();

    -- Create the auth user. Inserting here fires on_auth_user_created, which
    -- creates a matching public.profiles row (as 'student'); we promote it below.
    -- NOTE: the token columns MUST be '' not NULL. GoTrue scans them into Go
    -- strings; a NULL makes every login 500 with "Database error querying schema".
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      raw_app_meta_data, raw_user_meta_data,
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
      '', '', '',
      '', '',
      '', '', ''
    );

    -- Email identity — required by GoTrue for email/password sign-in.
    insert into auth.identities (
      provider_id, user_id, identity_data, provider,
      last_sign_in_at, created_at, updated_at
    ) values (
      v_email, v_user_id,
      jsonb_build_object('sub', v_user_id::text, 'email', v_email, 'email_verified', true),
      'email', now(), now(), now()
    );
  else
    -- Already exists: (re)set the password and make sure the email is confirmed.
    update auth.users
      set encrypted_password = extensions.crypt(v_password, extensions.gen_salt('bf')),
          email_confirmed_at = coalesce(email_confirmed_at, now()),
          updated_at         = now()
      where id = v_user_id;
  end if;

  -- Promote to admin. auth.uid() is null in the SQL editor, so the
  -- profiles_guard_role trigger permits this role change.
  insert into public.profiles (id, role, display_name)
  values (v_user_id, 'admin', v_name)
  on conflict (id) do update
    set role = 'admin', display_name = excluded.display_name;

  raise notice 'Admin ready: % (%).', v_email, v_user_id;
end $$;

-- Verify:
select u.email, p.role, p.display_name
from auth.users u
join public.profiles p on p.id = u.id
where u.email = 'mohamedhassan9082@gmail.com';
