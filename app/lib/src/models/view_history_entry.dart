import 'post.dart';

/// One "continue where you left off" entry: a post the student has opened,
/// with how far they got. Mirrors a `public.view_history` row joined to its post.
class ViewHistoryEntry {
  const ViewHistoryEntry({
    required this.post,
    required this.progressSeconds,
    required this.lastViewedAt,
  });

  final Post post;

  /// Last saved playback position for video posts, in seconds (0 otherwise).
  final int progressSeconds;
  final DateTime lastViewedAt;

  factory ViewHistoryEntry.fromMap(Map<String, dynamic> map) {
    final DateTime? viewedAt =
        DateTime.tryParse(map['last_viewed_at'] as String? ?? '');
    return ViewHistoryEntry(
      post: Post.fromMap(map['posts'] as Map<String, dynamic>),
      progressSeconds: (map['progress_seconds'] as int?) ?? 0,
      lastViewedAt: viewedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
