-- 20250601000800_guest_content.sql
-- Guest access: a single shared "guest" student can browse one public category.
--
-- The app's sign-in screen has a "الدخول كضيف" (log in as guest) button that
-- signs in with a shared guest account. Content visibility is entirely
-- group-based (see 20250601000600_content_groups.sql): a student sees the union
-- of the categories/subcategories granted to their groups. So the "guest" is
-- just an ordinary student whose one group grants a single "guest" category.
--
-- This migration provisions the data side of that: the guest category, the
-- guest group, and the grant linking them. It is idempotent (fixed UUIDs +
-- `on conflict do nothing`), matching the style of seed.sql.
--
-- TWO MANUAL FOLLOW-UPS (can't be done safely in SQL):
--   (a) In the admin portal, author a subcategory + at least one PUBLISHED post
--       under the "guest" category. The category grant already covers any
--       subcategories added later, so no further grant is needed.
--   (b) In the الطلاب (Students) page, create the guest student account
--       (username = the app's GUEST_USERNAME dart-define, password = its
--       GUEST_PASSWORD) and assign it to the "الضيوف" group created below.
--       Auth users must be created via the Admin API — a raw auth.users insert
--       leaves NULL token columns and breaks login (the known login-500).
-- Depends on: 20250601000100 (categories) and 20250601000600 (groups + grants).

-- The public "guest" category. Renameable from the admin portal; the slug is
-- what matters as a stable handle.
insert into public.categories (id, name, slug, sort_order) values
  ('cccccccc-0000-4000-8000-000000000001', 'محتوى الضيف', 'guest', 1000)
on conflict (slug) do nothing;

-- The group every guest belongs to. sort_order 1000 keeps it out of the way in
-- the admin group list.
insert into public.groups (id, name, description, sort_order) values
  ('a0000000-0000-4000-8000-000000000001', 'الضيوف',
   'المجموعة الافتراضية لحساب الضيف — تمنح الوصول إلى فئة «محتوى الضيف».', 1000)
on conflict (id) do nothing;

-- Grant the whole guest category (incl. future subcategories) to the guest
-- group. Looked up by slug so it still works if a "guest" category already
-- existed under a different id (the insert above was then a no-op).
insert into public.group_categories (group_id, category_id)
select 'a0000000-0000-4000-8000-000000000001', c.id
from public.categories c
where c.slug = 'guest'
on conflict do nothing;
