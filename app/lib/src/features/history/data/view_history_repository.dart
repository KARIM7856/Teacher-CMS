import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/view_history_entry.dart';

/// Reads and writes the student's `view_history` — the backbone of both
/// "continue where you left off" and resuming video playback.
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

  /// Records (or refreshes) that the student opened a post. The
  /// `view_history_touch` trigger bumps `last_viewed_at`; an existing saved
  /// progress is preserved (we don't send that column here).
  Future<void> recordView(String postId) async {
    final String? userId = _userId;
    if (userId == null) return;
    await _client.from('view_history').upsert(
      {'student_id': userId, 'post_id': postId},
      onConflict: 'student_id,post_id',
    );
  }

  /// Saves the current playback position for a post (called on a throttle).
  Future<void> saveProgress(String postId, int seconds) async {
    final String? userId = _userId;
    if (userId == null) return;
    await _client.from('view_history').upsert(
      {
        'student_id': userId,
        'post_id': postId,
        'progress_seconds': seconds < 0 ? 0 : seconds,
      },
      onConflict: 'student_id,post_id',
    );
  }

  /// The saved playback position for a post, in seconds (0 if none / signed out).
  Future<int> progressForPost(String postId) async {
    final String? userId = _userId;
    if (userId == null) return 0;
    final Map<String, dynamic>? row = await _client
        .from('view_history')
        .select('progress_seconds')
        .eq('student_id', userId)
        .eq('post_id', postId)
        .maybeSingle();
    return (row?['progress_seconds'] as int?) ?? 0;
  }

  /// Which of [postIds] the student has viewed, mapped to saved progress
  /// seconds. Used to show progress indicators across a playlist.
  Future<Map<String, int>> fetchProgressForPosts(List<String> postIds) async {
    final String? userId = _userId;
    if (userId == null || postIds.isEmpty) return const {};
    final List<Map<String, dynamic>> rows = await _client
        .from('view_history')
        .select('post_id, progress_seconds')
        .eq('student_id', userId)
        .inFilter('post_id', postIds);
    return {
      for (final row in rows)
        row['post_id'] as String: (row['progress_seconds'] as int?) ?? 0,
    };
  }
}
