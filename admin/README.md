# /admin — Web admin portal

The **teacher-facing** tool. A web app the teacher uses to create and publish
content for students.

## Stack

- **React + Vite + TypeScript**
- **Mantine v7** component library — RTL via `DirectionProvider` + `<html dir="rtl">`
- **@dnd-kit** — drag-and-drop reordering (categories, media, playlist items)
- **react-markdown** (+ remark-gfm) — markdown body editor preview
- **react-router** — routing
- **@supabase/supabase-js** — auth, data, storage against the `/supabase` backend

## Screens

- **Login** — email/password via Supabase Auth, **restricted to the `admin` role**
  (non-admins are signed out).
- **Dashboard** — counts of posts, playlists, categories.
- **Categories** — categories + subcategories: create, edit, **drag-reorder**, delete.
- **Tags** — create, edit, delete.
- **Posts** — list with search + filter by category/tag; editor with title,
  markdown body (edit/preview tabs), subcategory picker, tag multi-select,
  published toggle, and a **media uploader** (uploads to the Supabase Storage
  `media` bucket, mark each file video/pdf/other, drag-reorder).
- **Playlists** — create/edit, add posts in order via **drag-and-drop**, published toggle.

## Language & direction

**Arabic-first and RTL by default** (`<html lang="ar" dir="rtl">`, Mantine
`DirectionProvider`, Cairo font). All UI copy is Arabic. See `/CLAUDE.md` →
*Language & direction*.

## Getting started

```bash
cd admin
npm install
cp .env.example .env      # then fill in your Supabase URL + anon key
npm run dev               # http://localhost:5173
```

Other scripts: `npm run build` (typecheck + production build), `npm run preview`,
`npm run typecheck`.

### Configuration

`.env` (see `.env.example`):

```
VITE_SUPABASE_URL=https://your-project-ref.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-public-key
```

You also need an **admin** account: create a user in Supabase Auth and set their
`profiles.role = 'admin'` (the `/supabase` seed creates `teacher@example.com` /
`password123` for local dev).

## Layout

```
src/
  api/          data-access functions per entity (Supabase calls)
  auth/         AuthProvider (session + profile + admin gate)
  components/   AppLayout (RTL shell), RequireAdmin guard, SortableList
  pages/        one file per screen
  lib/          Supabase client
  types/        row types for the schema
```

## Status

Scaffolded with all six screens wired to Supabase (Phase 2). Typecheck and
production build pass.
