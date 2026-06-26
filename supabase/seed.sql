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
