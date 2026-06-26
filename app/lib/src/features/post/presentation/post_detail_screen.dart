import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../models/post_detail.dart';
import '../../history/application/history_providers.dart';
import '../../history/data/view_history_repository.dart';
import '../../playlists/application/playlist_providers.dart';
import '../application/post_providers.dart';
import 'playlist_context.dart';
import 'widgets/media_section.dart';

/// Displays a single published post and tracks engagement: it records the view,
/// resumes video from the saved position, and periodically saves progress. When
/// opened from a playlist it also drives sequential playback.
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.postId,
    this.initialTitle,
    this.playlistContext,
  });

  final String postId;

  /// Shown in the app bar while the full post loads (we usually already know it).
  final String? initialTitle;

  /// Set when the post is opened as part of a playlist (enables "next lesson").
  final PlaylistContext? playlistContext;

  static Route<void> route(
    String postId, {
    String? initialTitle,
    PlaylistContext? playlistContext,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => PostDetailScreen(
        postId: postId,
        initialTitle: initialTitle,
        playlistContext: playlistContext,
      ),
    );
  }

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  // Progress is saved at most this often while a video plays, plus once on exit
  // — so we never hammer the database on every tick.
  static const Duration _saveInterval = Duration(seconds: 5);

  late final ViewHistoryRepository _history;
  Timer? _saveTimer;
  int _latestPositionSeconds = 0;
  int _lastSavedSeconds = -1;
  bool _advanced = false;

  @override
  void initState() {
    super.initState();
    _history = ref.read(viewHistoryRepositoryProvider);
    _recordOpen();
    _saveTimer = Timer.periodic(_saveInterval, (_) => _flushProgress());
  }

  Future<void> _recordOpen() async {
    await _history.recordView(widget.postId);
    if (!mounted) return;
    // Surface this view on the Home "continue" row and any playlist progress.
    ref.invalidate(continueLearningProvider);
    final PlaylistContext? playlist = widget.playlistContext;
    if (playlist != null) {
      ref.invalidate(playlistProgressProvider(playlist.playlistId));
    }
  }

  // High-frequency ticks only update memory; the timer/dispose do the writing.
  void _onProgress(Duration position) =>
      _latestPositionSeconds = position.inSeconds;

  void _flushProgress() {
    if (_latestPositionSeconds <= 0 ||
        _latestPositionSeconds == _lastSavedSeconds) {
      return;
    }
    _lastSavedSeconds = _latestPositionSeconds;
    // Fire-and-forget: a missed progress write is not worth surfacing.
    _history.saveProgress(widget.postId, _latestPositionSeconds);
  }

  void _goToNext() {
    final PlaylistContext? playlist = widget.playlistContext;
    if (_advanced || playlist == null || !playlist.hasNext) return;
    _advanced = true;
    final next = playlist.nextPost!;
    Navigator.of(context).pushReplacement(
      PostDetailScreen.route(
        next.id,
        initialTitle: next.title,
        playlistContext: playlist.advanced(),
      ),
    );
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _flushProgress(); // final save (repository keeps its own client)
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(postViewProvider(widget.postId));
    final PlaylistContext? playlist = widget.playlistContext;

    return Scaffold(
      appBar: AppBar(title: Text(widget.initialTitle ?? 'الدرس')),
      body: AsyncValueWidget<PostView>(
        value: view,
        onRetry: () => ref.invalidate(postViewProvider(widget.postId)),
        data: (PostView postView) => _PostBody(
          detail: postView.detail,
          resumeSeconds: postView.resumeSeconds,
          onVideoProgress: _onProgress,
          onVideoCompleted: playlist != null ? _goToNext : null,
        ),
      ),
      bottomNavigationBar: playlist == null
          ? null
          : _PlaylistBar(context: playlist, onNext: _goToNext),
    );
  }
}

class _PostBody extends StatelessWidget {
  const _PostBody({
    required this.detail,
    required this.resumeSeconds,
    this.onVideoProgress,
    this.onVideoCompleted,
  });

  final PostDetail detail;
  final int resumeSeconds;
  final void Function(Duration position)? onVideoProgress;
  final VoidCallback? onVideoCompleted;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? body = detail.post.body;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(detail.post.title, style: theme.textTheme.headlineSmall),
        if (detail.tags.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final tag in detail.tags)
                Chip(
                  label: Text(tag.name),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
        if (body != null && body.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          MarkdownBody(
            data: body,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: theme.textTheme.bodyLarge,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        MediaSection(
          media: detail.media,
          initialVideoPositionSeconds: resumeSeconds,
          onVideoProgress: onVideoProgress,
          onVideoCompleted: onVideoCompleted,
        ),
      ],
    );
  }
}

/// The bottom bar shown during playlist playback: position plus a way forward.
class _PlaylistBar extends StatelessWidget {
  const _PlaylistBar({required this.context, required this.onNext});

  final PlaylistContext context;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext buildContext) {
    final ThemeData theme = Theme.of(buildContext);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'الدرس ${context.position} من ${context.total}',
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (context.hasNext)
              FilledButton.icon(
                onPressed: onNext,
                // "Forward" points to the start (left) edge in RTL.
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('الدرس التالي'),
              )
            else
              FilledButton.tonalIcon(
                onPressed: () => Navigator.of(buildContext).pop(),
                icon: const Icon(Icons.check_rounded),
                label: const Text('أنهيت القائمة'),
              ),
          ],
        ),
      ),
    );
  }
}
