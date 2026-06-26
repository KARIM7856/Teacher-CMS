/// A freeform tag used to group posts across categories. Mirrors `public.tags`.
class Tag {
  const Tag({required this.id, required this.name, required this.slug});

  final String id;
  final String name;
  final String slug;

  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      id: map['id'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
    );
  }
}
