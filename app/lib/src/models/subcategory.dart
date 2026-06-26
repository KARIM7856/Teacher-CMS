/// A subcategory under a [Category] (e.g. الجبر under الرياضيات).
/// Mirrors `public.subcategories`.
class Subcategory {
  const Subcategory({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.slug,
    this.sortOrder = 0,
  });

  final String id;
  final String categoryId;
  final String name;
  final String slug;
  final int sortOrder;

  factory Subcategory.fromMap(Map<String, dynamic> map) {
    return Subcategory(
      id: map['id'] as String,
      categoryId: map['category_id'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }
}
