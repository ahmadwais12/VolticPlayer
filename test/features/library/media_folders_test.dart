import 'package:flutter_test/flutter_test.dart';
import 'package:voltic_player/domain/entities/media_item.dart';
import 'package:voltic_player/shared/media_folders.dart';

MediaItem _video(String path, {int id = 1}) => MediaItem(
      id: id,
      uri: path,
      path: path,
      fileName: path.split('/').last,
      displayName: path.split('/').last,
      isVideo: true,
    );

MediaItem _song(String path, {int id = 1}) => MediaItem(
      id: id,
      uri: path,
      path: path,
      fileName: path.split('/').last,
      displayName: path.split('/').last,
      isAudio: true,
    );

void main() {
  group('folderPathOf', () {
    test('returns the parent directory of a local file', () {
      expect(
        folderPathOf(_video('/storage/emulated/0/Movies/Clips/a.mp4')),
        '/storage/emulated/0/Movies/Clips',
      );
    });

    test('falls back to uri when path is empty', () {
      final item = MediaItem(
        uri: '/storage/emulated/0/Music/b.mp3',
        fileName: 'b.mp3',
        displayName: 'b',
        isAudio: true,
      );
      expect(folderPathOf(item), '/storage/emulated/0/Music');
    });

    test('network items have no folder', () {
      expect(
        folderPathOf(_video('https://example.com/videos/a.mp4')),
        '',
      );
    });

    test('normalises Windows separators', () {
      expect(
        folderPathOf(_video(r'C:\Users\Me\Vids\a.mp4')),
        'C:/Users/Me/Vids',
      );
    });

    test('a file at the filesystem root maps to "/"', () {
      expect(folderPathOf(_video('/a.mp4')), '/');
    });
  });

  group('folderNameOf', () {
    test('last path segment', () {
      expect(folderNameOf('/storage/emulated/0/Movies'), 'Movies');
    });
    test('empty path → Other', () {
      expect(folderNameOf(''), 'Other');
    });
    test('root → Internal storage', () {
      expect(folderNameOf('/'), 'Internal storage');
    });
  });

  group('groupMediaByFolder', () {
    test('groups items and reports counts with correct units', () {
      final songs = [
        for (var i = 0; i < 150; i++) _song('/music/song$i.mp3', id: i),
        for (var i = 0; i < 3; i++) _song('/downloads/other$i.mp3', id: 200 + i),
      ];
      final folders = groupMediaByFolder(songs);

      expect(folders, hasLength(2));
      // Biggest folder first.
      expect(folders.first.name, 'music');
      expect(folders.first.count, 150);
      expect(folders.first.countLabel(isAudio: true), '150 songs');
      expect(folders.last.countLabel(isAudio: true), '3 songs');
    });

    test('singular labels and video units', () {
      final folders = groupMediaByFolder([
        _video('/a/one.mp4'),
        _video('/b/one.mp4', id: 2),
        _video('/b/two.mp4', id: 3),
      ]);
      final a = folders.firstWhere((f) => f.name == 'a');
      expect(a.countLabel(isAudio: false), '1 video');
      final b = folders.firstWhere((f) => f.name == 'b');
      expect(b.countLabel(isAudio: false), '2 videos');
    });

    test('ties break alphabetically', () {
      final folders = groupMediaByFolder([
        _song('/z/a.mp3'),
        _song('/a/b.mp3', id: 2),
      ]);
      expect(folders.map((f) => f.name), ['a', 'z']);
    });

    test('items without a folder land in "Other"', () {
      final folders = groupMediaByFolder([
        const MediaItem(
          uri: 'https://example.com/x.mp4',
          fileName: 'x.mp4',
          displayName: 'x',
          isVideo: true,
        ),
      ]);
      expect(folders.single.name, 'Other');
      expect(folders.single.path, '');
    });

    test('keeps every item exactly once', () {
      final items = [
        _video('/m/a.mp4'),
        _video('/m/b.mp4', id: 2),
        _video('/n/c.mp4', id: 3),
      ];
      final folders = groupMediaByFolder(items);
      expect(folders.fold<int>(0, (sum, f) => sum + f.count), items.length);
    });
  });
}
