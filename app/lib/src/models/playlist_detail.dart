import 'playlist.dart';
import 'post.dart';

/// A playlist together with its posts in playback order.
class PlaylistDetail {
  const PlaylistDetail({required this.playlist, required this.posts});

  final Playlist playlist;

  /// Posts ordered by `playlist_items.position`.
  final List<Post> posts;
}
