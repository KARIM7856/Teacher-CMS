# Publishing the student app

Step-by-step for shipping `/app` to **Google Play** and the **Apple App Store**.
Follow it in order the first time; §8 is the shorter path for every update after
that.

> **Current plan: Google Play first. iOS is postponed.** The Apple side is fully
> prepared — bundle id, privacy manifest, icons, listing copy, and a CI workflow
> that builds without a Mac — but nothing there is started, and no Apple account
> is needed yet. Sections marked *(postponed)* can be skipped for now. The
> **live path is §0 → §2 → §3 → §4 → §5.1-5.3 → §6**.

Listing copy and every console answer live in [`/store`](store/). Read
[`store/review-notes.md`](store/review-notes.md) before you submit — a missing
reviewer account is the most common reason this kind of app gets rejected.

> Store rules change. Where this file states a limit or a policy, the console is
> authoritative — re-check before submitting.

---

## 0. The app's permanent identity

Both of these are **fixed forever** once either store accepts the first upload.
They are already set in the code:

| | Value |
| --- | --- |
| **Android `applicationId`** | `com.teachercms.student` |
| **iOS bundle identifier** | `com.teachercms.student` |
| Android namespace / Kotlin package | `com.teachercms.student` |
| Launcher name (Android) | منصة المعلّم |
| Display name (iOS) | منصة المعلّم |
| Play Store URL will be | `play.google.com/store/apps/details?id=com.teachercms.student` |

If you ever want a different id, change it **now**, before the first upload:
`app/android/app/build.gradle.kts` (`namespace` + `applicationId`), the Kotlin
package path under `app/android/app/src/main/kotlin/`, and
`PRODUCT_BUNDLE_IDENTIFIER` in `app/ios/Runner.xcodeproj/project.pbxproj`.

---

## 1. Accounts and tools you need

| | Cost | Notes |
| --- | --- | --- |
| Google Play Developer account | one-off $25 | Personal accounts opened since late 2023 must run a 14-day closed test with 12+ testers before production — start that early |
| Apple Developer Program | $99/year | *(postponed)* Not needed until the iOS launch. See §5.5 for the prerequisites when you get there |
| Flutter SDK | — | Already at `C:\src\flutter` |

Android builds work fine from this Windows machine — no CI or extra hardware is
needed for the Play release.

---

## 2. Back up the signing key — do this first

`keystores/teacher-cms-upload.jks` (with `app/android/key.properties`) is the
**upload key** for Play. Both are gitignored and exist only on this machine.

**If you lose them you cannot ship an update to the same listing.** Play App
Signing lets Google reset a lost upload key on request, but the process is slow
and needs proof — losing the file is still a bad day. Copy both files now to a
password manager or an encrypted backup, along with the passwords in
`key.properties`.

For iOS, Xcode manages the distribution certificate through your Apple account;
nothing local to back up beyond the account credentials.

---

## 3. Prepare the backend

The app cannot be reviewed against an empty database.

1. **Apply the pending migrations** to the hosted Supabase project, in order:
   `…000600_content_groups.sql`, `…000700_student_import_fields.sql`,
   `…000800_guest_content.sql`.
   Applying `000600` switches every student to group-based visibility, so
   students with no group see nothing until assigned.
2. **Create groups and grant content** in the admin portal (المجموعات), then
   assign students.
3. **Publish real content** — at minimum one category with lessons that include a
   video, a PDF, and a playlist. Screenshots and the review both depend on it.
4. **Create the guest account** (username = your `GUEST_USERNAME`, password =
   `GUEST_PASSWORD`) and put it in the الضيوف group, and publish at least one
   post under the «محتوى الضيف» category. Without this the guest button fails.
5. **Create the reviewer account** exactly as described in
   [`store/review-notes.md`](store/review-notes.md) §1.
6. Confirm public sign-up is still **disabled** in the Supabase Auth dashboard.

---

## 4. Publish the legal pages

Both stores demand a privacy policy URL that resolves, and Play additionally
requires a data-deletion URL. The pages are static files in
`admin/public/legal/`, deployed with the admin portal:

```bash
cd admin
npm run build
npx vercel deploy --prod --yes
```

Then confirm each URL actually serves the document:

- https://teacher-cms-admin.vercel.app/legal/privacy.html
- https://teacher-cms-admin.vercel.app/legal/terms.html
- https://teacher-cms-admin.vercel.app/legal/delete-account.html
- https://teacher-cms-admin.vercel.app/legal/ (support page)

**A `200` is not proof.** Before this deploy, all four returned `200` while
serving the admin login SPA, because the old `vercel.json` rewrite swallowed
`/legal/`. A reviewer following your privacy-policy link would have landed on a
login screen — an instant rejection. Check the content, not the status code:

```bash
curl -s https://teacher-cms-admin.vercel.app/legal/privacy.html | grep -q "legal.css" \
  && echo "policy is live" || echo "still serving the SPA — redeploy"
```

If you move the admin portal to a custom domain, update `legalBaseUrl` in
`app/lib/src/core/config/app_info.dart` (or pass
`--dart-define=LEGAL_BASE_URL=…`) **and** the URLs in both consoles.

---

## 5. Build the release artifacts

### 5.1 Set the version

`app/pubspec.yaml` line 4 drives both platforms:

```yaml
version: 1.0.0+1
#        ^^^^^ versionName / CFBundleShortVersionString (what users see)
#              ^ versionCode / CFBundleVersion (must increase with every upload)
```

Keep `AppInfo.version` in `app/lib/src/core/config/app_info.dart` in step — it is
what the profile screen prints.

### 5.2 Fill in the credentials file

```bash
cd app
cp dart_define.example.json dart_define.json   # gitignored
```

Fill in `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GUEST_USERNAME`, `GUEST_PASSWORD`.
Leaving the guest values empty simply hides the guest button.

### 5.3 Android App Bundle

```bash
cd app
flutter clean
flutter pub get
flutter build appbundle --release --dart-define-from-file=dart_define.json
```

Output: `app/build/app/outputs/bundle/release/app-release.aab`

Sanity-check before uploading:

```bash
# should print com.teachercms.student and your versionCode
"$env:LOCALAPPDATA/Android/Sdk/build-tools/36.0.0/aapt2" dump badging \
  build/app/outputs/bundle/release/app-release.aab
```

If the build warns that `key.properties` was not found, it signed with the debug
key and Play will refuse the upload — fix the path in `key.properties` and
rebuild.

### 5.4 iOS archive (on a Mac) *(postponed)*

```bash
cd app
flutter clean
flutter pub get
flutter build ipa --release --dart-define-from-file=dart_define.json
```

No `pod install` step: this project uses Flutter's **Swift Package Manager**
integration for plugins (there is no `Podfile`, and the Xcode project references
`FlutterGeneratedPluginSwiftPackage`). `flutter build ipa` resolves the packages
itself, and generates a Podfile only if some plugin still needs CocoaPods.

Then open `build/ios/archive/Runner.xcarchive` in Xcode → **Distribute App → App
Store Connect**, or upload `build/ios/ipa/*.ipa` with Transporter.

First time on the Mac, in Xcode → Runner → Signing & Capabilities: select your
team and let Xcode create the `com.teachercms.student` App ID.

### 5.5 Building iOS without a Mac — GitHub Actions *(postponed)*

`flutter build ipa` only runs on macOS, and this project is developed on Windows.
[`.github/workflows/ios-release.yml`](.github/workflows/ios-release.yml) builds
and signs the archive on a GitHub-hosted `macos-latest` runner and optionally
ships it to TestFlight. **You need no Mac and no `.p12` certificate** — an App
Store Connect API key is enough, because `xcodebuild -allowProvisioningUpdates`
creates and reuses the distribution certificate and provisioning profile in your
Apple account.

> The workflow drives `xcodebuild` directly rather than calling
> `flutter build ipa`. Flutter does pass `-allowProvisioningUpdates`, but not the
> `-authenticationKey*` flags, and a fresh runner has no Apple ID signed into
> Xcode — so automatic provisioning would have nothing to authenticate with.
> `flutter build ios` still does the Dart and plugin compilation; only the
> archive and export steps are done by hand.

#### One-time setup (all of it from Windows)

1. **Enrol in the Apple Developer Program** — $99/year, at developer.apple.com.
   This is the hard prerequisite: a free Apple ID gets you no App Store Connect
   access at all, and therefore no API key. Also required:

   - **Two-factor authentication** on the Apple ID.
   - A decision between **Individual** and **Organization** enrolment.
     Organization needs a D-U-N-S number (free, but obtaining and verifying one
     can take days to weeks) and lets the app be sold under a company name.
     Individual is immediate by comparison, but **your legal personal name is
     shown publicly on the App Store listing** as the seller — worth deciding
     deliberately rather than discovering after launch.
   - Individual enrolment is often approved same-day; allow 24–48 hours.
     Enrolling through the Apple Developer app on an iPhone/iPad can be faster,
     because identity verification uses the device.

2. **Register the App ID.** developer.apple.com → Certificates, Identifiers &
   Profiles → Identifiers → **+** → App IDs → App → explicit bundle ID
   `com.teachercms.student`.
3. **Create the app record** in App Store Connect (My Apps → **+**). TestFlight
   uploads are rejected until the record exists.
4. **Create an App Store Connect API key.** App Store Connect → Users and Access
   → **Integrations** → App Store Connect API → Team Keys → **+**.

   - Creating a team key requires the **Account Holder** or **Admin** role. As a
     solo developer you are the Account Holder, so this is automatic.
   - Give the key **App Manager** access. A Developer-level key cannot create
     signing certificates, which is the whole point of using it here.
   - Download the `AuthKey_XXXXXXXX.p8`. **Apple lets you download it exactly
     once** — if you lose it, revoke the key and generate a new one.
   - Record the **Key ID** (10 characters, next to the key) and the **Issuer ID**
     (a UUID shown at the top of the page — one per team, shared by all keys).

   Treat the `.p8` as a high-value credential: at App Manager level it can manage
   your apps, builds, and signing assets. Keep it in a password manager. `.gitignore`
   now covers `*.p8`, `*.p12`, `*.cer` and `*.mobileprovision`, so it cannot be
   committed by accident — but this repository is public, so don't rely on that
   alone.
5. **Find your Team ID** on developer.apple.com → Membership (10 characters).
6. **Base64 the key** — in PowerShell:

   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\Downloads\AuthKey_XXXXXXXX.p8")) | Set-Clipboard
   ```

7. **Add the repository secrets** at
   github.com/KARIM7856/Teacher-CMS → Settings → Secrets and variables → Actions:

   | Secret | Value |
   | --- | --- |
   | `APP_STORE_CONNECT_KEY_ID` | the Key ID from step 4 |
   | `APP_STORE_CONNECT_ISSUER_ID` | the Issuer ID from step 4 |
   | `APP_STORE_CONNECT_PRIVATE_KEY` | the base64 from step 6 |
   | `APPLE_TEAM_ID` | the Team ID from step 5 |
   | `SUPABASE_URL` | production Supabase URL |
   | `SUPABASE_ANON_KEY` | production publishable key |
   | `GUEST_USERNAME` | optional — omit to ship without the guest button |
   | `GUEST_PASSWORD` | optional |
   | `LEGAL_BASE_URL` | optional — only if the legal pages move to a custom domain |

#### Running it

Actions → **iOS release** → **Run workflow**. Or push a `v*` tag to build and
upload automatically. Two inputs: whether to upload to TestFlight, and an
optional explicit build number.

- The build number defaults to the workflow **run number**, which increases on
  its own — TestFlight rejects a build number it has already seen, and this is
  the usual cause of a failed second upload.
- The `.ipa` and the dSYMs are uploaded as workflow artifacts **before** the
  TestFlight step, so a failed upload never costs you the build: download the
  artifact and send it with Transporter instead.
#### Cost

**This repository is public, so GitHub-hosted runners are free** — macOS included,
with no minute allowance to manage. Build as often as you need, which matters most
during first-time signing setup, where several failed attempts are normal.

The workflow is still written to be frugal, because the picture changes entirely
if the repo is ever made private:

- Analyzer and tests run on `ubuntu-latest` and gate the macOS job, so a broken
  test never reaches the slower runner.
- `timeout-minutes: 45` — just above the realistic worst case, so a hung job
  cannot run for hours.
- `concurrency: cancel-in-progress` — a superseded run is stopped rather than
  left to finish.

**If this repo ever goes private**, macOS minutes bill at **10×** (Linux 1×,
Windows 2×), so the Free plan's 2,000 included minutes become **200 minutes of
macOS time**. A cold build here is 20–35 minutes, i.e. 200–350 billed minutes —
roughly **8 builds a month**. You would not be billed by surprise: the Actions
spending limit defaults to **$0** on Free and Pro, so workflows stop running
rather than charging you. Raising it costs roughly $0.08/min for macOS (~$2 a
build); confirm current rates at github.com/settings/billing.

#### If the first run fails

- *"No profiles for 'com.teachercms.student' were found"* — the App ID was not
  registered (step 2), or the API key lacks App Manager access (step 4).
- *Authentication errors* — the base64 secret is malformed. Re-run step 6 and
  make sure you copied the whole string.
- *Export method rejected* — the workflow picks `app-store-connect` on Xcode 16+
  and `app-store` below that; check the "Export method" line in the log.
- Still stuck? Fall back to renting a Mac by the hour (MacinCloud, Scaleway,
  MacStadium) or borrowing one — you only need it at archive time.

Screenshots remain the one genuinely Mac-shaped task; see
[`store/screenshots.md`](store/screenshots.md).

---

## 6. Google Play submission

1. Play Console → **Create app**: name منصة المعلّم, language Arabic, App, Free.
2. **Store listing** — paste from [`store/google-play.md`](store/google-play.md);
   upload `store/assets/play-icon-512.png`, the feature graphic, and the
   screenshots from [`store/screenshots.md`](store/screenshots.md).
3. **Policy → App content** — work through every card using the answers in
   `store/google-play.md`: privacy policy, ads (none), app access (reviewer
   credentials), content rating questionnaire, target audience (13+), news
   (no), data safety, advertising ID (not used).
4. **Testing → Closed testing** — upload the `.aab`, add 12+ testers, and let it
   run 14 days if your account is subject to that requirement.
5. **Production → Create release** — upload the `.aab`, write release notes,
   choose countries, submit for review.

Review typically takes a few days for a first release, sometimes longer.

---

## 7. App Store submission *(postponed)*

1. Developer portal → register the App ID `com.teachercms.student` (or let Xcode
   do it during signing).
2. App Store Connect → **My Apps → +** → New App: platform iOS, name منصة المعلّم,
   primary language Arabic, bundle ID, SKU `teachercms-student-001`.
3. Fill the listing from [`store/app-store.md`](store/app-store.md): subtitle,
   promotional text, keywords, description, support and privacy URLs, category
   Education.
4. **App Privacy** — declare the three data types listed in that file. This is a
   separate section from the listing and blocks submission until complete.
5. **Age rating** — answer the questionnaire; expect 4+. Watch the
   "unrestricted web access" question: the answer is **No**.
6. Upload the build, wait for processing, then attach it to the version.
7. **App Review Information** — reviewer username and password, plus the notes
   block from `store/review-notes.md`.
8. Submit for review. First reviews commonly take 24–48 hours.

---

## 8. Shipping an update later

1. Bump `version:` in `app/pubspec.yaml` — the **build number after `+` must
   increase** on every upload to either store, even for a re-upload of the same
   version name.
2. Update `AppInfo.version` to match.
3. Rebuild (§5.3 / §5.4) and upload.
4. Play: new release on the production track. Apple: new version in App Store
   Connect, attach the build, submit.
5. If what the app collects has changed, update the privacy policy page, the
   Play Data safety form, the Apple nutrition labels, **and**
   `app/ios/Runner/PrivacyInfo.xcprivacy` together — they are four copies of the
   same claim and reviewers do compare them.

---

## 9. Pre-submission checklist

Backend

- [ ] Migrations `000600`, `000700`, `000800` applied to the hosted project
- [ ] Groups created, grants set, students assigned
- [ ] Real published content: a video lesson, a PDF lesson, a playlist
- [ ] Guest account created + guest category has a published post
- [ ] Reviewer account created, in a group with real content, verified by signing in
- [ ] Public sign-up disabled in Supabase Auth

Legal

- [ ] Admin portal redeployed; all four `/legal/` URLs load
- [ ] Contact address (k.massoud703@gmail.com) is monitored — reviewers do write to it

Build

- [ ] `dart_define.json` filled in with production Supabase credentials
- [ ] `flutter analyze` clean, `flutter test` green
- [ ] Version and build number bumped
- [ ] `.aab` built and confirmed release-signed
- [ ] Installed the release build on a real device and signed in successfully

Store

- [ ] Screenshots captured for every required size
- [ ] Play: all App content cards green, Data safety matches `store/google-play.md`
- [ ] Apple: App Privacy completed, age rating 4+, reviewer notes pasted
- [ ] Signing key and passwords backed up somewhere other than this machine

---

## Notes and open points

- **Governing law.** The terms deliberately contain no governing-law clause, since
  neither store requires one and naming the wrong jurisdiction is worse than
  naming none. If you want one, add a short section to
  `admin/public/legal/terms.html` naming your country.
- **Audience age.** Everything here assumes students aged **13+**. If you enrol
  pupils under 13, Play's Families Policy and stricter Apple rules apply: the
  Play target-audience answer changes, and the privacy policy needs COPPA and
  parental-consent sections.
- **iPad.** The iOS target currently builds for iPhone and iPad, which obliges you
  to supply iPad screenshots. See [`store/app-store.md`](store/app-store.md) for
  how to go iPhone-only instead.
- **Extra Android permissions you didn't ask for.** The merged release manifest
  requests `INTERNET` and `ACCESS_NETWORK_STATE` (ours), `WAKE_LOCK` (keeps the
  screen on during video, from `wakelock_plus` via chewie), and three that come
  from `androidx.credentials` — `USE_BIOMETRIC`, `USE_CREDENTIALS`,
  `CREDENTIAL_MANAGER_SET_ORIGIN`. That library arrives transitively with
  `supabase_flutter` for its *native Google sign-in* path, which this app never
  uses. All six are normal/signature-level: no runtime prompt, no Play permission
  declaration form, and nothing to add to Data safety. If you would rather they
  weren't listed on the store page, you can strip them with
  `<uses-permission android:name="…" tools:node="remove" />` in
  `app/android/app/src/main/AndroidManifest.xml` — but test sign-in on a real
  device afterwards, since you are removing declarations a bundled library made.
- **`PrivacyInfo.xcprivacy`.** Registered in the Xcode project by hand (it is in
  the Runner group and in Copy Bundle Resources). Open the project in Xcode once
  and confirm it appears under Runner → Build Phases → Copy Bundle Resources. If
  Apple still emails an ITMS-91053 warning naming an API category, add that
  category to the file and re-upload.
