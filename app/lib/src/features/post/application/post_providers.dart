import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/post_detail.dart';
import '../../content/application/content_providers.dart';
import '../../history/application/history_providers.dart';

/// What the post detail screen needs in one load: the post (with media + tags),
/// whether the student has marked it seen, and the position to resume from.
class PostView {
  const PostView({
    required this.detail,
    required this.resumeSeconds,
    required this.seen,
  });

  final PostDetail detail;
  final int resumeSeconds;
  final bool seen;
}

final postViewProvider =
    FutureProvider.autoDispose.family<PostView, String>((ref, postId) async {
  final detail =
      await ref.watch(contentRepositoryProvider).fetchPostDetail(postId);
  final state =
      await ref.watch(viewHistoryRepositoryProvider).viewStateForPost(postId);
  return PostView(
    detail: detail,
    resumeSeconds: state.progressSeconds,
    seen: state.seen,
  );
});
