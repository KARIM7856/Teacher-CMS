import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps an auth failure to an Arabic, user-friendly message.
String authErrorMessage(Object? error) {
  if (error is AuthException) return error.message;
  return 'تعذّر إتمام العملية. حاول مرة أخرى.';
}
