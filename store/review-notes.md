# Reviewer access and notes

Both stores review the app while signed in. Sign-in is mandatory in this app and
there is no sign-up, so a review **will** fail unless you hand them a working
account. Prepare this before your first submission.

---

## 1. Create a dedicated reviewer account

In the admin portal → **الطلاب** → «طالب جديد»:

| Field | Value |
| --- | --- |
| اسم المستخدم | `reviewer` |
| كلمة المرور | pick one, at least 8 characters, and record it here in your private copy |
| الاسم | `App Review` |
| المجموعات | a group that grants **real, populated categories** |

Why not the guest account: the guest group grants only the small «محتوى الضيف»
category. A reviewer who signs in there sees a nearly empty app and can reject it
for incomplete functionality (Apple 2.1). Give them a group with actual lessons —
ideally one containing a video post, a PDF post, and a playlist, so every feature
is reachable.

Keep the account enabled and the password unchanged until the review passes. Set
a calendar note to disable it once the app is live, and re-enable for each update
review.

---

## 2. How to sign in (paste into both consoles)

```
Sign-in is required. There is no sign-up inside the app: this is a
teacher-administered platform, and the teacher creates every student account
from a separate web portal. Students sign in with a USERNAME, not an email.

Username: reviewer
Password: <the password you set>

1. Launch the app. The sign-in screen appears.
2. Enter the username and password above and tap "تسجيل الدخول".
3. You land on the Home tab with recent lessons.

Alternatively, tap "الدخول كضيف" (sign in as guest) on the sign-in screen for
a no-credentials look at the public content. Note the guest account sees only a
small public category; use the reviewer account above to see the full app.

The interface is entirely in Arabic and lays out right-to-left, which is
intentional — the app serves Arabic-speaking students.
```

---

## 3. Notes for the reviewer (paste into App Review Information)

```
About this app

"منصة المعلّم" (Manassat Al-Mu'allim) is a free educational app. One teacher
publishes lessons — text, video, PDFs, playlists — and their students read
them. There are no purchases, no ads, no analytics SDKs, and no user-generated
content: students can only read what the teacher published.

Why there is no sign-up
Accounts are created by the teacher in a separate web admin portal and handed to
students in class. The app therefore deliberately offers sign-in only. Public
sign-up is disabled at the authentication provider as well, so a sign-up screen
would be non-functional.

Account deletion
Because the app offers no account creation, in-app deletion is not required, but
a path is provided regardless:
  حسابي (Profile tab) → حذف الحساب
It explains both routes — ask the teacher, or email a request — and opens a
pre-filled request email. The same information is public at
https://teacher-cms-admin.vercel.app/legal/delete-account.html

Third-party media
Some lessons embed video the teacher hosts on YouTube or Google Drive. These
play through the official embedded players. All other links open in the system
browser; the app contains no general-purpose web browser.

Guest access
"الدخول كضيف" signs in to a shared demo account with a small amount of public
content. It is not tied to any person.

Contact: k.massoud703@gmail.com
```

---

## 4. Before you submit — verify the account actually works

1. Build a release app with the real Supabase credentials.
2. Sign in as `reviewer` on a physical device.
3. Confirm: the Home tab lists lessons; opening a lesson shows body + media; a
   video plays; the Playlists tab is populated; حسابي → حذف الحساب opens.
4. Sign out, then sign in again — session persistence works.

If the reviewer account shows an empty catalogue, its group has no grants yet.
Fix it in المجموعات before submitting; an empty app is the single most common
cause of rejection for this kind of listing.
