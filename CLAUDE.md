# CLAUDE.md

Guidance for working in this repository. Read this first.

## Project goal

A **free-access educational content platform**. A single teacher publishes
learning content through a web admin portal; students view that content for
free through a mobile app. No paywalls, no per-student accounts to purchase —
the goal is open access to the teacher's material.

- **Students** use a mobile app to browse and consume content.
- **The teacher** uses a separate web admin portal to create and publish it.
- A shared Supabase backend stores the data, files, and auth.

## Stack

| Layer            | Technology                                              |
| ---------------- | ------------------------------------------------------- |
| Mobile app       | Flutter (Dart), targeting Android + iOS                 |
| Web admin portal | Node-based web app (framework chosen in a later phase)  |
| Backend          | Supabase — Postgres (data), Auth (login), Storage (files) |

## Folder layout

This is a monorepo. Each top-level folder is an independent project that talks
to the same Supabase backend.

```
/app        Flutter mobile app — the student-facing client
/admin      Web admin portal — the teacher-facing publishing tool
/supabase   Database migrations and Supabase project config
CLAUDE.md   This file
.gitignore  Ignores for Flutter + Node + Supabase
```

Each folder has its own `README.md` describing its purpose in more detail.

## Planned features

Built incrementally over several phases:

- **Posts** — a post can embed video, PDFs, and other file attachments.
- **Organization** — content sorted by main category → subcategory, plus
  freeform tags for cross-cutting grouping.
- **Continue where you left off** — track each student's latest-viewed content
  so they can resume quickly.
- **Playlists** — ordered collections of posts.
- **Celebrations** — animations when a student reaches an achievement.

## Coding conventions

- **Clear names.** Prefer descriptive, unambiguous names over short or clever
  ones. Code should read like prose.
- **Small functions.** Keep functions short and single-purpose. If a function
  does several things, split it.
- **Comments only where non-obvious.** Don't restate what the code already
  says. Comment the *why* — intent, trade-offs, and surprises — not the *what*.
- Keep each project's idioms consistent: follow Dart/Flutter conventions in
  `/app` and the chosen web framework's conventions in `/admin`.

## Current state

A running log of where the project stands. **Update this section at the end of
each phase.**

### Phase 0 — Repository scaffolding (current)

- Monorepo folder layout created: `/app`, `/admin`, `/supabase`, each with a
  README describing its purpose.
- Root `CLAUDE.md` documenting goal, stack, layout, and conventions.
- Git initialized with a `.gitignore` covering Flutter, Node, and Supabase.
- **No feature code, no project scaffolding, and no database schema yet.**

### Next up

- Scaffold the three projects (Flutter app, web admin, Supabase init).
- Decide on the web admin framework.
- Design the initial database schema (posts, categories, tags).
