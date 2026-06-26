import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/view_history_entry.dart';

/// Reads and writes the student's `view_history` — the backbone of both
/// "continue where you left off" and resuming video playback.
///
/// Phase 4 uses only [fetchContinueLearning]; the write paths are added in the
/// latest-viewed-tracking phase.
class ViewHistoryRepository {
  ViewHistoryRepository(this._client);

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  /// The student's most recently viewed posts, newest first. Returns an empty
  /// list when signed out or when nothing has been viewed yet.
  Future<List<ViewHistoryEntry>> fetchContinueLearning({int limit = 10}) async {
    final String? userId = _userId;
    if (userId == null) return const [];

    // `posts!inner` drops history rows whose post is no longer visible
    // (unpublished/removed) — students only ever see published content.
    final List<Map<String, dynamic>> rows = await _client
        .from('view_history')
        .select('progress_seconds, last_viewed_at, posts!inner(*)')
        .eq('student_id', userId)
        .eq('posts.published', true)
        .order('last_viewed_at', ascending: false)
        .limit(limit);

    return rows.map(ViewHistoryEntry.fromMap).toList();
  }
}
