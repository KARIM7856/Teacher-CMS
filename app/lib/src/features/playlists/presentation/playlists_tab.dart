import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/placeholder_view.dart';
import '../../../models/playlist.dart';
import '../application/playlist_providers.dart';
import 'playlist_detail_screen.dart';

/// The Playlists tab: published playlists curated by the teacher.
class PlaylistsTab extends ConsumerWidget {
  const PlaylistsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Playlist>> playlists = ref.watch(playlistsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('القوائم')),
      body: AsyncValueWidget<List<Playlist>>(
        value: playlists,
        onRetry: () => ref.invalidate(playlistsProvider),
        data: (items) {
          if (items.isEmpty) {
            return const PlaceholderView(
              icon: Icons.featured_play_list_outlined,
              title: 'لا توجد قوائم',
              message: 'ستظهر قوائم التشغيل هنا بمجرّد أن ينشرها معلّمك.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(playlistsProvider);
              await ref.read(playlistsProvider.future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: items.length,
              itemBuilder: (context, index) =>
                  _PlaylistCard(playlist: items[index]),
            ),
          );
        },
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          PlaylistDetailScreen.route(playlist.id, initialTitle: playlist.title),
        ),
        child: Row(
          children: [
            _PlaylistCover(coverImage: playlist.coverImage),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (playlist.description != null &&
                        playlist.description!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        playlist.description!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: Icon(Icons.chevron_left_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

/// The playlist's cover: a cached network image when available, otherwise a
/// friendly gradient tile so cards still read well.
class _PlaylistCover extends StatelessWidget {
  const _PlaylistCover({required this.coverImage});

  final String? coverImage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    const double size = 88;

    Widget fallback() => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
            ),
          ),
          child: const Icon(Icons.playlist_play_rounded,
              color: Colors.white, size: 36),
        );

    if (coverImage == null || coverImage!.isEmpty) return fallback();

    return CachedNetworkImage(
      imageUrl: coverImage!,
      width: size,
      height: size,
      fit: BoxFit.cover,
      placeholder: (_, __) => SizedBox(
        width: size,
        height: size,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (_, __, ___) => fallback(),
    );
  }
}
