# /store — App store listing material

Everything the two consoles ask for, written out so submission is transcription
rather than improvisation. The build-and-submit procedure itself is in
[`/RELEASE.md`](../RELEASE.md).

| File | What it holds |
| --- | --- |
| [google-play.md](google-play.md) | Play listing copy (Arabic), Data safety answers, content rating, target audience, release setup |
| [app-store.md](app-store.md) | App Store listing copy (Arabic), App Privacy nutrition labels, age rating, guideline notes |
| [review-notes.md](review-notes.md) | The reviewer account, sign-in instructions, and the notes block for both consoles |
| [screenshots.md](screenshots.md) | Required sizes per store and the six shots to capture |
| `assets/` | Generated icon and graphic assets (below) |

## Generated assets

| File | Used for |
| --- | --- |
| `assets/play-icon-512.png` | Play Console app icon (512×512) |
| `assets/play-feature-graphic-1024x500.png` | Play Console feature graphic |
| `assets/appstore-icon-1024.png` | Reference copy of the App Store icon (the real one ships inside the build) |

All three — plus every Android mipmap and the whole iOS icon set — come from
`node tools/generate_app_icons.mjs`. Change the palette or geometry at the top of
that script and re-run; nothing here is hand-edited.

## Keeping it honest

The privacy claims appear in four places that reviewers compare against each
other:

1. `admin/public/legal/privacy.html` — the published policy
2. `store/google-play.md` → Play's Data safety form
3. `store/app-store.md` → Apple's App Privacy labels
4. `app/ios/Runner/PrivacyInfo.xcprivacy` — shipped inside the binary

If the app starts collecting something new, all four change together.
