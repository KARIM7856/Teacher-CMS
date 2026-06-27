/// The kind of a [MediaItem]. Matches the `public.media_type` enum.
enum MediaType {
  video,
  pdf,
  other;

  static MediaType fromName(String value) {
    return MediaType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => MediaType.other,
    );
  }
}

/// How a video should be presented, derived from its URL. Lets the detail
/// screen pick the right player without the widget re-parsing URLs.
enum VideoSource { youtube, vimeo, directFile, storage, unknown }

/// A file attached to a post: a video, a PDF, or some other downloadable file.
/// Mirrors `public.media`. Exactly one of [storagePath] / [externalUrl] is set
/// (enforced by a CHECK constraint in the schema).
class MediaItem {
  const MediaItem({
    required this.id,
    required this.postId,
    required this.type,
    this.storagePath,
    this.externalUrl,
    this.displayName,
    this.sortOrder = 0,
  });

  final String id;
  final String postId;
  final MediaType type;

  /// Object path inside the private `media` storage bucket (needs a signed URL).
  final String? storagePath;

  /// A ready-to-use external URL (e.g. a YouTube link or a direct file URL).
  final String? externalUrl;
  final String? displayName;
  final int sortOrder;

  bool get isExternal => externalUrl != null && externalUrl!.isNotEmpty;

  factory MediaItem.fromMap(Map<String, dynamic> map) {
    return MediaItem(
      id: map['id'] as String,
      postId: map['post_id'] as String,
      type: MediaType.fromName(map['type'] as String),
      storagePath: map['storage_path'] as String?,
      externalUrl: map['external_url'] as String?,
      displayName: map['display_name'] as String?,
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }

  /// Classifies a video so the UI can choose a player. Stored-bucket and direct
  /// file URLs play inline; YouTube uses an embedded player; Vimeo and anything
  /// unrecognized fall back to opening externally.
  VideoSource get videoSource {
    if (storagePath != null && storagePath!.isNotEmpty) {
      return VideoSource.storage;
    }
    final String? url = externalUrl;
    if (url == null || url.isEmpty) return VideoSource.unknown;

    final String lower = url.toLowerCase();
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return VideoSource.youtube;
    }
    if (lower.contains('vimeo.com')) return VideoSource.vimeo;

    final Uri? uri = Uri.tryParse(url);
    final String path = (uri?.path ?? lower).toLowerCase();
    const List<String> playableExtensions = ['.mp4', '.m3u8', '.mov', '.webm', '.mkv'];
    if (playableExtensions.any(path.endsWith)) {
      return VideoSource.directFile;
    }
    return VideoSource.unknown;
  }
}
