# CLAUDE.md

Guidance for working in this repository. Read this first.

## Project goal

A **free-access educational content platform**. A single teacher publishes
learning content through a web admin portal; students view that content for
free through a mobile app. No paywalls, no per-student accounts to purchase —
the goal is open access to the teacher's material.

The audience is **Arabic-speaking**, so the platform is **Arabic-first and
right-to-left (RTL)** throughout — see *Language & direction* below.

- **Students** use a mobile app to browse and consume content.
- **The teacher** uses a separate web admin portal to create and publish it.
- A shared Supabase backend stores the data, files, and auth.

## Language & direction — Arabic-first (core principle)

**Arabic is the primary language and the platform is right-to-left (RTL) by
default.** This is a foundational constraint, not an afterthought — design and
build every screen, layout, and data model RTL-first. Left-to-right is the
exception, handled only for embedded Latin text (URLs, code, some names).

Applies everywhere:

- **Default locale is `ar`; RTL is the default text direction.**
- **Never hardcode `left` / `right`.** Use direction-aware primitives so the UI
  mirrors automatically:
  - Flutter (`/app`): `EdgeInsetsDirectional`, `AlignmentDirectional`,
    `start` / `end`; set `MaterialApp(locale: Locale('ar'), ...)` and let
    widgets inherit `TextDirection.rtl`.
  - Web (`/admin`): `<html lang="ar" dir="rtl">` and CSS **logical properties**
    (`margin-inline-start`, `padding-inline-end`, `inset-inline`,
    `text-align: start`) — not `margin-left` / `right`.
- **Directional icons and motion must flip.** Back/forward arrows, chevrons,
  progress bars, playlist order, and "continue where you left off" all flow
  right-to-left.
- **Bundle an Arabic font** with strong legibility for long-form reading
  (e.g. Cairo, Tajawal, IBM Plex Sans Arabic, or a Naskh face). Don't depend on
  system fonts. *(Exact face: to confirm.)*
- **Mixed Arabic/Latin text** (an English term in an Arabic sentence, a URL, a
  filename) must use proper bidirectional isolation so it doesn't reorder.
- **Numerals:** pick one and apply consistently — Western (`0-9`) or
  Arabic-Indic (`٠-٩`). *(Default assumption: Western digits; to confirm.)*
- **Don't hardcode user-facing strings.** Route all copy through localization
  from day one. Arabic is first; externalized strings leave room to add another
  language later without rework.

Backend (`/supabase`) implications:

- Postgres stores Arabic (UTF-8) natively — no special column types needed.
- For **sorting and search** of Arabic, plan for ICU collation (e.g.
  `ar-x-icu`) and an Arabic text-search setup. Consider storing a **normalized**
  form (strip tashkīl/diacritics, unify alef/hamza/yaa variants) alongside the
  original for reliable search and matching.
- Category, subcategory, tag, and post text are authored in Arabic.

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
- **RTL & i18n first.** Build every layout direction-aware (logical /
  `start`-`end` properties, never literal `left` / `right`) and route all
  user-facing text through localization with Arabic as the default locale.
  See *Language & direction* above.
- Keep each project's idioms consistent: follow Dart/Flutter conventions in
  `/app` and the chosen web framework's conventions in `/admin`.

## Current state

A running log of where the project stands. **Update this section at the end of
each phase.**

### Phase 0 — Repository scaffolding

- Monorepo folder layout created: `/app`, `/admin`, `/supabase`, each with a
  README describing its purpose.
- Root `CLAUDE.md` documenting goal, stack, layout, and conventions.
- Established **Arabic-first / RTL** as a core design principle, documented in
  `CLAUDE.md` and each folder README.
- Git initialized with a `.gitignore` covering Flutter, Node, and Supabase.
- **No feature code, no project scaffolding, and no database schema yet.**

### Phase 1 — Backend & data model

- Supabase schema as SQL migrations in `/supabase/migrations`: `profiles`,
  `categories`, `subcategories`, `tags`, `posts`, `post_tags`, `media`,
  `playlists`, `playlist_items`, `view_history`, `achievements`,
  `user_achievements`.
- Foreign keys, lookup indexes, and `updated_at` triggers throughout.
- Row Level Security: public reads published content; students own their
  `view_history` / `user_achievements`; admins do everything.
- Storage buckets (`media`, `public-assets`) with published-gated / admin-write
  policies.
- Arabic-aware search via `normalize_arabic()` + a trigram-indexed generated
  column on `posts`.
- Idempotent `seed.sql` (Arabic sample content) plus a local-run guide in
  `/supabase/README.md`. Migrations validated end-to-end on Postgres 16.

### Phase 2 — Admin portal (web)

- `/admin` scaffolded: **React + Vite + TypeScript**, **Mantine v7** (RTL via
  `DirectionProvider`), **@dnd-kit** for reordering, **react-markdown** for the
  post body. Arabic-first / RTL throughout.
- Screens: admin-only login (Supabase Auth + role check), dashboard counts,
  categories/subcategories CRUD + drag-reorder, tags CRUD, posts list with
  search + category/tag filters, post editor (markdown body, subcategory
  picker, tag multi-select, published toggle, media uploader to Supabase
  Storage with type + drag-reorder), playlists with drag-ordered items.
- Data-access layer in `/admin/src/api`, Supabase client + auth context, and
  `.env.example` for the keys. Typecheck + production build pass.

### Phase 3 — Student app scaffold (Flutter)

- `/app` scaffolded: Flutter (Android + iOS), Arabic-first / RTL (default
  locale `ar` + Material localizations), bundled **Cairo** font, warm
  Material 3 theme centralized in `lib/src/core/theme`.
- Feature-first architecture under `lib/src` separating data (repositories),
  models, application (**Riverpod** providers), and presentation. Riverpod
  chosen for compile-safe DI, testability, and first-class async/stream
  handling (auth state + future data).
- Supabase client wrapper + providers; credentials via `--dart-define`
  (`dart_define.example.json`); session persistence handled by supabase_flutter.
- Auth flow (welcome → email/password sign-up & sign-in; returning users land
  straight in the app) and an app shell with bottom-nav tabs (Home, Browse,
  Playlists, Profile) as placeholders. `flutter analyze` clean; widget smoke
  test passes. Content browsing intentionally not built yet.

### Phase 4 — Content browsing & post viewer (current)

- `/app` now browses real content from Supabase, **published-only** throughout
  (queries never request drafts; RLS backstops it).
- **Shared content layer** (`features/content`): `ContentRepository` + Riverpod
  providers for categories, subcategories, posts (with optional tag filter via
  an inner join), recent posts, tags, and a combined post-detail fetch
  (post + media + tags).
- **Home tab:** a "تابِع ما بدأته" (continue) row wired to `view_history`
  (empty until tracking lands) above the most recent published lessons.
- **Browse tab:** categories → subcategories → posts, with a tag filter bar.
- **Post viewer:** markdown body (`flutter_markdown`) plus media —
  `video_player`/`chewie` for stored & direct-file video, an embedded YouTube
  player (`youtube_player_flutter`) for YouTube links, Vimeo/unknown open
  externally (`url_launcher`); PDFs render inline (`pdfx`); other files
  open/download. Each video carries resume/progress hooks for the next phase.
- **States:** a reusable `AsyncValueWidget` gives every screen consistent
  loading / empty / error (with retry); lists are lazy (`ListView.builder`).
- Android `INTERNET` permission + a url_launcher `<queries>` entry added.
  `flutter analyze` clean; widget + media-classification tests pass.

### Next up

- Add latest-viewed tracking (write `view_history`; debounced save/restore of
  video position) and build the Playlists tab; then achievement celebrations.
- Initialize the Supabase CLI project / link to a hosted project.
- Confirm Arabic specifics: font face, numeral style (Western `0-9` vs
  Arabic-Indic `٠-٩`), and whether a second language is ever in scope.
- Add "continue where you left off", playlists, and celebrations in `/app`.
