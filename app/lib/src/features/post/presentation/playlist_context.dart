import '../../../models/post.dart';

/// Carried into the post detail screen when a post is opened as part of a
/// playlist, so the screen can show "lesson X of N" and advance to the next.
class PlaylistContext {
  const PlaylistContext({
    required this.playlistId,
    required this.posts,
    required this.index,
  });

  final String playlistId;
  final List<Post> posts;
  final int index;

  int get position => index + 1;
  int get total => posts.length;
  bool get hasNext => index < posts.length - 1;
  Post? get nextPost => hasNext ? posts[index + 1] : null;

  PlaylistContext advanced() =>
      PlaylistContext(playlistId: playlistId, posts: posts, index: index + 1);
}
