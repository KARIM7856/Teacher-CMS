/// A badge a student can earn. Mirrors `public.achievements`. The app keys all
/// logic and visuals off the stable [code], not the id.
class Achievement {
  const Achievement({
    required this.id,
    required this.code,
    required this.title,
    this.description,
    this.icon,
    this.sortOrder = 0,
  });

  final String id;
  final String code;
  final String title;
  final String? description;

  /// Icon hint from the server (e.g. "star", "fire", "trophy", "school"),
  /// mapped to a Material icon in the UI.
  final String? icon;
  final int sortOrder;

  factory Achievement.fromMap(Map<String, dynamic> map) {
    return Achievement(
      id: map['id'] as String,
      code: map['code'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      icon: map['icon'] as String?,
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }
}
