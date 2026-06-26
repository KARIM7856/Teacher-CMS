import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../../../models/media_item.dart';
import 'external_media_button.dart';
import 'inline_video_player.dart';
import 'youtube_video_player.dart';

/// Picks the right player for a video [MediaItem] based on its source:
///   * stored object / direct file URL → inline Chewie player
///   * YouTube link                    → embedded YouTube player
///   * Vimeo / unrecognized            → "open externally" fallback
class VideoPlayerView extends StatelessWidget {
  const VideoPlayerView({
    super.key,
    required this.item,
    this.initialPositionSeconds = 0,
    this.onPositionChanged,
  });

  final MediaItem item;
  final int initialPositionSeconds;
  final void Function(Duration position)? onPositionChanged;

  @override
  Widget build(BuildContext context) {
    switch (item.videoSource) {
      case VideoSource.storage:
      case VideoSource.directFile:
        return InlineVideoPlayer(
          item: item,
          initialPositionSeconds: initialPositionSeconds,
          onPositionChanged: onPositionChanged,
        );

      case VideoSource.youtube:
        final String? videoId =
            YoutubePlayerController.convertUrlToId(item.externalUrl!);
        if (videoId == null) {
          return ExternalMediaButton(
            url: item.externalUrl!,
            label: 'افتح الفيديو',
            icon: Icons.play_circle_outline_rounded,
          );
        }
        return YoutubeVideoPlayer(
          videoId: videoId,
          initialPositionSeconds: initialPositionSeconds,
          onPositionChanged: onPositionChanged,
        );

      case VideoSource.vimeo:
      case VideoSource.unknown:
        final String? url = item.externalUrl;
        if (url == null || url.isEmpty) {
          return Text(
            'هذا الفيديو غير متاح حاليًا.',
            style: Theme.of(context).textTheme.bodyMedium,
          );
        }
        return ExternalMediaButton(
          url: url,
          label: 'افتح الفيديو',
          icon: Icons.play_circle_outline_rounded,
        );
    }
  }
}
