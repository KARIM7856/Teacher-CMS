/// App identity, store-facing links, and support contact.
///
/// Both stores require a reachable privacy policy, and Google Play additionally
/// requires a public URL describing how to request account/data deletion. These
/// pages are served as static files from the admin portal's deployment
/// (`admin/public/legal/`), so they stay up independently of the React bundle.
///
/// If the admin portal ever moves to a custom domain, change [legalBaseUrl] here
/// and update the URLs in both store consoles to match — a privacy-policy link
/// that 404s is a rejection.
class AppInfo {
  AppInfo._();

  /// User-facing app name. Matches `CFBundleDisplayName` (iOS), the Android
  /// launcher label in `values/strings.xml`, and both store listings.
  static const String appName = 'منصة المعلّم';

  /// Marketing version. Must be kept in step with `version:` in pubspec.yaml,
  /// which is what actually stamps the build — this constant only feeds the
  /// "about" line in the profile screen.
  static const String version = '1.0.0';

  /// Where the legal pages live. Overridable at build time so a custom domain
  /// doesn't need a code change:
  /// `--dart-define=LEGAL_BASE_URL=https://example.com/legal`
  static const String legalBaseUrl = String.fromEnvironment(
    'LEGAL_BASE_URL',
    defaultValue: 'https://teacher-cms-admin.vercel.app/legal',
  );

  static const String privacyPolicyUrl = '$legalBaseUrl/privacy.html';
  static const String termsUrl = '$legalBaseUrl/terms.html';
  static const String accountDeletionUrl = '$legalBaseUrl/delete-account.html';
  static const String supportUrl = '$legalBaseUrl/';

  /// Support / privacy / deletion-request mailbox. Also the "support email" on
  /// both store listings, so it has to be a mailbox someone actually reads.
  static const String supportEmail = 'k.massoud703@gmail.com';
}
