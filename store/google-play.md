# Google Play — listing copy and console answers

Everything the Play Console asks for, answered for this app. Copy the Arabic
blocks verbatim; the answers below them are the ones that match what the code
actually does — don't guess at them in the console, an inaccurate Data safety
form is a policy violation.

> Store requirements change. Where this file states a limit or a rule, treat the
> console as authoritative and re-check before you submit.

---

## Store listing

**Default language:** العربية (ar) — the app has no other UI language.

**App name** (max 30 characters)

```
منصة المعلّم
```

**Short description** (max 80 characters)

```
دروس معلّمك في مكان واحد: فيديو وملفات، وتُكمل من حيث توقّفت.
```

**Full description** (max 4000 characters)

```
منصة المعلّم تطبيق تعليمي مجاني يجمع دروس معلّمك في مكان واحد ومرتّب.

يدخل الطالب باسم مستخدم وكلمة مرور يسلّمهما له معلّمه، فيجد أمامه المحتوى الذي
خُصّص لمجموعته الدراسية فقط.

■ ماذا يقدّم التطبيق؟

• دروس مرتّبة حسب الأقسام والأقسام الفرعية، مع وسوم تساعدك على الوصول السريع.
• فيديو يعمل داخل التطبيق، وملفات PDF تُقرأ دون تنزيل، ومرفقات إضافية للدرس.
• «تابِع ما بدأته»: يحفظ التطبيق موضع توقّفك في الفيديو ويعيدك إليه في المرة
  التالية.
• قوائم تشغيل مرتّبة تنتقل بك من درس إلى الذي يليه تلقائيًا.
• إنجازات تحتفل بمواظبتك: أول درس، خمسة دروس، سلسلة أيام متتالية، وإكمال قائمة
  تشغيل كاملة.
• واجهة عربية بالكامل ومصمّمة من اليمين إلى اليسار، بخطّ واضح مريح للقراءة
  الطويلة.

■ مجاني بالكامل

لا اشتراكات، ولا مشتريات داخل التطبيق، ولا إعلانات على الإطلاق.

■ خصوصيتك

لا نعرض إعلانات ولا نتتبّعك ولا نستخدم أدوات تحليلات خارجية، ولا نبيع بياناتك.
نجمع فقط ما يلزم لتشغيل حسابك وحفظ تقدّمك في الدروس. التفاصيل الكاملة في سياسة
الخصوصية.

■ كيف أحصل على حساب؟

الحسابات ينشئها المعلّم؛ لا يوجد تسجيل ذاتي داخل التطبيق. اطلب من معلّمك اسم
مستخدم وكلمة مرور. وإن أردت الاطّلاع أولًا، استخدم زر «الدخول كضيف» لعرض المحتوى
العام.

■ الدعم

لأي سؤال أو مشكلة: k.massoud703@gmail.com
```

**App icon:** `store/assets/play-icon-512.png` (512×512, 32-bit PNG)
**Feature graphic:** `store/assets/play-feature-graphic-1024x500.png` (1024×500)
**Screenshots:** see [screenshots.md](screenshots.md)

**Category:** Education
**Tags:** Education › Study tools, Video
**Contact email:** k.massoud703@gmail.com
**Website (optional):** https://teacher-cms-admin.vercel.app/legal/
**Privacy policy:** https://teacher-cms-admin.vercel.app/legal/privacy.html

---

## App content declarations

Play Console → **Policy → App content**. Each answer below is what the code does.

### Privacy policy
`https://teacher-cms-admin.vercel.app/legal/privacy.html`

### Ads
**No**, the app contains no ads. There is no ads SDK, and no advertising ID is
requested.

### App access
**All or some functionality is restricted.** Sign-in is required, so you must
give Play a working account or the review will fail. Add one instruction set:

- Name: `Student sign-in`
- Username / password: the reviewer account from [review-notes.md](review-notes.md)
- Instructions: paste the "How to sign in" block from that file.

### Content rating (IARC questionnaire)
Category: **Reference, News, or Educational**. Expected answers:

| Question | Answer |
| --- | --- |
| Violence, sexual content, profanity, drugs, gambling | No to all |
| Does the app let users interact or exchange content? | **No** — students only read; nothing is user-generated |
| Does the app share the user's location? | No |
| Does the app allow purchases? | No |
| Does the app contain unrestricted internet browsing? | **No** — only the teacher's own embedded media plays; other links open in the device browser |

Expected outcome: **Everyone / PEGI 3** or equivalent.

### Target audience and content
- **Target age groups:** 13–15, 16–17, 18+ (this app is for students aged 13+).
- **Is your app designed for children?** No.
- Because no age band under 13 is selected, the **Families Policy does not
  apply** and no Families-specific declarations are required. If you later
  enrol pupils under 13, this answer must change and the privacy policy needs
  COPPA/parental-consent sections added.

### Data safety
Declare exactly this — it matches the schema and the app's queries:

| Data type | Collected | Shared | Optional? | Purpose |
| --- | --- | --- | --- | --- |
| Personal info → **Name** | Yes | No | Required | App functionality, Account management |
| Personal info → **User IDs** (username) | Yes | No | Required | App functionality, Account management |
| App activity → **App interactions** (lessons opened, progress, achievements) | Yes | No | Required | App functionality |

Everything else: **not collected**. Specifically no location, no contacts, no
photos/videos taken from the device, no files from the device, no financial
info, no health data, no device or advertising IDs, no crash logs or diagnostics
(the app bundles no analytics or crash SDK).

Security section:

- **Is all user data encrypted in transit?** Yes (HTTPS/TLS throughout).
- **Do you provide a way for users to request data deletion?** Yes —
  `https://teacher-cms-admin.vercel.app/legal/delete-account.html`
- **Data collection is required**, not optional: the app is account-based.
- Independent security review: No.

> Phone numbers appear in the teacher's import spreadsheet but are **not** stored
> in the database (migration `…000700` adds only `serial_number` and
> `request_code`), so they are not declared here. If that ever changes, add
> Personal info → Phone number.

### Government apps / Financial features / Health / News
No to all.

### Advertising ID
**No**, the app does not use an advertising ID.

---

## Release setup

- **App bundle**, not an APK: `app/build/app/outputs/bundle/release/app-release.aab`
- **Play App Signing:** enabled (the default). Your upload key is
  `keystores/teacher-cms-upload.jks` — see [../RELEASE.md](../RELEASE.md) for the
  backup warning.
- **Package name:** `com.teachercms.student` — permanent, cannot be changed after
  the first upload.
- **Countries:** select wherever your students are.
- **Pricing:** Free. (Free → paid is not possible later; paid → free is.)

### Closed testing requirement for new personal accounts
Google requires personal developer accounts created from late 2023 onward to run
a **closed test with at least 12 testers, opted in continuously for 14 days**,
before production access is granted. Plan for that: create a closed track, add
12+ real testers (students or colleagues), and let it run for two full weeks
before expecting a production release. Organisation accounts are exempt. Check
the console — this requirement has been revised more than once.
