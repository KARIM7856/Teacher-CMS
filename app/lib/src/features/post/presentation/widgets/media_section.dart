import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../models/media_item.dart';
import 'file_attachment_view.dart';
import 'pdf_media_view.dart';
import 'video_player_view.dart';

/// Lays out all of a post's attachments in order, choosing a viewer per type.
///
/// Resume/progress hooks ([initialVideoPositionSeconds], [onVideoProgress])
/// apply to the post's *first* video — the one "continue where you left off"
/// tracks for this post.
class MediaSection extends StatelessWidget {
  const MediaSection({
    super.key,
    required this.media,
    this.initialVideoPositionSeconds = 0,
    this.onVideoProgress,
    this.onVideoCompleted,
  });

  final List<MediaItem> media;
  final int initialVideoPositionSeconds;
  final void Function(Duration position)? onVideoProgress;
  final VoidCallback? onVideoCompleted;

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);
    final List<Widget> children = [];
    bool primaryVideoAssigned = false;

    for (final MediaItem item in media) {
      // A heading for inline viewers (the file tile shows its own name).
      final String? name = item.displayName;
      if (name != null && name.isNotEmpty && item.type != MediaType.other) {
        children.add(Padding(
          padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
          child: Text(name, style: theme.textTheme.titleMedium),
        ));
      }

      switch (item.type) {
        case MediaType.video:
          final bool isPrimary = !primaryVideoAssigned;
          primaryVideoAssigned = true;
          children.add(VideoPlayerView(
            item: item,
            initialPositionSeconds: isPrimary ? initialVideoPositionSeconds : 0,
            onPositionChanged: isPrimary ? onVideoProgress : null,
            onCompleted: isPrimary ? onVideoCompleted : null,
          ));
        case MediaType.pdf:
          children.add(PdfMediaView(item: item));
        case MediaType.other:
          children.add(FileAttachmentView(item: item));
      }
      children.add(const SizedBox(height: AppSpacing.lg));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
