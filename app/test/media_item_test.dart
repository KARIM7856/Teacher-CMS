import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_cms_app/src/models/media_item.dart';

MediaItem video({String? externalUrl, String? storagePath}) => MediaItem(
      id: 'm1',
      postId: 'p1',
      type: MediaType.video,
      externalUrl: externalUrl,
      storagePath: storagePath,
    );

void main() {
  group('MediaType.fromName', () {
    test('maps known names and falls back to other', () {
      expect(MediaType.fromName('video'), MediaType.video);
      expect(MediaType.fromName('pdf'), MediaType.pdf);
      expect(MediaType.fromName('weird'), MediaType.other);
    });
  });

  group('MediaItem.videoSource', () {
    test('a stored object plays inline regardless of any URL', () {
      expect(video(storagePath: 'post/clip.mp4').videoSource,
          VideoSource.storage);
    });

    test('YouTube links (long and short) use the YouTube player', () {
      expect(video(externalUrl: 'https://www.youtube.com/watch?v=abc123').videoSource,
          VideoSource.youtube);
      expect(video(externalUrl: 'https://youtu.be/abc123').videoSource,
          VideoSource.youtube);
    });

    test('Google Drive links use the Drive player', () {
      expect(
        video(externalUrl: 'https://drive.google.com/file/d/ABC123_x-y/view?usp=sharing')
            .videoSource,
        VideoSource.googleDrive,
      );
      expect(
        video(externalUrl: 'https://drive.google.com/open?id=ABC123_x-y').videoSource,
        VideoSource.googleDrive,
      );
    });

    test('Vimeo falls back to opening externally', () {
      expect(video(externalUrl: 'https://vimeo.com/123456').videoSource,
          VideoSource.vimeo);
    });

    test('direct media files play inline', () {
      expect(video(externalUrl: 'https://cdn.example.com/lesson.mp4').videoSource,
          VideoSource.directFile);
      expect(video(externalUrl: 'https://cdn.example.com/stream/master.m3u8').videoSource,
          VideoSource.directFile);
    });

    test('an unrecognized page URL is treated as unknown', () {
      expect(video(externalUrl: 'https://example.com/watch/page').videoSource,
          VideoSource.unknown);
    });
  });

  group('MediaItem.googleDriveFileId', () {
    test('parses the id from the /file/d/ share form', () {
      expect(
        video(externalUrl: 'https://drive.google.com/file/d/ABC123_x-y/view?usp=sharing')
            .googleDriveFileId,
        'ABC123_x-y',
      );
    });

    test('parses the id from an ?id= query form', () {
      expect(
        video(externalUrl: 'https://drive.google.com/open?id=ABC123_x-y').googleDriveFileId,
        'ABC123_x-y',
      );
    });

    test('returns null when there is no id', () {
      expect(video(externalUrl: 'https://drive.google.com/drive/my-drive').googleDriveFileId,
          isNull);
    });
  });
}
