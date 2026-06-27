import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../models/achievement.dart';
import '../../auth/application/auth_providers.dart';
import '../data/achievements_repository.dart';

final achievementsRepositoryProvider = Provider<AchievementsRepository>((ref) {
  return AchievementsRepository(ref.watch(supabaseClientProvider));
});

/// An achievement paired with whether the current student has earned it.
class AchievementView {
  const AchievementView({
    required this.achievement,
    required this.earned,
    this.unlockedAt,
  });

  final Achievement achievement;
  final bool earned;
  final DateTime? unlockedAt;
}

/// All achievements, each marked earned/locked for the current student.
/// Refetched on auth changes and invalidated after a claim.
final achievementsListProvider =
    FutureProvider<List<AchievementView>>((ref) async {
  ref.watch(authStateProvider);
  final repo = ref.watch(achievementsRepositoryProvider);
  final all = await repo.fetchAchievements();
  final unlocked = await repo.fetchUnlocked();
  return all
      .map((achievement) => AchievementView(
            achievement: achievement,
            earned: unlocked.containsKey(achievement.id),
            unlockedAt: unlocked[achievement.id],
          ))
      .toList();
});
