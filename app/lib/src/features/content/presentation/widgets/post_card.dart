import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../models/post.dart';
import '../../../post/presentation/post_detail_screen.dart';

/// A tappable list row for a post. Opens the post detail screen. [subtitle] can
/// carry context such as a resume hint.
class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post, this.subtitle});

  final Post post;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.menu_book_rounded,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(post.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: subtitle == null ? null : Text(subtitle!),
        // In RTL, "forward" points to the start (left) edge.
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: () => Navigator.of(context).push(
          PostDetailScreen.route(post.id, initialTitle: post.title),
        ),
      ),
    );
  }
}
