/// A unit of learning content. Mirrors `public.posts` (the student app only ever
/// sees published rows — RLS enforces it, and our queries never ask for drafts).
class Post {
  const Post({
    required this.id,
    required this.title,
    this.body,
    required this.subcategoryId,
    this.createdAt,
  });

  final String id;
  final String title;

  /// Markdown body, rendered in the post detail screen.
  final String? body;
  final String subcategoryId;
  final DateTime? createdAt;

  factory Post.fromMap(Map<String, dynamic> map) {
    final String? created = map['created_at'] as String?;
    return Post(
      id: map['id'] as String,
      title: map['title'] as String,
      body: map['body'] as String?,
      subcategoryId: map['subcategory_id'] as String,
      createdAt: created == null ? null : DateTime.tryParse(created),
    );
  }
}
