/// An ordered collection of posts curated by the teacher. Mirrors
/// `public.playlists` (students only ever see published playlists).
class Playlist {
  const Playlist({
    required this.id,
    required this.title,
    this.description,
    this.coverImage,
  });

  final String id;
  final String title;
  final String? description;

  /// Optional cover image URL (public-assets bucket / external).
  final String? coverImage;

  factory Playlist.fromMap(Map<String, dynamic> map) {
    return Playlist(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      coverImage: map['cover_image'] as String?,
    );
  }
}
