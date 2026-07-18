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

### Phase 4 — Content browsing & post viewer

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

### Phase 5 — Latest-viewed tracking & playlists

- **Latest-viewed:** opening a post upserts a `view_history` row; video
  playback position is saved on a throttle (a 5s timer plus a final flush on
  exit, so we never write every second) and restored on the next open. The
  Home "تابِع ما بدأته" row now reflects real history, newest first, with the
  saved resume position shown where available.
- **Playlists tab:** lists published playlists (cached cover images); the
  detail screen shows posts in order with per-post progress (viewed/resume)
  and "اكتمل X من N".
- **Sequential playback:** opening a post from a playlist carries a
  `PlaylistContext`; a bottom bar advances to the next lesson, and finishing a
  video auto-advances (inline end-of-stream / YouTube `ended` state).
- New layers: `PlaylistRepository` + providers, `view_history` write methods,
  a `PostView` (detail + resume) provider. Unit tests cover the sequential
  `PlaylistContext` logic; `flutter analyze` clean, all tests pass.

### Phase 6 — Achievement celebrations

- **Server-side detection** (`/supabase` migration `…000400`): a lightweight
  `student_activity` day-log (for streaks), the starter achievement set
  (first view, 5 & 25 views, 5-day streak, first playlist completed), and a
  SECURITY DEFINER `claim_achievements()` RPC that records activity, grants any
  newly-earned achievements, and **returns just those** so the client can
  celebrate them. Detection is authoritative in Postgres; the client can only
  ask the server to evaluate. Validated end-to-end on Postgres 16.
- **Triggering:** the app calls `claim()` on app open (covers streaks) and
  after each post view (covers view counts + playlist completion); a Riverpod
  queue surfaces unlocks one at a time.
- **Celebration overlay:** confetti (`confetti`), a scaling + glowing badge and
  staggered text via Flutter's animation framework (elastic/eased `Interval`s),
  Lottie accent rings (`lottie`, with a graceful fallback), and a haptic. It's
  generic over `CelebrationData`, so new achievements need no overlay changes.
- **Why these tools:** Flutter's framework drives the transition choreography
  (full control, no assets); `confetti` for physics-based particles; **Lottie**
  for the vector accent (text-based JSON, designer-replaceable). **Rive** was
  skipped — it needs a binary `.riv` authored in its editor, whereas a Lottie
  JSON is reviewable/editable in-repo.
- **Achievements screen** in Profile: a grid of earned (colorful, pop-in) and
  locked (muted) badges. **Reduce-motion** is respected everywhere (no
  confetti/Lottie/scale; a settled, static presentation instead).
- `flutter analyze` clean; widget + unit tests pass (incl. an overlay render
  test and the SQL engine validation).

### Phase 7 — Teacher-managed student accounts (current)

- **Access model flip:** the app no longer self-registers students. The teacher
  (super admin) creates every account from the admin portal; the app has **no
  sign-up flow** — only sign-in.
- **Username login:** students sign in with a *username* + password (not email).
  Each username maps to a deterministic synthetic email
  `‹username›@‹kStudentEmailDomain›` (constant in `app/lib/src/core/config/
  auth_config.dart`, mirrored by the function's `STUDENT_EMAIL_DOMAIN`) so
  Supabase Auth stays email-based under the hood. App changes: sign-up screen +
  `signUp` methods removed, `welcome_screen` deleted, `RootScreen` routes
  straight to `SignInScreen`, sign-in field is now a username.
- **Secure backend:** a **Vercel serverless function** (`admin/api/students.ts`)
  holds the `service_role` key (server-only env) and is the *only* thing that
  creates/modifies auth users. It verifies the caller's admin JWT on every
  request and refuses to touch non-student accounts. Actions: `list` (merges
  `auth.users` + `profiles`), `create` (Admin API, `email_confirm:true` — also
  sidesteps the NULL-token login-500), `reset_password`, `rename`,
  `set_disabled` (ban/unban), `delete`. No DB migration needed — the existing
  `on_auth_user_created` trigger still makes the profile row.
- **Admin UI:** a new "الطلاب" page (`StudentsListPage`) + `src/api/students.ts`
  wrappers (forward the admin JWT to the function). Create/reset show a copyable
  credentials hand-off dialog (no email is sent). `vercel.json` rewrite tightened
  to `/((?!api/).*)` so it can't shadow the function.
- **Config (manual):** disable "Allow new users to sign up" in the Supabase
  Auth dashboard (authoritative lock); set `SUPABASE_URL`,
  `SUPABASE_SERVICE_ROLE_KEY`, `STUDENT_EMAIL_DOMAIN` as Vercel env vars.
- `flutter analyze` + tests pass; admin `tsc`/build green; the function
  typechecks standalone.

### Phase 8 — Group-based content visibility (current)

- **Access model:** students belong to zero or more **groups**; each group is
  granted **whole categories** and/or **individual subcategories**. A student
  sees the **union** of what all their groups allow; a student in no group (or
  whose groups grant nothing) sees **no content** — access is opt-in.
- **Schema** (`/supabase` migration `…000600`): `groups`, `group_members`
  (group↔student), `group_categories` (whole-category grant, incl. future
  subcategories), `group_subcategories` (single-subcategory grant). Two
  SECURITY DEFINER helpers — `can_see_subcategory(uuid)` /
  `can_see_category(uuid)` — resolve visibility for `auth.uid()` (both return
  true for admins).
- **Enforcement is in RLS (authoritative):** the migration replaces the open
  "read published" policies on `categories`, `subcategories`, `posts`,
  `post_tags`, `media`, and `playlist_items` with group-gated ones. The Flutter
  app needs **no query changes** — its existing reads inherit the filter and
  can't widen it. Admins still bypass everything.
- **Admin function** (`admin/api/students.ts`): `list` now returns each
  student's groups; `create` accepts `group_ids`; new `set_groups` action
  replaces a student's memberships (all via `service_role`, which bypasses RLS).
- **Admin UI:** new "المجموعات" page (`GroupsListPage`) — group CRUD plus a
  category/subcategory grant tree (check a whole category or cherry-pick
  subcategories). `StudentsListPage` gains a groups column, a group multi-select
  on create, and a per-student "assign groups" dialog. New `src/api/groups.ts`;
  `groups`/grant tables are admin-managed directly via RLS (like categories).
- Admin `tsc --noEmit` + `vite build` green; serverless function typechecks
  standalone. **Pending:** apply `…000600` to the hosted DB and redeploy admin
  (see *Next up*) — applying it flips every student to group-based visibility,
  so groups must be created/assigned right after.

### Phase 9 — Bulk student import from Excel (current)

- **Goal:** onboard a whole class at once from the teacher's roster workbook
  instead of one-by-one. New route `/students/import` (button on the الطلاب
  page); the `xlsx`/SheetJS parsing is **code-split** onto this route only.
- **Workbook shape:** one sheet per class; the sheet tab's **first two words are
  the group** (Arabic-normalized for matching). Columns located by header text —
  `الاسم` (name), `الرقم التسلسلي` (serial), `كود الطلب` (request code),
  `تليفون الطالب` / `تليفون ولي الأمر` (phones). Attendance grid ignored; blank
  template sheets (e.g. `فارغ`) auto-skipped.
- **Username** = smart first-name transliteration + a **5-digit djb2 hash of the
  full (normalized) name**, e.g. «عبد الله أحمد» → `abdullah24819`. عبد/أبو
  compounds stay together; a ~150-name dictionary (`src/lib/transliterate.ts`)
  covers common Egyptian names with a per-letter rule fallback. **Password** =
  2 letters + 6 digits. In-batch + on-server username collisions are
  auto-disambiguated (suffix bump) and flagged live.
- **Editable review table** (`StudentsImportPage`): grouped per source sheet,
  shows name / **username** / **password** / phone / serial / request code, all
  editable. Groups are **match-existing-only** — a sheet whose group isn't found
  is flagged and its rows excluded until the teacher creates the group and hits
  «إعادة مطابقة المجموعات» (no re-upload, edits preserved).
- **Submit:** downloads an Excel **credentials record** (one worksheet per source
  sheet, passwords included — they can't be recovered later), then creates each
  account **row-by-row** via the existing `create` action, colouring the row
  green on success / red on failure and continuing through the list.
- **Backend:** migration `…000700` adds `profiles.serial_number` +
  `profiles.request_code` (admin-facing; phone is shown/exported but **not**
  stored, per choice). `api/students.ts`: `create` now persists serial/request
  code; new **`check_usernames`** action does a bulk existence check. Admin build
  + standalone function typecheck green; pure logic covered by an esbuild
  self-test (usernames, password format, phone-as-decimal, sheet parsing).

### Phase 10 — Guest login (current)

- **Goal:** a **"الدخول كضيف"** button on the app's sign-in screen that drops a
  visitor straight into the app as a single shared **guest** student, seeing only
  the content the teacher exposes to guests. No new auth mode — the guest is an
  ordinary student whose one group grants a single **"guest" category**, so the
  Phase 8 group-based RLS scopes everything automatically.
- **App:** `auth_config.dart` gains `kGuestUsername` / `kGuestPassword` (build-time
  `--dart-define`, like the Supabase keys) + an `isGuestLoginEnabled` guard.
  `SignInScreen` shows an `OutlinedButton` (guarded by that flag) that calls the
  existing `signIn(studentEmailForUsername(kGuestUsername), kGuestPassword)` and
  lands in `HomeShell` via `RootScreen`'s auth-state routing — no nav code. The
  button hides itself when the defines are unset. `dart_define.example.json`
  documents the two new keys.
- **Backend:** migration `…000800` provisions the guest **category** (slug
  `guest`), the **"الضيوف" group**, and the category→group grant (idempotent).
  Two manual follow-ups remain: author a published post under the guest category,
  and create the guest **student account** (username=`GUEST_USERNAME`,
  password=`GUEST_PASSWORD`) assigned to the الضيوف group — auth users must be
  made via the admin portal, not raw SQL (login-500 on NULL token columns).
- `flutter analyze` clean.

### Next up

- **Apply migrations `…000600`, `…000700`, and `…000800` to the hosted DB and
  redeploy the admin portal.** For guest login: after applying `…000800`, author a
  published post under the **guest** category, create the guest student account
  (username=`GUEST_USERNAME` / password=`GUEST_PASSWORD`) and assign it to the
  **الضيوف** group, then build the app with the `GUEST_USERNAME` / `GUEST_PASSWORD`
  dart-defines set.
- **Apply migrations `…000600` and `…000700` to the hosted DB and redeploy the
  admin portal.** `000700` only adds two nullable `profiles` columns (safe,
  independent of `000600`). NOTE: once `000600` is applied, existing students see
  nothing until assigned to a group — so create groups **before** importing, and
  do assignments promptly. The import matches sheet→group by name, so the groups
  must exist first.
- (Optional) friendlier app empty-state for a student with no group yet
  ("contact your teacher") — currently they just see an empty catalog.

- Deploy the admin portal to Vercel (set the four env vars) and flip off public
  sign-ups; then create the first students and verify app login end-to-end.
- Initialize the Supabase CLI project / link to a hosted project.
- Confirm Arabic specifics: font face, numeral style (Western `0-9` vs
  Arabic-Indic `٠-٩`), and whether a second language is ever in scope.
- Run the full app on a device/emulator and wire it to a hosted Supabase
  project (only `flutter analyze` + tests run in this container).
