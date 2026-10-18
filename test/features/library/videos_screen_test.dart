import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voltic_player/domain/entities/media_item.dart';
import 'package:voltic_player/features/library/presentation/controllers/library_prefs_controller.dart';
import 'package:voltic_player/features/library/presentation/controllers/videos_controller.dart';
import 'package:voltic_player/features/library/presentation/screens/videos_screen.dart';
import 'package:voltic_player/shared/widgets/folder_tile.dart';
import 'package:voltic_player/shared/widgets/media_grid.dart';

/// In-memory stand-in: no scanner, no database.
class _FakeVideosController extends VideosController {
  _FakeVideosController(this.items);
  final List<MediaItem> items;

  @override
  Future<List<MediaItem>> build() async => items;

  @override
  Future<void> reload() async {}

  @override
  Future<void> scan() async {}

  @override
  Future<void> seedDemo() async {}
}

/// Prefs controller without persistence (avoids the database in tests).
class _FakePrefsController extends LibraryPrefsController {
  _FakePrefsController(this.initial);
  final LibraryPrefs initial;

  @override
  Future<LibraryPrefs> build() async => initial;

  @override
  Future<void> toggleLayout() async {
    final cur = state.value ?? const LibraryPrefs();
    state = AsyncData(cur.copyWith(layout: cur.isGrid ? 'list' : 'grid'));
  }

  @override
  Future<void> setView(String view) async {
    final cur = state.value ?? const LibraryPrefs();
    if (view != 'folders' && view != 'all' || cur.view == view) return;
    state = AsyncData(cur.copyWith(view: view));
  }
}

final _videos = [
  MediaItem(
    id: 1,
    uri: '/movies/Alpha.mp4',
    path: '/movies/Alpha.mp4',
    fileName: 'Alpha.mp4',
    displayName: 'Alpha',
    isVideo: true,
    durationMs: 60000,
  ),
  MediaItem(
    id: 2,
    uri: '/movies/Beta.mp4',
    path: '/movies/Beta.mp4',
    fileName: 'Beta.mp4',
    displayName: 'Beta',
    isVideo: true,
  ),
  MediaItem(
    id: 3,
    uri: '/downloads/Gamma.mp4',
    path: '/downloads/Gamma.mp4',
    fileName: 'Gamma.mp4',
    displayName: 'Gamma',
    isVideo: true,
  ),
];

Future<void> _pump(WidgetTester tester, {LibraryPrefs prefs = const LibraryPrefs()}) async {
  final router = GoRouter(
    initialLocation: '/videos',
    routes: [
      GoRoute(path: '/videos', builder: (context, state) => const VideosScreen()),
      GoRoute(
        path: '/media-folder',
        builder: (context, state) =>
            const Scaffold(body: Text('FOLDER_CONTENTS')),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const Scaffold(body: Text('SEARCH_PAGE')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        videosControllerProvider
            .overrideWith(() => _FakeVideosController(_videos)),
        libraryPrefsProvider
            .overrideWith(() => _FakePrefsController(prefs)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('VideosScreen folders view', () {
    testWidgets('groups videos into folders with counts', (tester) async {
      await _pump(tester, prefs: const LibraryPrefs(view: 'folders'));

      expect(find.byType(FolderTile), findsNWidgets(2));
      expect(find.text('movies'), findsOneWidget);
      expect(find.text('downloads'), findsOneWidget);
      expect(find.text('2 videos'), findsOneWidget);
      expect(find.text('1 video'), findsOneWidget);
      // Folders view — no item cards yet.
      expect(find.byType(MediaGridView), findsNothing);
      expect(find.byType(MediaListView), findsNothing);
    });

    testWidgets('bigger folder is listed first', (tester) async {
      await _pump(tester, prefs: const LibraryPrefs(view: 'folders'));

      final tiles = tester.widgetList<FolderTile>(find.byType(FolderTile));
      expect(tiles.first.folder.name, 'movies');
      expect(tiles.last.folder.name, 'downloads');
    });

    testWidgets('tapping a folder opens its contents', (tester) async {
      await _pump(tester, prefs: const LibraryPrefs(view: 'folders'));
      await tester.tap(find.byType(FolderTile).first);
      await tester.pumpAndSettle();
      expect(find.text('FOLDER_CONTENTS'), findsOneWidget);
    });
  });

  group('VideosScreen layout toggle', () {
    testWidgets('All segment shows the videos as a grid', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(find.byType(MediaGridView), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Gamma'), findsOneWidget);
      expect(find.byType(FolderTile), findsNothing);
    });

    testWidgets('list icon switches grid → list', (tester) async {
      await _pump(tester, prefs: const LibraryPrefs(view: 'all'));
      expect(find.byType(MediaGridView), findsOneWidget);

      await tester.tap(find.byTooltip('List view'));
      await tester.pumpAndSettle();

      expect(find.byType(MediaListView), findsOneWidget);
      expect(find.byType(MediaGridView), findsNothing);
      expect(find.byType(ListTile), findsNWidgets(3));
      // The toggle now offers the way back.
      expect(find.byTooltip('Grid view'), findsOneWidget);
    });

    testWidgets('remembered prefs are applied on open', (tester) async {
      await _pump(
        tester,
        prefs: const LibraryPrefs(layout: 'list', view: 'all'),
      );
      expect(find.byType(MediaListView), findsOneWidget);
      expect(find.byType(FolderTile), findsNothing);
      // Layout toggle is offered in the All view.
      expect(find.byTooltip('Grid view'), findsOneWidget);
    });
  });

  group('VideosScreen folders switcher', () {
    testWidgets('Folders segment returns to the folders view', (tester) async {
      await _pump(tester, prefs: const LibraryPrefs(view: 'all'));
      expect(find.byType(FolderTile), findsNothing);

      await tester.tap(find.text('Folders'));
      await tester.pumpAndSettle();

      expect(find.byType(FolderTile), findsNWidgets(2));
    });
  });
}
