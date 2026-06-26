/// A top-level content category (e.g. الرياضيات). Mirrors `public.categories`.
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.icon,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String slug;

  /// Optional icon hint authored in the admin portal (a name, not an asset).
  final String? icon;
  final int sortOrder;

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
      icon: map['icon'] as String?,
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }
}
