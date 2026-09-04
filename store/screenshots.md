# Screenshots

Both stores reject a listing with missing or wrong-sized screenshots, and this is
the one asset that cannot be generated from code — it needs the real app running
against real content. Plan for an hour with a device or simulator.

> Sizes below were correct in September 2026. Both consoles show the exact
> accepted dimensions when you upload; trust those.

---

## What to capture (the same six shots serve both stores)

Sign in as a student whose group has **real, populated content** — screenshots of
an empty catalogue look broken.

| # | Screen | Why it earns its place |
| --- | --- | --- |
| 1 | Home, with «تابِع ما بدأته» populated | Shows the app's headline feature in one glance |
| 2 | Browse → a category's subcategories | Shows the content is organised, not a dump |
| 3 | A lesson with its video player visible | Proves the video actually plays in-app |
| 4 | A lesson showing an inline PDF | The second content type, also in-app |
| 5 | A playlist detail with progress («اكتمل ٣ من ٨») | Sequential learning |
| 6 | Achievements grid, some earned | The reward loop, and it is visually the nicest screen |

Practical notes:

- Use **portrait** for every shot; the app is portrait-first.
- Turn off the status-bar clutter (simulator status bar overrides, or Do Not
  Disturb + full battery on device).
- Do not add marketing frames or captions for the first release — plain
  screenshots are accepted everywhere and there is nothing to get wrong.
- Never capture a screen containing a real student's name. Use the reviewer
  account or seed data.

---

## Apple App Store

Required, because the target builds for both device families:

| Device class | Pixel size (portrait) | Count |
| --- | --- | --- |
| iPhone 6.9" | 1290 × 2796 **or** 1320 × 2868 | 3–10 (upload all 6) |
| iPad 13" | 2064 × 2752 **or** 2048 × 2732 | 3–10 (upload all 6) |

Apple scales the 6.9" set down for smaller iPhones automatically, so one iPhone
set is enough. If you set `TARGETED_DEVICE_FAMILY = 1` (iPhone only) as described
in [app-store.md](app-store.md), the iPad set is not needed.

Capture with the simulator: `iPhone 16 Pro Max` and `iPad Pro 13-inch`, then
⌘S saves a correctly-sized PNG to the desktop.

---

## Google Play

| Asset | Size | Count |
| --- | --- | --- |
| Phone screenshots | min 320 px, max 3840 px on the long edge; 16:9 or 9:16 | 2 minimum, 8 maximum — upload 6 |
| 7" tablet (optional) | same rules | upload the same 6 to be listed as tablet-ready |
| 10" tablet (optional) | same rules | as above |
| Feature graphic | 1024 × 500 | 1 — already generated at `assets/play-feature-graphic-1024x500.png` |
| App icon | 512 × 512 | 1 — already generated at `assets/play-icon-512.png` |

A 1080 × 2400 phone capture (any modern Android device or emulator) satisfies the
phone requirement.

---

## Regenerating the icons

The icons and the feature graphic come from one script, so a colour or shape
change propagates everywhere at once:

```bash
node tools/generate_app_icons.mjs
```

It rewrites every Android mipmap, the whole iOS `AppIcon.appiconset`, and the
three store assets. Edit the palette or the geometry near the top of
`tools/generate_app_icons.mjs` and re-run.
