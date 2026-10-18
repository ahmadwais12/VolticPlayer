import 'package:flutter_test/flutter_test.dart';
import 'package:voltic_player/features/library/presentation/controllers/library_prefs_controller.dart';

void main() {
  group('LibraryPrefs defaults', () {
    test('start in grid + all', () {
      const prefs = LibraryPrefs();
      expect(prefs.isGrid, isTrue);
      expect(prefs.isFolders, isFalse);
      expect(prefs.layout, 'grid');
      expect(prefs.view, 'all');
    });
  });

  group('LibraryPrefs.fromStorage', () {
    test('accepts stored values', () {
      final prefs = LibraryPrefs.fromStorage('list', 'all');
      expect(prefs.layout, 'list');
      expect(prefs.isGrid, isFalse);
      expect(prefs.view, 'all');
      expect(prefs.isFolders, isFalse);
    });

    test('falls back to defaults on junk or missing values', () {
      for (final layout in [null, '', 'tree', 42]) {
        for (final view in [null, '', 'grid', 7]) {
          final prefs = LibraryPrefs.fromStorage(layout, view);
          expect(prefs.layout, 'grid', reason: 'layout=$layout');
          expect(prefs.view, 'all', reason: 'view=$view');
        }
      }
    });
  });

  group('LibraryPrefs.copyWith', () {
    test('changes one field at a time', () {
      const prefs = LibraryPrefs();
      expect(prefs.copyWith(layout: 'list').layout, 'list');
      expect(prefs.copyWith(layout: 'list').view, 'all');
      expect(prefs.copyWith(view: 'folders').isFolders, isTrue);
      expect(prefs.copyWith(view: 'folders').layout, 'grid');
    });

    test('value equality', () {
      const a = LibraryPrefs(layout: 'list', view: 'all');
      const b = LibraryPrefs(layout: 'list', view: 'all');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == const LibraryPrefs(), isFalse);
    });
  });
}
