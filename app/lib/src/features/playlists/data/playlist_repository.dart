import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/playlist.dart';
import '../../../models/playlist_detail.dart';
import '../../../models/post.dart';

/// Read access to published playlists and their ordered posts.
class PlaylistRepository {
  PlaylistRepository(this._client);

  final SupabaseClient _client;

  Future<List<Playlist>> fetchPublishedPlaylists() async {
    final List<Map<String, dynamic>> rows = await _client
        .from('playlists')
        .select()
        .eq('published', true)
        .order('created_at', ascending: false);
    return rows.map(Playlist.fromMap).toList();
  }

  /// A playlist with its published posts in playback order.
  Future<PlaylistDetail> fetchPlaylistDetail(String playlistId) async {
    final Map<String, dynamic>? playlistRow = await _client
        .from('playlists')
        .select()
        .eq('id', playlistId)
        .eq('published', true)
        .maybeSingle();
    if (playlistRow == null) {
      throw StateError('Playlist not found or not published: $playlistId');
    }

    final List<Map<String, dynamic>> itemRows = await _client
        .from('playlist_items')
        .select('position, posts!inner(*)')
        .eq('playlist_id', playlistId)
        .eq('posts.published', true)
        .order('position');

    final List<Post> posts = itemRows
        .map((row) => row['posts'])
        .whereType<Map<String, dynamic>>()
        .map(Post.fromMap)
        .toList();

    return PlaylistDetail(playlist: Playlist.fromMap(playlistRow), posts: posts);
  }
}
