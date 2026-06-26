import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper over Supabase Auth. Session persistence is handled by
/// supabase_flutter (a returning user is restored automatically on launch).
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: (displayName == null || displayName.isEmpty)
          ? null
          : {'display_name': displayName},
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}
