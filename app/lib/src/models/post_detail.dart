import 'media_item.dart';
import 'post.dart';
import 'tag.dart';

/// Everything the post detail screen needs, fetched together: the post, its
/// attached [media] (ordered), and its [tags].
class PostDetail {
  const PostDetail({
    required this.post,
    required this.media,
    required this.tags,
  });

  final Post post;
  final List<MediaItem> media;
  final List<Tag> tags;
}
