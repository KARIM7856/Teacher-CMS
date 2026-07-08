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
