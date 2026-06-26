import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_cms_app/src/features/post/presentation/playlist_context.dart';
import 'package:teacher_cms_app/src/models/post.dart';

Post post(String id) => Post(id: id, title: 'Post $id', subcategoryId: 's1');

void main() {
  final posts = [post('a'), post('b'), post('c')];

  test('position and total are 1-based / count', () {
    const context = PlaylistContext(playlistId: 'p', posts: [], index: 0);
    expect(context.position, 1);

    final mid = PlaylistContext(playlistId: 'p', posts: posts, index: 1);
    expect(mid.position, 2);
    expect(mid.total, 3);
  });

  test('hasNext / nextPost reflect position in the list', () {
    final first = PlaylistContext(playlistId: 'p', posts: posts, index: 0);
    expect(first.hasNext, isTrue);
    expect(first.nextPost?.id, 'b');

    final last = PlaylistContext(playlistId: 'p', posts: posts, index: 2);
    expect(last.hasNext, isFalse);
    expect(last.nextPost, isNull);
  });

  test('advanced() moves to the next index, same playlist & posts', () {
    final next =
        PlaylistContext(playlistId: 'p', posts: posts, index: 0).advanced();
    expect(next.index, 1);
    expect(next.playlistId, 'p');
    expect(next.nextPost?.id, 'c');
  });
}
