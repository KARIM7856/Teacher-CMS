import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../../../core/theme/app_spacing.dart';

/// Embeds a YouTube video using the inline iframe player (play / pause / seek
/// built in). [initialPositionSeconds] resumes where the student left off, and
/// [onPositionChanged] reports playback position (used by latest-viewed
/// tracking) — the state stream emits roughly once per second.
class YoutubeVideoPlayer extends StatefulWidget {
  const YoutubeVideoPlayer({
    super.key,
    required this.videoId,
    this.initialPositionSeconds = 0,
    this.onPositionChanged,
  });

  final String videoId;
  final int initialPositionSeconds;
  final void Function(Duration position)? onPositionChanged;

  @override
  State<YoutubeVideoPlayer> createState() => _YoutubeVideoPlayerState();
}

class _YoutubeVideoPlayerState extends State<YoutubeVideoPlayer> {
  late final YoutubePlayerController _controller;
  StreamSubscription<YoutubeVideoState>? _stateSubscription;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: false,
      startSeconds: widget.initialPositionSeconds.toDouble(),
    );
    final onPositionChanged = widget.onPositionChanged;
    if (onPositionChanged != null) {
      _stateSubscription = _controller.videoStateStream
          .listen((state) => onPositionChanged(state.position));
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: YoutubePlayer(controller: _controller),
    );
  }
}
