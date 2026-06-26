# /app — Student mobile app

The **student-facing** client. A Flutter app (Android + iOS) that students use
to browse and consume the content the teacher publishes.

## Purpose

- Free, login-based access to published content.
- Browse posts by category → subcategory and by tags.
- View embedded video, PDFs, and other file attachments.
- "Continue where you left off" — resume the latest-viewed content.
- Follow playlists (ordered collections of posts).
- Show celebration animations when a student reaches an achievement.

## Language & direction

**Arabic-first and RTL by default** (`MaterialApp(locale: Locale('ar'))`,
`TextDirection.rtl`). Use direction-aware widgets (`EdgeInsetsDirectional`,
`AlignmentDirectional`, `start` / `end`), bundle an Arabic font, route all
strings through localization, and flip directional icons/progress for RTL.
See `/CLAUDE.md` → *Language & direction*.

## Backend

Talks to the shared Supabase project (see `/supabase`) for auth, data, and file
storage.

## Status

Not scaffolded yet. The Flutter project will be created in a later phase.
