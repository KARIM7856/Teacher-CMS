import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../models/view_history_entry.dart';
import '../data/view_history_repository.dart';

final viewHistoryRepositoryProvider = Provider<ViewHistoryRepository>((ref) {
  return ViewHistoryRepository(ref.watch(supabaseClientProvider));
});

/// The "continue where you left off" list for the Home tab. Empty until the
/// student starts opening posts (latest-viewed tracking lands in the next phase).
final continueLearningProvider =
    FutureProvider<List<ViewHistoryEntry>>((ref) {
  return ref.watch(viewHistoryRepositoryProvider).fetchContinueLearning();
});
