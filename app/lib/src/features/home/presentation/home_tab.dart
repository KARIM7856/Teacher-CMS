import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/error_view.dart';
import '../../../models/post.dart';
import '../../../models/view_history_entry.dart';
import '../../content/application/content_providers.dart';
import '../../content/presentation/widgets/continue_card.dart';
import '../../content/presentation/widgets/post_card.dart';
import '../../content/presentation/widgets/section_header.dart';
import '../../history/application/history_providers.dart';

/// The Home tab: a "continue where you left off" row (shown only when there's
/// something to resume) over the most recent published lessons.
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Post>> recent = ref.watch(recentPostsProvider);
    final AsyncValue<List<ViewHistoryEntry>> continueLearning =
        ref.watch(continueLearningProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('الرئيسية')),
      body: recent.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => ErrorView(
          onRetry: () => ref.invalidate(recentPostsProvider),
        ),
        data: (posts) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(recentPostsProvider);
            ref.invalidate(continueLearningProvider);
            await ref.read(recentPostsProvider.future);
          },
          child: ListView(
            children: [
              ..._continueSection(continueLearning),
              const SectionHeader(title: 'أحدث الدروس'),
              if (posts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text('لا توجد دروس منشورة بعد.'),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Column(
                    children: [for (final post in posts) PostCard(post: post)],
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  /// The "continue" row, or nothing while it's loading/failed/empty — it's a
  /// secondary convenience, so it never blocks the Home feed.
  List<Widget> _continueSection(AsyncValue<List<ViewHistoryEntry>> value) {
    return value.maybeWhen(
      orElse: () => const [],
      data: (entries) {
        if (entries.isEmpty) return const [];
        return [
          const SectionHeader(title: 'تابِع ما بدأته'),
          SizedBox(
            height: 196,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: entries.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.md),
                child: ContinueCard(entry: entries[index]),
              ),
            ),
          ),
        ];
      },
    );
  }
}
