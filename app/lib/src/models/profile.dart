/// A student/admin profile row from the `profiles` table.
class Profile {
  const Profile({
    required this.id,
    required this.role,
    this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String role;
  final String? displayName;
  final String? avatarUrl;

  bool get isAdmin => role == 'admin';

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      role: (map['role'] as String?) ?? 'student',
      displayName: map['display_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
    );
  }
}
