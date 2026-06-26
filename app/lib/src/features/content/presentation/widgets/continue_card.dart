import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/duration_format.dart';
import '../../../../models/view_history_entry.dart';
import '../../../post/presentation/post_detail_screen.dart';

/// A compact card for the horizontal "continue where you left off" row. Shows
/// the post title and, when a video position was saved, where to resume.
class ContinueCard extends StatelessWidget {
  const ContinueCard({super.key, required this.entry});

  final ViewHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasResume = entry.progressSeconds > 0;

    return SizedBox(
      width: 220,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            PostDetailScreen.route(entry.post.id, initialTitle: entry.post.title),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 88,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.tertiary,
                    ],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.play_circle_fill_rounded,
                      color: Colors.white, size: 40),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          hasResume
                              ? Icons.history_rounded
                              : Icons.play_arrow_rounded,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          hasResume
                              ? 'تابِع من ${formatSeconds(entry.progressSeconds)}'
                              : 'تابِع المشاهدة',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
