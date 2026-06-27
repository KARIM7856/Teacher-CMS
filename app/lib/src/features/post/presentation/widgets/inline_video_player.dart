import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../models/media_item.dart';
import '../../../content/application/content_providers.dart';
import 'external_media_button.dart';

/// Plays a directly-streamable video (a stored object or a direct file URL)
/// inline via Chewie, which provides play / pause / seek controls. Stored
/// objects are resolved to a short-lived signed URL first.
///
/// [initialPositionSeconds] resumes playback where the student left off, and
/// [onPositionChanged] reports progress so it can be saved (wired up in the
/// latest-viewed-tracking phase).
class InlineVideoPlayer extends ConsumerStatefulWidget {
  const InlineVideoPlayer({
    super.key,
    required this.item,
    this.initialPositionSeconds = 0,
    this.onPositionChanged,
    this.onCompleted,
  });

  final MediaItem item;
  final int initialPositionSeconds;
  final void Function(Duration position)? onPositionChanged;

  /// Fires once when playback reaches the end (used for playlist auto-advance).
  final VoidCallback? onCompleted;

  @override
  ConsumerState<InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends ConsumerState<InlineVideoPlayer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _loading = true;
  bool _failed = false;
  bool _completedFired = false;

  @override
  void initState() {
    super.initState();
    _setUp();
  }

  Future<String> _resolveUrl() async {
    final MediaItem item = widget.item;
    if (item.storagePath != null && item.storagePath!.isNotEmpty) {
      return ref.read(contentRepositoryProvider).signedUrlForPath(item.storagePath!);
    }
    return item.externalUrl!;
  }

  Future<void> _setUp() async {
    try {
      final String url = await _resolveUrl();
      final VideoPlayerController video =
          VideoPlayerController.networkUrl(Uri.parse(url));
      await video.initialize();
      if (widget.initialPositionSeconds > 0) {
        await video.seekTo(Duration(seconds: widget.initialPositionSeconds));
      }
      video.addListener(_reportPosition);

      final double aspect =
          video.value.aspectRatio == 0 ? 16 / 9 : video.value.aspectRatio;
      final ChewieController chewie = ChewieController(
        videoPlayerController: video,
        aspectRatio: aspect,
        autoPlay: false,
        looping: false,
        allowFullScreen: true,
      );

      if (!mounted) {
        chewie.dispose();
        video.dispose();
        return;
      }
      setState(() {
        _videoController = video;
        _chewieController = chewie;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _reportPosition() {
    final VideoPlayerController? video = _videoController;
    if (video == null || !video.value.isInitialized) return;

    widget.onPositionChanged?.call(video.value.position);

    final Duration duration = video.value.duration;
    final bool reachedEnd = duration > Duration.zero &&
        video.value.position >= duration - const Duration(milliseconds: 500);
    if (reachedEnd && !_completedFired) {
      _completedFired = true;
      widget.onCompleted?.call();
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_reportPosition);
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      final String? url = widget.item.externalUrl;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تعذّر تشغيل الفيديو هنا.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (url != null && url.isNotEmpty)
            ExternalMediaButton(url: url, label: 'افتح الفيديو', icon: Icons.play_circle_outline_rounded),
        ],
      );
    }

    if (_loading || _chewieController == null) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black12,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: AspectRatio(
        aspectRatio: _chewieController!.aspectRatio ?? 16 / 9,
        child: Chewie(controller: _chewieController!),
      ),
    );
  }
}
