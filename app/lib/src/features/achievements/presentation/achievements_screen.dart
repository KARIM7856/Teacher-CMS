import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/motion.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/placeholder_view.dart';
import '../application/achievements_providers.dart';
import 'widgets/achievement_badge.dart';

/// The student's badges: earned (colorful, with a gentle pop-in) and locked
/// (muted). Reached from the Profile tab.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const AchievementsScreen());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(achievementsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('إنجازاتي')),
      body: AsyncValueWidget<List<AchievementView>>(
        value: achievements,
        onRetry: () => ref.invalidate(achievementsListProvider),
        data: (items) {
          if (items.isEmpty) {
            return const PlaceholderView(
              icon: Icons.emoji_events_outlined,
              title: 'لا توجد إنجازات بعد',
              message: 'تابِع التعلّم لتفتح أول إنجازاتك!',
            );
          }
          final int earned = items.where((view) => view.earned).length;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(achievementsListProvider);
              await ref.read(achievementsListProvider.future);
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 0.78,
              ),
              itemCount: items.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _ProgressHeader(earned: earned, total: items.length);
                }
                return _AchievementTile(view: items[index - 1]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.earned, required this.total});

  final int earned;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_rounded,
                color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'فتحت $earned من $total',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.view});

  final AchievementView view;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool animate = view.earned && !prefersReducedMotion(context);

    final Widget content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AchievementBadge(
          iconName: view.achievement.icon,
          size: 84,
          earned: view.earned,
          glow: view.earned,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          view.achievement.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          view.earned ? 'مفتوح' : 'مقفل',
          style: theme.textTheme.bodySmall?.copyWith(
            color: view.earned
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    if (!animate) return content;

    // A tasteful pop-in for earned badges (skipped under reduce-motion).
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
      ),
      child: content,
    );
  }
}
