import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/view_history_entry.dart';

/// Reads and writes the student's `view_history` — the backbone of both
/// "continue where you left off" and resuming video playback.
class ViewHistoryRepository {
  ViewHistoryRepository(this._client);

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  /// The "continue where you left off" list, newest first: posts the student
  /// has started (opened) but not yet marked seen. Opening a post adds it here;
  /// marking it seen drops it. Returns an empty list when signed out or when
  /// nothing is in progress.
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
        .eq('seen', false)
        .order('last_viewed_at', ascending: false)
        .limit(limit);

    return rows.map(ViewHistoryEntry.fromMap).toList();
  }

  /// Records that the student opened ("started") a post — a row's existence is
  /// what marks it started. Idempotent, and preserves any existing `seen` flag
  /// and resume progress. Keeps the post in "continue" until it's marked seen.
  Future<void> markStarted(String postId) async {
    final String? userId = _userId;
    if (userId == null) return;
    await _client.from('view_history').upsert(
      {'student_id': userId, 'post_id': postId},
      onConflict: 'student_id,post_id',
    );
  }

  /// Marks a post as seen — the student's explicit "I've seen this" action.
  /// Sets the `seen` flag, creating the row if needed; any saved resume progress
  /// is preserved (we don't send that column here). The `view_history_touch`
  /// trigger bumps `last_viewed_at`.
  Future<void> markSeen(String postId) async {
    final String? userId = _userId;
    if (userId == null) return;
    await _client.from('view_history').upsert(
      {'student_id': userId, 'post_id': postId, 'seen': true},
      onConflict: 'student_id,post_id',
    );
  }

  /// Un-marks a post as seen. The row (and its resume progress) is kept — only
  /// the flag is cleared.
  Future<void> unmarkSeen(String postId) async {
    final String? userId = _userId;
    if (userId == null) return;
    await _client
        .from('view_history')
        .update({'seen': false})
        .eq('student_id', userId)
        .eq('post_id', postId);
  }

  /// Saves the current playback position (called on a throttle). Independent of
  /// `seen`: it upserts the row so resume is remembered whether or not the
  /// student has marked the post seen.
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

  /// Whether a post is marked seen, and its saved resume position, in one read.
  Future<({bool seen, int progressSeconds})> viewStateForPost(
      String postId) async {
    final String? userId = _userId;
    if (userId == null) return (seen: false, progressSeconds: 0);
    final Map<String, dynamic>? row = await _client
        .from('view_history')
        .select('progress_seconds, seen')
        .eq('student_id', userId)
        .eq('post_id', postId)
        .maybeSingle();
    return (
      seen: (row?['seen'] as bool?) ?? false,
      progressSeconds: (row?['progress_seconds'] as int?) ?? 0,
    );
  }

  /// For each of [postIds] the student has a history row, its seen flag and
  /// saved resume position. Used to show per-post status across a playlist.
  Future<Map<String, ({bool seen, int progressSeconds})>> fetchProgressForPosts(
      List<String> postIds) async {
    final String? userId = _userId;
    if (userId == null || postIds.isEmpty) return const {};
    final List<Map<String, dynamic>> rows = await _client
        .from('view_history')
        .select('post_id, progress_seconds, seen')
        .eq('student_id', userId)
        .inFilter('post_id', postIds);
    return {
      for (final row in rows)
        row['post_id'] as String: (
          seen: (row['seen'] as bool?) ?? false,
          progressSeconds: (row['progress_seconds'] as int?) ?? 0,
        ),
    };
  }
}
