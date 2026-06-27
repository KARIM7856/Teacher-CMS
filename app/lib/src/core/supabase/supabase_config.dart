/// Supabase credentials, supplied at build/run time via `--dart-define` (or
/// `--dart-define-from-file=dart_define.json`). Keeping them out of source
/// means no secrets are committed. See dart_define.example.json.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
