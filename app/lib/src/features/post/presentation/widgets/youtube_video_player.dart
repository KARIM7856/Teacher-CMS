import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../../../core/theme/app_spacing.dart';

/// Embeds a YouTube video using the inline iframe player (play / pause / seek
/// built in). [initialPositionSeconds] resumes where the student left off,
/// [onPositionChanged] reports playback position (used by latest-viewed
/// tracking), and [onCompleted] fires once when the video ends (playlist
/// auto-advance).
class YoutubeVideoPlayer extends StatefulWidget {
  const YoutubeVideoPlayer({
    super.key,
    required this.videoId,
    this.initialPositionSeconds = 0,
    this.onPositionChanged,
    this.onCompleted,
  });

  final String videoId;
  final int initialPositionSeconds;
  final void Function(Duration position)? onPositionChanged;
  final VoidCallback? onCompleted;

  @override
  State<YoutubeVideoPlayer> createState() => _YoutubeVideoPlayerState();
}

class _YoutubeVideoPlayerState extends State<YoutubeVideoPlayer> {
  late final YoutubePlayerController _controller;
  StreamSubscription<YoutubeVideoState>? _stateSubscription;
  StreamSubscription<YoutubePlayerValue>? _valueSubscription;
  bool _completedFired = false;

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

    if (widget.onCompleted != null) {
      _valueSubscription = _controller.stream.listen((value) {
        if (value.playerState == PlayerState.ended && !_completedFired) {
          _completedFired = true;
          widget.onCompleted!();
        }
      });
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _valueSubscription?.cancel();
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
