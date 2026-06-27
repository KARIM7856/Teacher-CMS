import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/category.dart';
import '../../../models/media_item.dart';
import '../../../models/post.dart';
import '../../../models/post_detail.dart';
import '../../../models/subcategory.dart';
import '../../../models/tag.dart';

/// Read access to published learning content. Every query is scoped to
/// `published = true`; drafts are never requested (RLS would block them anyway,
/// but the UI shouldn't even ask).
class ContentRepository {
  ContentRepository(this._client);

  final SupabaseClient _client;

  static const String _mediaBucket = 'media';

  Future<List<Category>> fetchCategories() async {
    final List<Map<String, dynamic>> rows =
        await _client.from('categories').select().order('sort_order');
    return rows.map(Category.fromMap).toList();
  }

  Future<List<Subcategory>> fetchSubcategories(String categoryId) async {
    final List<Map<String, dynamic>> rows = await _client
        .from('subcategories')
        .select()
        .eq('category_id', categoryId)
        .order('sort_order');
    return rows.map(Subcategory.fromMap).toList();
  }

  /// Published posts in a subcategory, optionally narrowed to a single tag.
  Future<List<Post>> fetchPosts({
    required String subcategoryId,
    String? tagId,
  }) async {
    // An inner join on post_tags lets us filter by tag in one round trip.
    final String columns = tagId == null ? '*' : '*, post_tags!inner(tag_id)';
    var filter = _client
        .from('posts')
        .select(columns)
        .eq('subcategory_id', subcategoryId)
        .eq('published', true);
    if (tagId != null) {
      filter = filter.eq('post_tags.tag_id', tagId);
    }
    final List<Map<String, dynamic>> rows =
        await filter.order('created_at', ascending: false);
    return rows.map(Post.fromMap).toList();
  }

  /// Most recently published posts across the whole catalog (for the Home feed).
  Future<List<Post>> fetchRecentPosts({int limit = 10}) async {
    final List<Map<String, dynamic>> rows = await _client
        .from('posts')
        .select()
        .eq('published', true)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(Post.fromMap).toList();
  }

  Future<List<Tag>> fetchTags() async {
    final List<Map<String, dynamic>> rows =
        await _client.from('tags').select().order('name');
    return rows.map(Tag.fromMap).toList();
  }

  /// The post plus its media and tags, fetched together for the detail screen.
  Future<PostDetail> fetchPostDetail(String postId) async {
    final Map<String, dynamic>? postRow = await _client
        .from('posts')
        .select()
        .eq('id', postId)
        .eq('published', true)
        .maybeSingle();
    if (postRow == null) {
      throw StateError('Post not found or not published: $postId');
    }

    final List<Map<String, dynamic>> mediaRows = await _client
        .from('media')
        .select()
        .eq('post_id', postId)
        .order('sort_order');

    final List<Map<String, dynamic>> tagRows = await _client
        .from('post_tags')
        .select('tags(id, name, slug)')
        .eq('post_id', postId);

    final List<Tag> tags = tagRows
        .map((row) => row['tags'])
        .whereType<Map<String, dynamic>>()
        .map(Tag.fromMap)
        .toList();

    return PostDetail(
      post: Post.fromMap(postRow),
      media: mediaRows.map(MediaItem.fromMap).toList(),
      tags: tags,
    );
  }

  /// A short-lived signed URL for a private media object (videos played inline).
  Future<String> signedUrlForPath(String storagePath) {
    return _client.storage.from(_mediaBucket).createSignedUrl(storagePath, 3600);
  }

  /// Raw bytes for a private media object (used to render PDFs from storage).
  Future<Uint8List> downloadBytes(String storagePath) {
    return _client.storage.from(_mediaBucket).download(storagePath);
  }
}
