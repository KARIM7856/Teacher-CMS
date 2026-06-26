import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../models/category.dart';
import '../../../models/post.dart';
import '../../../models/post_detail.dart';
import '../../../models/subcategory.dart';
import '../../../models/tag.dart';
import '../data/content_repository.dart';

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return ContentRepository(ref.watch(supabaseClientProvider));
});

/// Identifies a filtered post list: a subcategory, optionally narrowed by tag.
/// A record gives value-equality for free, so the family caches correctly.
typedef PostsQuery = ({String subcategoryId, String? tagId});

final categoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(contentRepositoryProvider).fetchCategories();
});

final subcategoriesProvider =
    FutureProvider.family<List<Subcategory>, String>((ref, categoryId) {
  return ref.watch(contentRepositoryProvider).fetchSubcategories(categoryId);
});

final postsProvider =
    FutureProvider.autoDispose.family<List<Post>, PostsQuery>((ref, query) {
  return ref.watch(contentRepositoryProvider).fetchPosts(
        subcategoryId: query.subcategoryId,
        tagId: query.tagId,
      );
});

final recentPostsProvider = FutureProvider<List<Post>>((ref) {
  return ref.watch(contentRepositoryProvider).fetchRecentPosts();
});

final tagsProvider = FutureProvider<List<Tag>>((ref) {
  return ref.watch(contentRepositoryProvider).fetchTags();
});

final postDetailProvider =
    FutureProvider.autoDispose.family<PostDetail, String>((ref, postId) {
  return ref.watch(contentRepositoryProvider).fetchPostDetail(postId);
});
