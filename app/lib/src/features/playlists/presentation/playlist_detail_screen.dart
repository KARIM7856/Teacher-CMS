import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/placeholder_view.dart';
import '../../../models/playlist_detail.dart';
import '../../post/presentation/playlist_context.dart';
import '../../post/presentation/post_detail_screen.dart';
import '../application/playlist_providers.dart';

/// A playlist's posts in order, each with a progress indicator, plus a button
/// to start/continue sequential playback.
class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
    this.initialTitle,
  });

  final String playlistId;
  final String? initialTitle;

  static Route<void> route(String playlistId, {String? initialTitle}) {
    return MaterialPageRoute<void>(
      builder: (_) => PlaylistDetailScreen(
        playlistId: playlistId,
        initialTitle: initialTitle,
      ),
    );
  }

  Future<void> _openAt(
    BuildContext context,
    WidgetRef ref,
    PlaylistDetail detail,
    int index,
  ) async {
    final post = detail.posts[index];
    await Navigator.of(context).push(
      PostDetailScreen.route(
        post.id,
        initialTitle: post.title,
        playlistContext: PlaylistContext(
          playlistId: playlistId,
          posts: detail.posts,
          index: index,
        ),
      ),
    );
    // Refresh progress indicators after returning from a lesson.
    ref.invalidate(playlistProgressProvider(playlistId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PlaylistDetail> detail =
        ref.watch(playlistDetailProvider(playlistId));

    return Scaffold(
      appBar: AppBar(title: Text(initialTitle ?? 'قائمة التشغيل')),
      body: AsyncValueWidget<PlaylistDetail>(
        value: detail,
        onRetry: () => ref.invalidate(playlistDetailProvider(playlistId)),
        data: (data) {
          if (data.posts.isEmpty) {
            return const PlaceholderView(
              icon: Icons.playlist_remove_rounded,
              title: 'القائمة فارغة',
              message: 'لا توجد دروس في هذه القائمة بعد.',
            );
          }

          final Map<String, int> progress = ref
              .watch(playlistProgressProvider(playlistId))
              .maybeWhen(data: (value) => value, orElse: () => const {});

          final int viewedCount =
              data.posts.where((post) => progress.containsKey(post.id)).length;
          final int startIndex = data.posts.indexWhere(
            (post) => !progress.containsKey(post.id),
          );
          final int resumeIndex = startIndex == -1 ? 0 : startIndex;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _PlaylistHeader(
                detail: data,
                viewedCount: viewedCount,
                allViewed: startIndex == -1,
                onPlay: () => _openAt(context, ref, data, resumeIndex),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (int i = 0; i < data.posts.length; i++)
                _PlaylistPostTile(
                  index: i,
                  title: data.posts[i].title,
                  progressSeconds: progress[data.posts[i].id],
                  viewed: progress.containsKey(data.posts[i].id),
                  onTap: () => _openAt(context, ref, data, i),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PlaylistHeader extends StatelessWidget {
  const _PlaylistHeader({
    required this.detail,
    required this.viewedCount,
    required this.allViewed,
    required this.onPlay,
  });

  final PlaylistDetail detail;
  final int viewedCount;
  final bool allViewed;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int total = detail.posts.length;
    final String label = viewedCount == 0
        ? 'ابدأ القائمة'
        : allViewed
            ? 'إعادة المشاهدة'
            : 'تابِع القائمة';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (detail.playlist.description != null &&
            detail.playlist.description!.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
            child: Text(
              detail.playlist.description!,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        Row(
          children: [
            Icon(Icons.task_alt_rounded,
                size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.xs),
            Text('اكتمل $viewedCount من $total',
                style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: onPlay,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(label),
        ),
      ],
    );
  }
}

class _PlaylistPostTile extends StatelessWidget {
  const _PlaylistPostTile({
    required this.index,
    required this.title,
    required this.viewed,
    required this.progressSeconds,
    required this.onTap,
  });

  final int index;
  final String title;
  final bool viewed;
  final int? progressSeconds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasResume = (progressSeconds ?? 0) > 0;

    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: viewed
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          foregroundColor:
              viewed ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
          child: viewed
              ? const Icon(Icons.check_rounded)
              : Text('${index + 1}'),
        ),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: hasResume
            ? Text('تابِع من ${formatSeconds(progressSeconds!)}')
            : null,
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: onTap,
      ),
    );
  }
}
