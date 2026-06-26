# /supabase — Backend (database + config)

The shared **Supabase** backend used by both the mobile app (`/app`) and the
web admin portal (`/admin`).

## Purpose

- **Postgres** — application data (posts, categories, tags, playlists,
  view tracking, achievements).
- **Auth** — student and teacher login.
- **Storage** — uploaded files (video, PDFs, attachments).

## Contents

- `migrations/` — versioned SQL migrations that define the database schema.
- Supabase project config (e.g. `config.toml`) will live here once the project
  is initialized with the Supabase CLI.

## Status

Not initialized yet. Schema and config will be added in a later phase.
