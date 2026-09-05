# Google Play launch plan

The working checklist for getting **منصة المعلّم** onto Google Play. iOS is
postponed — see [`RELEASE.md`](RELEASE.md) for that when the time comes.

Reference material lives in [`store/google-play.md`](store/google-play.md)
(listing copy, Data safety answers, content rating) and
[`store/review-notes.md`](store/review-notes.md) (the reviewer account).

Legend: **[done]** already finished · **[you]** needs your accounts or a device ·
**[either]** can be handed back to Claude.

---

## Where things stand

| | Status |
| --- | --- |
| Package name `com.teachercms.student` | **[done]** permanent, set on both platforms |
| **Upload-ready AAB built** | **[done]** 58.5 MB, release-signed, production Supabase credentials compiled into all 3 ABIs |
| App icons, Play icon, feature graphic | **[done]** `store/assets/` |
| Listing copy in Arabic | **[done]** `store/google-play.md` |
| Data safety / content rating answers | **[done]** worked out, ready to transcribe |
| Legal documents written | **[done]** `admin/public/legal/` |
| **Supabase backend** | **BLOCKER #0** — the project host does not resolve; nothing works until this is settled |
| **Legal pages actually reachable** | **BLOCKER** — deployed build predates them |
| **Hosted DB migrations** | **BLOCKER** — 000600/000700/000800 not applied |
| Content + accounts to review against | **BLOCKER** — depends on the above |
| Screenshots | not started — needs the app running against real content |
| Play Console listing | not started |

Blockers in a strict order: **backend → database → content → screenshots →
console**.

**Step 1 is the exception — it is not blocked by Step 0.** The legal pages are
static HTML that never touches Supabase, so they can be deployed today, and Play
needs those URLs whatever state the database is in. Do it while the backend
question is being sorted out.

---

## Step 0 — The backend is unreachable · **[you]** · BLOCKS EVERYTHING

`djtcqaqmonvajlzaeokw.supabase.co` **does not resolve**. Checked 4 Sep 2026:

```
nslookup djtcqaqmonvajlzaeokw.supabase.co  -> Non-existent domain
curl https://…/rest/v1/                    -> HTTP 000 (no connection)
nslookup supabase.co                       -> 76.76.21.21   (DNS is fine)
curl https://status.supabase.com           -> HTTP 200      (Supabase is up)
```

Supabase gives each project its own DNS record — a random ref does not resolve
either, so there is no wildcard and this absence is meaningful. A *paused* free
project still resolves and answers with a "paused" response, so **NXDOMAIN points
to the project being deleted or its ref having changed** — though only the
dashboard can say which.

This ref is baked into both clients: `app/dart_define.json`, and the deployed
admin bundle (`/assets/index-XqYkmfSO.js` contains the same URL). So right now
the admin portal cannot sign in and the app cannot load content.

**What to do**

1. Open the Supabase dashboard and establish whether the project is paused,
   deleted, or now under a different ref.
2. If it has to be recreated: run `supabase/_full_setup_hosted.sql` (migrations
   000000–000400 plus the Arabic sample seed) on the empty project, then
   `supabase/migrations/20250601000500_view_history_seen.sql`, then
   [`supabase/_apply_pending_hosted.sql`](supabase/_apply_pending_hosted.sql) for
   000600–000800. Recreate the admin user, then the students.
3. Update the URL and anon key in **three** places: `app/dart_define.json`, the
   admin portal Vercel env vars (`VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`),
   and the serverless function env vars (`SUPABASE_URL`,
   `SUPABASE_SERVICE_ROLE_KEY`).
4. **Rebuild the AAB.** The artifact from step 5 has the dead host compiled into
   it and would ship an app that can reach nothing.

Verify recovery with:

```bash
node tools/verify_student_access.mjs <username> <password>
```

---

## Step 1 — Publish the legal pages · **[you]**

Play requires a privacy-policy URL *and* a data-deletion URL. Right now all four
`/legal/` URLs return `200` while serving the **admin login page**, because the
live deployment predates the legal files and the old rewrite swallowed the path.
A reviewer clicking your policy link would land on a login screen.

**This does not depend on Step 0.** These are static files; they never talk to
Supabase, so the dead backend is irrelevant here. Deploy them now.

The fix is committed and only needs deploying. There is no usable Vercel
credential on this machine — no token in the environment, no CLI `auth.json`, and
`admin/.env.local` holds only a `VERCEL_OIDC_TOKEN` that expired 2026-07-09 (and
which could not deploy anyway; it is a workload-identity token for the deployed
function to authenticate *outward*). So authenticate first:

```bash
cd admin
npx vercel login          # interactive browser flow
npm run build
npx vercel deploy --prod --yes
```

Or, to let this be automated, create a token at vercel.com/account/tokens scoped
to the `students-cms` team and pass it explicitly:

```bash
npx vercel deploy --prod --yes --token="$VERCEL_TOKEN"
```

Then verify by **content, not status code**:

```bash
curl -s https://teacher-cms-admin.vercel.app/legal/privacy.html | grep -q "legal.css" \
  && echo "policy is live" || echo "still serving the SPA"
```

Repeat for `terms.html`, `delete-account.html`, and `/legal/`.

---

## Step 2 — Apply the pending migrations · **[you]**

Paste [`supabase/_apply_pending_hosted.sql`](supabase/_apply_pending_hosted.sql)
into Supabase Dashboard → SQL Editor → New query → Run. It is the three pending
migrations concatenated in order, and it is idempotent, so a failed run can
simply be pasted again.

> **This is the one irreversible-feeling step.** `000600` switches content
> visibility to group-based: the moment it lands, **every student sees nothing**
> until they are in a group that has been granted categories. Do step 3
> immediately afterwards — ideally in the same sitting, outside class hours.

Verify afterwards, in the SQL editor:

```sql
select count(*) from public.groups;                     -- الضيوف should exist
select count(*) from public.categories where slug='guest';
select column_name from information_schema.columns
 where table_name='profiles' and column_name in ('serial_number','request_code');
```

---

## Step 3 — Groups, content, accounts · **[you]**

In the admin portal, in this order:

1. **المجموعات** — create your class groups and grant each one its categories or
   subcategories.
2. **الطلاب** — assign existing students to groups. Until you do, they see an
   empty app.
3. **Publish real content** — at minimum one category containing a **video**
   lesson, a **PDF** lesson, and a **playlist**. Both the screenshots and the
   Play review depend on the app not looking empty.
4. **Create the reviewer account** exactly as in
   [`store/review-notes.md`](store/review-notes.md) §1: username `reviewer`, in a
   group with real content. Google's "App access" section is mandatory because
   sign-in is required, and an empty catalogue is the most common rejection for
   this kind of app.
5. *(optional)* Create the **guest** account and publish a post under «محتوى
   الضيف». Not needed for v1 — the current build has no guest credentials
   compiled in, so the guest button is hidden. Ship it in v1.1 if you want it.

---

## Step 4 — Screenshots · **[either]**

Play needs **2 minimum, 8 maximum**; upload 6. Shot list and rules are in
[`store/screenshots.md`](store/screenshots.md).

Two routes:

- **A real Android phone** — best results, and the app is already installable
  from the release AAB via `bundletool`, or just `flutter run --release`.
- **The emulator on this machine** — one AVD exists, `Pixel_2_API_26`
  (1080×1920, a valid Play size). API 26 is old but above the app's minSdk 24.
  Worth checking the WebView and PDF surfaces render before relying on it; a
  newer system image would be a safer capture device.

Either way this is blocked until step 3 gives the app something to display. Hand
it back to Claude once content exists and it can drive the emulator and capture.

---

## Step 5 — Build the upload artifact · **[done]**

Built and verified at `app/build/app/outputs/bundle/release/app-release.aab`:

| | |
| --- | --- |
| Size | 58.5 MB |
| Package | `com.teachercms.student` |
| Signing | release-signed (`META-INF` RSA block present) |
| Credentials | production Supabase host compiled into all three ABIs |
| Guest button | hidden — no guest defines, as intended for v1 |

To rebuild after any change:

```bash
cd app
flutter build appbundle --release --dart-define-from-file=dart_define.json
```

> A build with **empty** dart-defines is not a valid test of the real thing. It
> comes out ~7 MB smaller because `SupabaseConfig.isConfigured` becomes a
> compile-time `false`, letting Dart tree-shake the entire signed-in half of the
> app. Always build with the defines file before uploading, and treat a
> surprisingly small AAB as a symptom.

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
   - Privacy policy → the URL from step 1
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
the day the AAB is ready, and do the listing paperwork while it runs.

---

## Suggested order of work

| When | Do |
| --- | --- |
| **First** | **Step 0 — find out what happened to the Supabase project.** Steps 2–6 all wait on it |
| Today, in parallel | Step 1 (deploy the legal pages) — static, unaffected by the backend |
| Today, in parallel | Step 7 (check the testing requirement) — needs no backend, and sets the whole timeline |
| Now | Step 1 (deploy legal pages) — 10 minutes, unblocks the console |
| Next, quiet hours | Step 2 → Step 3 together, without a gap |
| Then | Step 4 screenshots, Step 5 rebuild |
| Then | Step 6 console, closed test if required |
| Before submitting | The pre-submission checklist in [`RELEASE.md`](RELEASE.md) §9 |
