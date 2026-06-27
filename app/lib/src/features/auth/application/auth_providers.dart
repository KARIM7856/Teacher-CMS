import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

/// The current session, re-emitted on every auth change. The whole app routes
/// off this: `null` → auth flow, non-null → the signed-in shell.
final authStateProvider = StreamProvider<Session?>((ref) async* {
  final AuthRepository repo = ref.watch(authRepositoryProvider);
  yield repo.currentSession;
  yield* repo.onAuthStateChange.map((AuthState event) => event.session);
});

/// Drives the sign-in / sign-up / sign-out actions and exposes their
/// loading + error state to the UI via [AsyncValue].
class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signIn(email: email, password: password),
    );
    return !state.hasError;
  }

  Future<bool> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signUp(
            email: email,
            password: password,
            displayName: displayName,
          ),
    );
    return !state.hasError;
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).signOut());
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);
