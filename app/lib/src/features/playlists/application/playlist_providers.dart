import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../models/playlist.dart';
import '../../../models/playlist_detail.dart';
import '../../history/application/history_providers.dart';
import '../data/playlist_repository.dart';

final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  return PlaylistRepository(ref.watch(supabaseClientProvider));
});

final playlistsProvider = FutureProvider<List<Playlist>>((ref) {
  return ref.watch(playlistRepositoryProvider).fetchPublishedPlaylists();
});

final playlistDetailProvider =
    FutureProvider.autoDispose.family<PlaylistDetail, String>((ref, playlistId) {
  return ref.watch(playlistRepositoryProvider).fetchPlaylistDetail(playlistId);
});

/// For each post in a playlist, the student's saved progress (presence = viewed).
/// Kept separate from the playlist detail so it can be refreshed on its own
/// after the student returns from a post.
final playlistProgressProvider =
    FutureProvider.autoDispose.family<Map<String, int>, String>((ref, playlistId) async {
  final detail = await ref.watch(playlistDetailProvider(playlistId).future);
  final List<String> postIds = detail.posts.map((post) => post.id).toList();
  return ref.watch(viewHistoryRepositoryProvider).fetchProgressForPosts(postIds);
});
