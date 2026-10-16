# Google Play launch plan

The working checklist for getting **منصة المعلّم** onto Google Play. iOS is
postponed — see [`RELEASE.md`](RELEASE.md) for that when the time comes.

Reference material lives in [`store/google-play.md`](store/google-play.md)
(listing copy, Data safety answers, content rating) and
[`store/review-notes.md`](store/review-notes.md) (the reviewer account).

Legend: **[done]** already finished · **[you]** needs your accounts or a device ·
**[either]** can be handed back to Claude.

> **Status last verified 2026-10-16** against the live backend and the live
> admin deployment. Anything marked **[done]** below was checked on that date,
> not merely assumed. Store requirements change — treat the Play Console as
> authoritative over this file.

---

## Where things stand

| | Status |
| --- | --- |
| Package name `com.teachercms.student` | **[done]** permanent, set on both platforms |
| App icons, Play icon, feature graphic | **[done]** `store/assets/` |
| Listing copy in Arabic | **[done]** `store/google-play.md` |
| Data safety / content rating answers | **[done]** worked out, ready to transcribe |
| Legal documents written | **[done]** `admin/public/legal/` |
| **Supabase backend** | **[done]** alive and reachable — see Step 0 |
| **Hosted DB migrations** | **[done]** 000600/000700/000800 applied 2026-10-16 |
| **Content + accounts to review against** | **BLOCKER #1** — no group grants anything, so every student sees an empty app |
| **Legal pages actually reachable** | **BLOCKER #2** — deployed build still predates them |
| **Upload keystore** | **BLOCKER #3** — not present on this machine; without it there is no uploadable AAB |
| Upload-ready AAB | **not available here** — see Step 5 |
| Screenshots | not started — needs the app running against real content |
| Play Console listing | not started |

The three blockers are independent of one another and can be worked in
parallel. Downstream order is: **content → keystore → artifact → screenshots →
console**.

---

## Step 0 — Backend reachability · **[resolved 2026-10-16]**

**An earlier revision of this plan recorded the backend as deleted and treated
it as "BLOCKER #0, blocks everything". That was wrong.** The project is alive,
and it was used to apply the pending migrations. Verified 2026-10-16:

```
DNS  djtcqaqmonvajlzaeokw.supabase.co -> 104.18.38.10, 172.64.149.246
REST GET /rest/v1/                    -> HTTP 401   (endpoint live; 401 = no auth header)
GET  /auth/v1/health                  -> HTTP 200   {"version":"v2.197.0","name":"GoTrue"}
Postgres (session pooler, port 5432)  -> connected; migrations applied
```

The earlier `NXDOMAIN` reading (dated 4 Sep 2026) was transient or a local
resolver failure — not a deleted project. **Nothing needs recreating, and the
ref baked into the clients is correct.** If you hit a connection failure in
future, re-run the checks above before concluding the project is gone; a paused
free project still resolves and answers with a "paused" response.

Verify student-facing access at any time with:

```bash
node tools/verify_student_access.mjs <username> <password>
```

---

## Step 1 — Groups, content, accounts · **[you]** · BLOCKER #1

**This is the real blocker, and it gates both the review and the screenshots.**
Group-based visibility is live (`000600`), but nothing has been granted yet. As
of 2026-10-16 the hosted database looks like this:

| Group | Members | Categories granted | Subcategories granted |
| --- | --- | --- | --- |
| أولى اعدادى | 0 | 0 | 0 |
| تانيه اعدادى | 1 | 0 | 0 |
| تالته اعدادى | 0 | 0 | 0 |

Three student accounts exist; two are in no group at all, and the third is in a
group that grants nothing. **So all five published posts are invisible to every
student.** Sign-in is mandatory and there is no sign-up, so a reviewer handed an
account would see an empty app — the most common rejection for this kind of app.

Content currently in the database:

| Category | Subcategory | Published posts |
| --- | --- | --- |
| الصف الاول الابدائي | المنهج | 3 |
| الصف الاول الابدائي | review | 1 |
| Math | 1 Secondary | 1 |
| محتوى الضيف (`guest`) | — none yet — | 0 |

In the admin portal, in this order:

1. **المجموعات** — grant each class group its categories or subcategories.
2. **الطلاب** — assign the existing students to groups.
3. **Publish real content** — at minimum one category containing a **video**
   lesson, a **PDF** lesson, and a **playlist**. Both the screenshots and the
   Play review depend on the app not looking empty.
4. **Create the reviewer account** exactly as in
   [`store/review-notes.md`](store/review-notes.md) §1: username `reviewer`, in
   a group with real content. Google's "App access" section is mandatory
   because sign-in is required.
5. *(optional)* The **guest** account. `000800` has already provisioned the
   «محتوى الضيف» category, the **الضيوف** group and the grant between them — all
   that remains is publishing a post under that category and creating the guest
   student account. Still optional for v1: a build without the guest
   dart-defines hides the button entirely.

---

## Step 2 — Apply the pending migrations · **[done 2026-10-16]**

`000600`, `000700` and `000800` are applied to the hosted database.

Worth recording for accuracy: `000600` and `000700` turned out to be **already
applied** before this step ran, so only `000800` (guest category + الضيوف group
+ the grant between them) was genuinely outstanding. All three were re-run from
[`supabase/_apply_pending_hosted.sql`](supabase/_apply_pending_hosted.sql) in a
single transaction — they are idempotent, so this was a safe no-op for the first
two and also guarded against a partially-applied `000600`.

Verified afterwards: all four group tables and both `can_see_*` helpers exist,
all six re-gated read policies reference them, `profiles` has `serial_number`
and `request_code`, and the guest category, group and grant are each present
exactly once.

The consequence is Step 1: visibility is now opt-in, and nothing is granted yet.

---

## Step 3 — Publish the legal pages · **[you]** · BLOCKER #2

Play requires a privacy-policy URL *and* a data-deletion URL. All four `/legal/`
URLs return `200` while serving the **admin SPA**, because the live deployment
predates the legal files. A reviewer clicking your policy link lands on a login
screen. Re-confirmed 2026-10-16:

```
GET /legal/privacy.html -> HTTP 200, but the body contains no legal.css — it is the SPA
```

The pages themselves are committed and correct; they only need deploying. They
are static HTML that never touches Supabase, so this is independent of
everything else.

There is no usable Vercel credential on this machine (no token in the
environment, no CLI `auth.json`, and no `admin/.env.local`). Authenticate first:

```bash
cd admin
npx vercel login          # interactive browser flow
npm run build
npx vercel deploy --prod --yes
```

Or create a token at vercel.com/account/tokens scoped to the `students-cms`
team so this can be automated:

```bash
npx vercel deploy --prod --yes --token="$VERCEL_TOKEN"
```

Then verify by **content, not status code**:

```bash
curl -s https://teacher-cms-admin.vercel.app/legal/privacy.html | grep -q "legal.css" \
  && echo "policy is live" || echo "still serving the SPA"
```

Repeat for `terms.html`, `delete-account.html`, and `/legal/`.

Redeploying also ships the Phase 8–10 admin UI (المجموعات, الطلاب, the Excel
import), which Step 1 needs — so in practice do this one first.

---

## Step 4 — Screenshots · **[either]**

Play needs **2 minimum, 8 maximum**; upload 6. Shot list and rules are in
[`store/screenshots.md`](store/screenshots.md). No screenshots exist yet.

Blocked until Step 1 gives the app something to display — an empty catalogue
photographs as a broken app.

Capture needs a device or emulator. **Neither is available on this machine:**
`flutter`, `adb` and `emulator` are all absent. (An earlier revision of this
plan described a `Pixel_2_API_26` AVD; that was on a different machine.) So
either:

- **A real Android phone** — best results; install via `flutter run --release`
  or from the AAB with `bundletool`.
- **An emulator** — install the Android SDK and create an AVD at a valid Play
  size. Prefer a recent system image; the app's `minSdk` is 24, but the WebView
  and PDF surfaces are worth checking on something modern.

Hand this back to Claude once content exists and a device or emulator is
reachable.

---

## Step 5 — Build the upload artifact · **[you]** · BLOCKER #3

A previous revision marked this **[done]** — a 58.5 MB release-signed AAB with
production credentials compiled into all three ABIs. **That artifact is not on
this machine, and neither is the key that signed it:**

| Needed | Present here? |
| --- | --- |
| `app/build/app/outputs/bundle/release/app-release.aab` | no (build output, gitignored) |
| `keystores/teacher-cms-upload.jks` | **no** |
| `app/android/key.properties` | **no** |
| `app/dart_define.json` (the Supabase credentials) | **no** (gitignored) |
| `flutter` toolchain | **not installed** |
| `keytool` (JDK) | **not installed** |

**Find that keystore before generating a new one.** `RELEASE.md` §2 says it
exists "only on this machine", so it is on whichever machine produced that
build — check there and in your password manager. The upload key is what lets
you ship *updates* to the same listing: publish with a new key and a later
recovery of the old one is worthless, and vice versa.

Nothing is published yet, so if the original is genuinely gone, generating a
fresh key costs nothing. Once you do, **back it up immediately** — Play App
Signing can reset a lost upload key on request, but it is slow and needs proof.

To rebuild once the toolchain, keystore and `dart_define.json` are in place:

```bash
cd app
flutter build appbundle --release --dart-define-from-file=dart_define.json
```

> A build with **empty** dart-defines is not a valid test of the real thing. It
> comes out ~7 MB smaller because `SupabaseConfig.isConfigured` becomes a
> compile-time `false`, letting Dart tree-shake the entire signed-in half of the
> app. Always build with the defines file before uploading, and treat a
> surprisingly small AAB as a symptom.
>
> Equally, a release build with no `key.properties` is **debug-signed** and
> cannot be uploaded — the Gradle config warns rather than failing, by design.

Version for the first upload is `1.0.0+1` from `app/pubspec.yaml`. Every
subsequent upload needs the number after `+` increased.

---

## Step 6 — Play Console · **[you]**

Transcribe from [`store/google-play.md`](store/google-play.md) — every answer
there matches what the code actually does, which matters most for Data safety,
where a wrong answer is a policy violation rather than a typo.

1. **Create app** — منصة المعلّم, Arabic, App, Free.
   *(Free → paid is impossible later; paid → free is fine.)*
2. **Store listing** — name, short and full description, the 512 icon, the
   1024×500 feature graphic, screenshots.
3. **App content** — work every card:
   - Privacy policy → the URL from Step 3
   - Ads → **No**
   - App access → reviewer credentials + the sign-in block from `review-notes.md`
   - Content rating questionnaire → expect Everyone / PEGI 3
   - Target audience → 13–15, 16–17, 18+; *not* designed for children
   - Data safety → the three declared types, encrypted in transit, deletion URL
   - Advertising ID → **No**
4. **Testing → Closed testing** — upload the AAB, add testers.
5. **Production** — create the release, release notes, countries, submit.

---

## Step 7 — The thing to check first · **[you]**

If your Play developer account is a **personal** account created from late 2023
onward, Google requires a **closed test with 12+ testers, opted in continuously
for 14 days**, before production access is granted. Organisation accounts are
exempt.

**Check this before anything else.** If it applies, it is a two-week wall-clock
delay and nothing else on this list shortens it — so get the closed test running
the day the AAB is ready, and do the listing paperwork while it runs. This
requirement has been revised more than once; the console is authoritative.

---

## Suggested order of work

| When | Do |
| --- | --- |
| **Right now** | **Step 7** — find out whether you owe a 14-day closed test. Needs no backend and no build, and it sets the whole timeline |
| **Right now** | **Step 5** — hunt for `teacher-cms-upload.jks`. If it is lost you want to know today, not after the listing is built |
| Today | **Step 3** — deploy the legal pages (~10 min). Also ships the admin UI that Step 1 needs |
| Next | **Step 1** — grants, assignments, real content, reviewer account |
| Then | Install the Flutter/Android toolchain, then finish **Step 5** (keystore + AAB) |
| Then | **Step 4** screenshots, against the content from Step 1 |
| Then | **Step 6** console; upload to the closed track as soon as the AAB exists |
| Before submitting | The pre-submission checklist in [`RELEASE.md`](RELEASE.md) §9 |
