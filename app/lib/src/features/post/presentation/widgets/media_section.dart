import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../models/media_item.dart';
import 'file_attachment_view.dart';
import 'pdf_media_view.dart';
import 'video_player_view.dart';

/// Lays out all of a post's attachments in order, choosing a viewer per type.
///
/// Videos play inline (the lesson content). PDFs are wrapped in a collapsible
/// card — collapsed by default and loaded only on first expand, so a long
/// document neither dominates the post nor downloads until the student opens it.
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
      final String? name = item.displayName;

      // Videos show a plain heading above the inline player; PDFs and files
      // carry their own titled headers (collapsible card / file tile).
      if (item.type == MediaType.video && name != null && name.isNotEmpty) {
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
          children.add(CollapsibleMedia(
            icon: Icons.picture_as_pdf_rounded,
            title: (name != null && name.isNotEmpty) ? name : 'ملف PDF',
            builder: (_) => PdfMediaView(item: item),
          ));
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

/// A titled card whose body expands/collapses. The body is built lazily on the
/// first expand (so heavy viewers don't load while collapsed) and then kept
/// alive off-screen, so collapsing and re-opening doesn't reload it.
class CollapsibleMedia extends StatefulWidget {
  const CollapsibleMedia({
    super.key,
    required this.title,
    required this.icon,
    required this.builder,
    this.initiallyExpanded = false,
  });

  final String title;
  final IconData icon;
  final WidgetBuilder builder;
  final bool initiallyExpanded;

  @override
  State<CollapsibleMedia> createState() => _CollapsibleMediaState();
}

class _CollapsibleMediaState extends State<CollapsibleMedia> {
  late bool _expanded = widget.initiallyExpanded;
  late bool _built = widget.initiallyExpanded;

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) _built = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(widget.icon, color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(_expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded),
                ],
              ),
            ),
          ),
          if (_built)
            Offstage(
              offstage: !_expanded,
              child: TickerMode(
                enabled: _expanded,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: widget.builder(context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
