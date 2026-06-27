import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/celebration_data.dart';
import 'achievements_providers.dart';

/// A FIFO queue of achievements waiting to be celebrated. The celebration
/// overlay shows the first item; [dismissCurrent] advances to the next.
///
/// Triggering a celebration from anywhere is one call — `claim()` — so adding
/// new achievements never touches the overlay.
class CelebrationController extends Notifier<List<CelebrationData>> {
  @override
  List<CelebrationData> build() => const [];

  /// Evaluate achievements server-side; enqueue anything newly unlocked.
  Future<void> claim() async {
    final List<CelebrationData> unlocked =
        await ref.read(achievementsRepositoryProvider).claim();
    if (unlocked.isEmpty) return;
    state = [...state, ...unlocked];
    ref.invalidate(achievementsListProvider);
  }

  void dismissCurrent() {
    if (state.isNotEmpty) state = state.sublist(1);
  }
}

final celebrationControllerProvider =
    NotifierProvider<CelebrationController, List<CelebrationData>>(
  CelebrationController.new,
);
