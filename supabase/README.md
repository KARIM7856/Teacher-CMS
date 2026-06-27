# /supabase — Backend (database + config)

The shared **Supabase** backend used by both the mobile app (`/app`) and the
web admin portal (`/admin`).

## Purpose

- **Postgres** — application data (posts, categories, tags, playlists,
  view tracking, achievements).
- **Auth** — student and teacher login.
- **Storage** — uploaded files (video, PDFs, attachments).

## Language & content

Content is authored in **Arabic**. Postgres stores UTF-8 natively, so no
special column types are needed. For reliable Arabic search the schema ships a
`normalize_arabic()` function (folds alef/hamza/yaa/taa variants, strips
tashkīl) backing a **generated `search_text` column** on `posts` with a GIN
trigram index. See `/CLAUDE.md` → *Language & direction*.

## Schema overview

Twelve tables in the `public` schema:

| Table | Purpose | Key columns / relationships |
| ----- | ------- | --------------------------- |
| `profiles` | Extends `auth.users` | `id`→`auth.users`, `role` (`student`\|`admin`), `display_name`, `avatar_url` |
| `categories` | Main categories | `name`, `slug` (unique), `icon`, `sort_order` |
| `subcategories` | Belong to a category | `category_id`→`categories`, unique `(category_id, slug)` |
| `tags` | Freeform labels | `name`, `slug` (unique) |
| `posts` | Main content unit | `title`, `body` (markdown), `subcategory_id` (required), `author_id`→`profiles`, `published`, generated `search_text` |
| `post_tags` | Posts ⇄ tags (M2M) | PK `(post_id, tag_id)` |
| `media` | Files on a post | `post_id`→`posts`, `type` (`video`\|`pdf`\|`other`), `storage_path` **or** `external_url`, `sort_order` |
| `playlists` | Ordered collections | `title`, `description`, `cover_image`, `published` |
| `playlist_items` | Posts within a playlist | `playlist_id`, `post_id`, `position` (deferrable-unique per playlist) |
| `view_history` | "Continue where you left off" | PK `(student_id, post_id)`, `progress_seconds`, `last_viewed_at` |
| `achievements` | Achievement definitions | `code` (unique), `title`, `description`, `icon` |
| `user_achievements` | Unlocked achievements | PK `(student_id, achievement_id)`, `unlocked_at` |
| `student_activity` | Daily activity log (for streaks) | PK `(student_id, activity_date)` |

Conventions: UUID primary keys (`gen_random_uuid()`), `created_at` / `updated_at`
on mutable tables (a `set_updated_at()` trigger keeps `updated_at` current),
foreign keys with deliberate `on delete` behavior, and indexes on every lookup /
join column.

## Row Level Security

RLS is enabled on all tables. The model:

- **Read (anon + authenticated):** published content only — `posts`,
  `media`, `post_tags`, `playlists`, `playlist_items` are visible when the
  owning post/playlist is `published`. Lookup tables (`categories`,
  `subcategories`, `tags`, `achievements`) are world-readable.
- **Admins** (`profiles.role = 'admin'`) can do everything. The check is
  centralized in a `SECURITY DEFINER` helper `public.is_admin()` (avoids RLS
  recursion).
- **Students** can read/write **only their own** `view_history` and
  `user_achievements` rows (`student_id = auth.uid()`).
- **Profiles:** you can read your own row and any admin (teacher) row, and
  update your own — but a trigger (`enforce_profile_role`) blocks non-admins
  from changing their `role`.

## Storage buckets

| Bucket | Public? | Read | Write |
| ------ | ------- | ---- | ----- |
| `media` | No | Object is readable only when it is linked (via `media.storage_path`) to a **published** post — or the caller is an admin | Admins only |
| `public-assets` | Yes | World-readable (icons, playlist covers, avatars) | Admins only |

Store a post attachment's bucket path in `media.storage_path`; that linkage is
what gates public read access to private media.

## Migrations

Applied in filename order:

1. `20250601000000_init_extensions_and_helpers.sql` — extensions
   (`pgcrypto`, `pg_trgm`, `unaccent`), enum types, `normalize_arabic()`,
   `set_updated_at()`.
2. `20250601000100_core_schema.sql` — all tables, FKs, indexes, triggers,
   `is_admin()`, the new-user / role-guard triggers, role grants.
3. `20250601000200_rls_policies.sql` — RLS enablement + policies.
4. `20250601000300_storage.sql` — storage buckets + object policies.
5. `20250601000400_achievements_engine.sql` — `student_activity` log, the
   starter achievement set, and `claim_achievements()` — a `SECURITY DEFINER`
   RPC the app calls to evaluate the rules (first view, 5 / 25 views, 5-day
   streak, first playlist completed), grant any newly earned, and return them
   so the client can celebrate.

`seed.sql` (sample data) runs separately — see below.

## Running locally

Requires the [Supabase CLI](https://supabase.com/docs/guides/cli) and Docker.
From the **repo root**:

```bash
supabase init        # first time only — generates config (keep the [db.seed] block)
supabase start       # boots local Postgres, Auth, Storage, Studio
supabase db reset    # applies all migrations in order, then runs seed.sql
```

`supabase db reset` is the everyday command while iterating on the schema. To
push migrations to a linked hosted project (seed is **not** applied):

```bash
supabase link --project-ref <your-project-ref>
supabase db push
```

No CLI? Apply the SQL directly with `psql` in filename order, then the seed:

```bash
for f in supabase/migrations/*.sql; do psql "$DATABASE_URL" -f "$f"; done
psql "$DATABASE_URL" -f supabase/seed.sql   # local/dev only
```

> The migrations were validated end-to-end against Postgres 16 (all migrations
> apply, seed loads, and the RLS/trigger/constraint behavior was asserted).

## Seed data

`seed.sql` is idempotent and adds: 1 admin (teacher) user, 2 categories, 4
subcategories, 2 tags, 3 published posts (with tags + sample media), 1 published
playlist of 2 posts, and 3 achievement definitions — all in Arabic.

It also creates a dev login (local only):

```
email:    teacher@example.com
password: password123
```

> The seed inserts directly into `auth.users` for local dev. If your local auth
> schema rejects the insert, create the user via Studio / sign-up instead and
> then run the role-promotion `UPDATE` from the top of `seed.sql`.

## Status

Schema, RLS, storage policies, and seed data are in place (Phase 1); the
achievement-detection engine (`student_activity` + `claim_achievements()`) was
added in Phase 6. Next: initialize/link a hosted Supabase project and refine
search/collation as real content lands.
