import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../models/post_detail.dart';
import '../../content/application/content_providers.dart';
import 'widgets/media_section.dart';

/// Reads and displays a single published post: title, tags, markdown body, and
/// its media (video / PDF / file). Built as a stateful consumer so later phases
/// can hook view tracking and playback-position saving into its lifecycle.
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.postId,
    this.initialTitle,
  });

  final String postId;

  /// Shown in the app bar while the full post loads (we usually already know it).
  final String? initialTitle;

  static Route<void> route(String postId, {String? initialTitle}) {
    return MaterialPageRoute<void>(
      builder: (_) => PostDetailScreen(postId: postId, initialTitle: initialTitle),
    );
  }

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(postDetailProvider(widget.postId));

    return Scaffold(
      appBar: AppBar(title: Text(widget.initialTitle ?? 'الدرس')),
      body: AsyncValueWidget<PostDetail>(
        value: detail,
        onRetry: () => ref.invalidate(postDetailProvider(widget.postId)),
        data: (PostDetail postDetail) => _PostBody(detail: postDetail),
      ),
    );
  }
}

class _PostBody extends StatelessWidget {
  const _PostBody({required this.detail});

  final PostDetail detail;

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
        MediaSection(media: detail.media),
      ],
    );
  }
}
