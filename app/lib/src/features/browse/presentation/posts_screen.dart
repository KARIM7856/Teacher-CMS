import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/placeholder_view.dart';
import '../../../models/post.dart';
import '../../../models/subcategory.dart';
import '../../../models/tag.dart';
import '../../content/application/content_providers.dart';
import '../../content/presentation/widgets/post_card.dart';

/// The posts inside a subcategory, with an optional tag filter along the top.
class PostsScreen extends ConsumerStatefulWidget {
  const PostsScreen({super.key, required this.subcategory});

  final Subcategory subcategory;

  static Route<void> route(Subcategory subcategory) {
    return MaterialPageRoute<void>(
      builder: (_) => PostsScreen(subcategory: subcategory),
    );
  }

  @override
  ConsumerState<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends ConsumerState<PostsScreen> {
  String? _selectedTagId;

  @override
  Widget build(BuildContext context) {
    final PostsQuery query =
        (subcategoryId: widget.subcategory.id, tagId: _selectedTagId);
    final AsyncValue<List<Post>> posts = ref.watch(postsProvider(query));
    final AsyncValue<List<Tag>> tags = ref.watch(tagsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.subcategory.name)),
      body: Column(
        children: [
          // The tag filter only appears once tags have loaded successfully.
          tags.maybeWhen(
            orElse: () => const SizedBox.shrink(),
            data: (items) => items.isEmpty
                ? const SizedBox.shrink()
                : _TagFilterBar(
                    tags: items,
                    selectedTagId: _selectedTagId,
                    onSelected: (id) => setState(() => _selectedTagId = id),
                  ),
          ),
          Expanded(
            child: AsyncValueWidget<List<Post>>(
              value: posts,
              onRetry: () => ref.invalidate(postsProvider(query)),
              data: (items) {
                if (items.isEmpty) {
                  return PlaceholderView(
                    icon: Icons.article_outlined,
                    title: 'لا توجد دروس',
                    message: _selectedTagId == null
                        ? 'لا توجد دروس في هذا القسم بعد.'
                        : 'لا توجد دروس بهذا الوسم.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(postsProvider(query));
                    await ref.read(postsProvider(query).future);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: items.length,
                    itemBuilder: (context, index) =>
                        PostCard(post: items[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A horizontally-scrolling row of tag chips, with a leading "الكل" (All) chip
/// that clears the filter.
class _TagFilterBar extends StatelessWidget {
  const _TagFilterBar({
    required this.tags,
    required this.selectedTagId,
    required this.onSelected,
  });

  final List<Tag> tags;
  final String? selectedTagId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
            child: ChoiceChip(
              label: const Text('الكل'),
              selected: selectedTagId == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          for (final tag in tags)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(tag.name),
                selected: selectedTagId == tag.id,
                onSelected: (_) => onSelected(tag.id),
              ),
            ),
        ],
      ),
    );
  }
}
