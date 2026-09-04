# Apple App Store — listing copy and App Store Connect answers

Everything App Store Connect asks for. Copy the Arabic blocks verbatim; the
answers below them match what the code actually does.

> Store requirements change. Where this file states a limit or a rule, treat App
> Store Connect and the current App Review Guidelines as authoritative.

---

## App information

- **Bundle ID:** `com.teachercms.student` — permanent, must match the Xcode
  project (it already does) and the App ID you register in the Developer portal.
- **SKU:** `teachercms-student-001` (internal only, never shown)
- **Primary language:** Arabic
- **Primary category:** Education · **Secondary:** none
- **Content rights:** the app displays third-party-hosted content (the teacher's
  own videos on YouTube / Google Drive). Answer **Yes** to "contains, shows, or
  accesses third-party content" and confirm you hold the rights — the teacher
  authored the material.

---

## Localised listing (Arabic)

**Name** (max 30 characters)

```
منصة المعلّم
```

**Subtitle** (max 30 characters)

```
دروس معلّمك في مكان واحد
```

**Promotional text** (max 170 characters — editable without a new build)

```
دروس معلّمك مرتّبة: فيديو وملفات PDF وقوائم تشغيل، مع حفظ موضع توقّفك في كل درس.
مجاني بالكامل، بلا إعلانات.
```

**Keywords** (max 100 characters total, comma-separated, no spaces after commas)

```
تعليم,دروس,شرح,مذاكرة,منهج,مدرس,طالب,فيديو,ملفات,قوائم,تعلم
```

**Description** (max 4000 characters)

```
منصة المعلّم تطبيق تعليمي مجاني يجمع دروس معلّمك في مكان واحد ومرتّب.

يدخل الطالب باسم مستخدم وكلمة مرور يسلّمهما له معلّمه، فيجد أمامه المحتوى الذي
خُصّص لمجموعته الدراسية فقط.

ماذا يقدّم التطبيق؟

• دروس مرتّبة حسب الأقسام والأقسام الفرعية، مع وسوم تساعدك على الوصول السريع.
• فيديو يعمل داخل التطبيق، وملفات PDF تُقرأ دون تنزيل، ومرفقات إضافية للدرس.
• «تابِع ما بدأته»: يحفظ التطبيق موضع توقّفك في الفيديو ويعيدك إليه في المرة
  التالية.
• قوائم تشغيل مرتّبة تنتقل بك من درس إلى الذي يليه تلقائيًا.
• إنجازات تحتفل بمواظبتك: أول درس، خمسة دروس، سلسلة أيام متتالية، وإكمال قائمة
  تشغيل كاملة.
• واجهة عربية بالكامل ومصمّمة من اليمين إلى اليسار، بخطّ واضح مريح للقراءة
  الطويلة.

مجاني بالكامل: لا اشتراكات، ولا مشتريات داخل التطبيق، ولا إعلانات.

خصوصيتك: لا نعرض إعلانات ولا نتتبّعك ولا نستخدم أدوات تحليلات خارجية، ولا نبيع
بياناتك. نجمع فقط ما يلزم لتشغيل حسابك وحفظ تقدّمك.

كيف أحصل على حساب؟ الحسابات ينشئها المعلّم؛ لا يوجد تسجيل ذاتي داخل التطبيق.
اطلب من معلّمك اسم مستخدم وكلمة مرور، أو استخدم زر «الدخول كضيف» للاطّلاع على
المحتوى العام.

الدعم: k.massoud703@gmail.com
```

**Support URL** (required)
`https://teacher-cms-admin.vercel.app/legal/`

**Marketing URL** (optional)
`https://teacher-cms-admin.vercel.app/legal/`

**Privacy Policy URL** (required)
`https://teacher-cms-admin.vercel.app/legal/privacy.html`

**Licence agreement:** either accept Apple's standard EULA, or paste the custom
terms at `https://teacher-cms-admin.vercel.app/legal/terms.html`. Those terms
already contain Apple's required minimum clauses (section 11).

**App icon:** taken from the build (`Icon-App-1024x1024@1x.png`, no alpha
channel — an alpha channel fails validation). A standalone copy for reference is
at `store/assets/appstore-icon-1024.png`.

---

## Age rating questionnaire

All content questions: **None**. Two that routinely trip people up:

| Question | Answer | Why |
| --- | --- | --- |
| Unrestricted web access | **No** | The in-app WebView only loads the specific YouTube/Drive embed the teacher attached. Ordinary links open in the system browser, which is not in-app web access. |
| User-generated content / user interaction | **No** | Students only read. Nothing they do is visible to another student. |
| In-app purchases, gambling, contests | No | The app is free with no purchases. |

Expected result: **4+**.

> The app is *intended* for students aged 13+, but Apple's rating reflects
> content, not audience, and the content is suitable for all ages. Do **not**
> enrol the app in the Kids Category — that brings stricter rules (no external
> links, no third-party analytics, parental gates) that this app is not built
> for.

---

## App Privacy (the nutrition label)

Answer "Yes, we collect data", then declare exactly:

| Category | Data type | Linked to user | Used for tracking | Purpose |
| --- | --- | --- | --- | --- |
| Contact Info | Name | Yes | No | App Functionality |
| Identifiers | User ID | Yes | No | App Functionality |
| Usage Data | Product Interaction | Yes | No | App Functionality |

Everything else: **not collected** — no location, contacts, photos, health,
financial info, browsing history, search history, device IDs, diagnostics, or
crash data. **Tracking: No** (no ATT prompt is needed; the app links no data to
third-party data for advertising).

This must stay consistent with `app/ios/Runner/PrivacyInfo.xcprivacy`, which
declares the same three types plus the `UserDefaults` required-reason API
(`CA92.1`, used to persist the sign-in session).

---

## App Review Information

- **Sign-in required:** Yes. Supply the reviewer account from
  [review-notes.md](review-notes.md) — a real student account in a group with
  real content, *not* the guest account, so the reviewer sees a populated app.
- **Notes:** paste the whole "Notes for the reviewer" block from that file. It
  pre-empts the two likely questions: why there is no sign-up, and where account
  deletion is.
- **Contact:** your name, phone, and k.massoud703@gmail.com.

### Guideline points this app touches

| Guideline | Status |
| --- | --- |
| 2.1 — app completeness, demo account | Reviewer account supplied; guest button also works |
| 4.8 — Sign in with Apple | **Not required.** The app uses only first-party username/password sign-in, no third-party social login |
| 5.1.1(v) — account deletion | The app offers no account *creation*, so in-app deletion is not mandated. A deletion path is provided anyway: حسابي → حذف الحساب, plus a public page |
| 5.1.2 — data use | No tracking, no data sharing; nutrition labels above |
| 3.1.1 — in-app purchase | No purchases of any kind |
| 1.2 / 1.4 — user-generated content | None; students cannot post |

---

## Export compliance

`ITSAppUsesNonExemptEncryption` is already set to `false` in `Info.plist`, so App
Store Connect will not ask on every upload. That is accurate: the app uses only
the OS-provided HTTPS/TLS stack.

---

## Devices

The Xcode target builds for iPhone **and** iPad (Flutter's default). That means
App Store Connect requires **iPad 13-inch screenshots as well as iPhone 6.9-inch
ones** — see [screenshots.md](screenshots.md). If you would rather ship
iPhone-only for the first release, set `TARGETED_DEVICE_FAMILY = 1` in the Runner
target's build settings before archiving; the iPad screenshot requirement then
disappears.
