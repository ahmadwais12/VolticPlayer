import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltic_player/domain/entities/media_item.dart';
import 'package:voltic_player/shared/media_folders.dart';
import 'package:voltic_player/shared/widgets/folder_tile.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

MediaItem _song(String path, {int id = 1}) => MediaItem(
      id: id,
      uri: path,
      path: path,
      fileName: path.split('/').last,
      displayName: path.split('/').last,
      isAudio: true,
    );

void main() {
  group('FolderTile', () {
    testWidgets('shows folder name and "150 songs" count', (tester) async {
      final folder = groupMediaByFolder([
        for (var i = 0; i < 150; i++) _song('/music/song$i.mp3', id: i),
      ]).single;

      await tester.pumpWidget(
        _wrap(FolderTile(folder: folder, isAudio: true, onTap: () {})),
      );

      expect(find.text('music'), findsOneWidget);
      expect(find.text('150 songs'), findsOneWidget);
      expect(find.text('150'), findsOneWidget); // count badge
    });

    testWidgets('shows "1 video" for a single video folder',
        (tester) async {
      final folder = groupMediaByFolder([
        MediaItem(
          id: 1,
          uri: '/movies/clip.mp4',
          path: '/movies/clip.mp4',
          fileName: 'clip.mp4',
          displayName: 'clip.mp4',
          isVideo: true,
        ),
      ]).single;

      await tester.pumpWidget(
        _wrap(FolderTile(folder: folder, isAudio: false, onTap: () {})),
      );

      expect(find.text('movies'), findsOneWidget);
      expect(find.text('1 video'), findsOneWidget);
    });

    testWidgets('fires onTap', (tester) async {
      final folder = groupMediaByFolder([
        _song('/music/a.mp3'),
      ]).single;
      var taps = 0;

      await tester.pumpWidget(
        _wrap(FolderTile(folder: folder, isAudio: true, onTap: () => taps++)),
      );
      await tester.tap(find.byType(FolderTile));
      expect(taps, 1);
    });
  });
}
