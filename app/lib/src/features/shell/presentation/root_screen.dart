import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/presentation/welcome_screen.dart';
import 'home_shell.dart';

/// Top-level router: shows the auth flow or the signed-in shell based on the
/// current session. Session restore happens before the first frame, so a
/// returning user lands straight in [HomeShell].
class RootScreen extends ConsumerWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!SupabaseConfig.isConfigured) return const _NotConfiguredScreen();

    final AsyncValue<Object?> auth = ref.watch(authStateProvider);
    return auth.when(
      data: (session) =>
          session == null ? const WelcomeScreen() : const HomeShell(),
      loading: () => const _SplashScreen(),
      error: (_, __) => const WelcomeScreen(),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _NotConfiguredScreen extends StatelessWidget {
  const _NotConfiguredScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.settings_suggest_outlined, size: 48),
              SizedBox(height: AppSpacing.md),
              Text(
                'لم تُضبط بيانات Supabase.\n'
                'مرّر SUPABASE_URL و SUPABASE_ANON_KEY عبر '
                '--dart-define-from-file=dart_define.json',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
