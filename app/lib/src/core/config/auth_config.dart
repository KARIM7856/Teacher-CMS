/// Students sign in with a *username*, not an email. There is no sign-up in the
/// app — the teacher creates every account from the admin portal.
///
/// Supabase Auth is email-based, so each username maps to a deterministic
/// synthetic email `<username>@<kStudentEmailDomain>`. No mail is ever sent to it
/// (admin-created accounts are pre-confirmed); the domain is just a stable suffix.
///
/// This MUST stay identical to STUDENT_EMAIL_DOMAIN used by the admin serverless
/// function (admin/api/students.ts). If they diverge, logins silently fail.
const String kStudentEmailDomain = 'students.teachercms.app';

/// Builds the Supabase login email for a student username.
String studentEmailForUsername(String username) =>
    '${username.trim().toLowerCase()}@$kStudentEmailDomain';

/// Credentials for the shared "guest" student account, injected at build time
/// via `--dart-define` (like the Supabase keys). The guest is an ordinary
/// student whose single group grants only the "guest" category, so tapping
/// "الدخول كضيف" drops a visitor straight into that public content.
///
/// These MUST match the guest student account the teacher created in the admin
/// portal (username + password). When either is empty the guest button hides
/// itself, so a build without these defines simply has no guest entry point.
const String kGuestUsername = String.fromEnvironment('GUEST_USERNAME');
const String kGuestPassword = String.fromEnvironment('GUEST_PASSWORD');

/// Whether the guest-login button should be shown (both credentials provided).
bool get isGuestLoginEnabled =>
    kGuestUsername.isNotEmpty && kGuestPassword.isNotEmpty;
