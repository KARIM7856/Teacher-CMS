import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/application/auth_providers.dart';
import '../application/profile_providers.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final profileAsync = ref.watch(currentProfileProvider);
    final String email =
        ref.watch(supabaseClientProvider).auth.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Center(
            child: CircleAvatar(
              radius: 44,
              child: Icon(Icons.person_rounded, size: 44),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          profileAsync.when(
            data: (profile) => Text(
              profile?.displayName ?? 'طالب',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Text(
              'طالب',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            email,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }
}
