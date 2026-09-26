import 'package:flutter_test/flutter_test.dart';
import 'package:vlc_remote_flutter/models/playlist_item.dart';

void main() {
  group('PlaylistItem Tests', () {
    test('displayName removes path and extension', () {
      final item = PlaylistItem(
        id: 1,
        index: 0,
        title: '/media/videos/movie.mp4',
      );
      expect(item.displayName, 'movie');
    });

    test('displayName handles no extension', () {
      final item = PlaylistItem(id: 2, index: 1, title: '/media/videos/video');
      expect(item.displayName, 'video');
    });

    test('displayName handles empty title', () {
      final item = PlaylistItem(id: 3, index: 2, title: '');
      expect(item.displayName, '');
    });

    test('copyWith updates fields correctly', () {
      final item = PlaylistItem(
        id: 1,
        index: 0,
        title: 'original.mp4',
        duration: '00:05:00',
        isPlaying: false,
      );

      final updated = item.copyWith(title: 'new.mp4', isPlaying: true);

      expect(updated.id, item.id);
      expect(updated.title, 'new.mp4');
      expect(updated.isPlaying, true);
      expect(updated.duration, '00:05:00');
    });

    test('Equality based on id, index, title', () {
      final item1 = PlaylistItem(id: 1, index: 0, title: 'a.mp4');
      final item2 = PlaylistItem(id: 1, index: 0, title: 'a.mp4');
      final item3 = PlaylistItem(id: 2, index: 0, title: 'a.mp4');

      expect(item1, equals(item2));
      expect(item1, isNot(equals(item3)));
    });

    test('isPlaying defaults to false', () {
      final item = PlaylistItem(id: 1, index: 0, title: 'test.mp4');
      expect(item.isPlaying, false);
    });
  });
}
