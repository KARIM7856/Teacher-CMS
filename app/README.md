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

## Stack

- **Flutter** (Dart), Android + iOS
- **Riverpod** (`flutter_riverpod`) for state management
- **supabase_flutter** for auth, data, and storage against the `/supabase` backend
- Bundled **Cairo** Arabic font (`assets/fonts`)
- Media: **video_player** + **chewie** (inline video), **youtube_player_flutter**
  (YouTube), **pdfx** (in-app PDF), **url_launcher** (external/other files),
  **flutter_markdown** (post body), **cached_network_image** (lazy images)

### Why Riverpod

Compile-safe dependency injection without `BuildContext`, trivial provider
overrides for testing, and first-class async/stream support — a natural fit for
Supabase auth state and the data streams later screens will consume. It scales
cleanly as features grow.

## Architecture

Feature-first, with a clear separation of concerns:

```
lib/
  main.dart                  app entry; initializes Supabase
  src/
    app.dart                 MaterialApp (ar locale, RTL, theme)
    core/
      supabase/              client wrapper + config + provider
      theme/                 colors, spacing, typography, theme (one source)
      widgets/               shared widgets
    models/                  plain data models (e.g. Profile)
    features/<feature>/
      data/                  repositories (Supabase calls)
      application/           Riverpod providers / controllers
      presentation/          screens & widgets
```

Features: `auth`, `shell`, `home`, `browse`, `playlists`, `profile`.

## Language & direction

**Arabic-first and RTL by default**: `MaterialApp(locale: Locale('ar'))` plus
the Global Material/Widgets/Cupertino localizations drive RTL across the app.
All copy is Arabic; the bundled Cairo font is used throughout. Use
direction-aware widgets (`EdgeInsetsDirectional`, `start`/`end`) in new screens.
See `/CLAUDE.md` → *Language & direction*.

## Getting started

Requires the Flutter SDK. Credentials are passed at run time (never committed):

```bash
cd app
flutter pub get
cp dart_define.example.json dart_define.json   # fill in your Supabase values
flutter run --dart-define-from-file=dart_define.json
```

`dart_define.json` provides:

```
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-anon-public-key   # Supabase's "publishable" key
```

Without credentials the app launches to a "not configured" screen. With them you
get the welcome → sign-up/sign-in flow; sessions persist across launches.

Checks: `flutter analyze`, `flutter test`.

## What's built

- **Foundation (Phase 3):** auth flow, session persistence, the themed app
  shell with bottom-nav tabs, and the data/state plumbing.
- **Content browsing (Phase 4):** Home (continue + recent), Browse
  (categories → subcategories → posts, tag filter), and the post viewer
  (markdown body; inline video for stored/direct files, embedded YouTube,
  external open for Vimeo/unknown; in-app PDF; file open/download). Only
  published content is ever requested; every screen handles loading / empty /
  error, and lists load lazily.

The Playlists tab and achievement celebrations come in later phases.
