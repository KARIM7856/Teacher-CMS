import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_info.dart';
import '../../../core/config/auth_config.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/external_link.dart';
import '../../achievements/presentation/achievements_screen.dart';
import '../../auth/application/auth_providers.dart';
import '../application/profile_providers.dart';
import 'account_deletion_screen.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final profileAsync = ref.watch(currentProfileProvider);
    // Students sign in with a username; the address on the account is a
    // synthetic one nobody can write to (see kStudentEmailDomain), so showing it
    // in full would only confuse. Show the username part alone.
    final String? username = usernameFromStudentEmail(
      ref.watch(supabaseClientProvider).auth.currentUser?.email,
    );

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
          if (username != null)
            Text(
              'اسم المستخدم: $username',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
            ),
          const SizedBox(height: AppSpacing.xl),
          _MenuCard(
            children: [
              ListTile(
                leading: const Icon(Icons.emoji_events_rounded),
                title: const Text('إنجازاتي'),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () =>
                    Navigator.of(context).push(AchievementsScreen.route()),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Both stores expect the privacy policy and a data-deletion route to
          // be reachable from inside the app, not only from the store listing.
          _MenuCard(
            children: [
              ListTile(
                leading: const Icon(Icons.help_outline_rounded),
                title: const Text('المساعدة والدعم'),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () => openExternalUrl(context, AppInfo.supportUrl),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('سياسة الخصوصية'),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () =>
                    openExternalUrl(context, AppInfo.privacyPolicyUrl),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('شروط الاستخدام'),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () => openExternalUrl(context, AppInfo.termsUrl),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.person_remove_outlined,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  'حذف الحساب',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => Navigator.of(context).push(
                  AccountDeletionScreen.route(username: username),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('تسجيل الخروج'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '${AppInfo.appName} · الإصدار ${AppInfo.version}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// A rounded card holding a group of [ListTile]s, clipped so the ripple of the
/// first and last rows follows the corner radius.
class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(children: children),
    );
  }
}
