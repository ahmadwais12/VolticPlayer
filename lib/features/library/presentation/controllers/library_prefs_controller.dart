import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';

/// Display preferences for the Videos / Music library sections.
///
/// Persisted in the existing Drift key/value `settings` table so the
/// chosen layout survives restarts.
class LibraryPrefs {
  /// 'grid' | 'list'
  final String layout;

  /// 'folders' | 'all'
  final String view;

  const LibraryPrefs({this.layout = 'grid', this.view = 'all'});

  bool get isGrid => layout == 'grid';
  bool get isFolders => view == 'folders';

  LibraryPrefs copyWith({String? layout, String? view}) =>
      LibraryPrefs(layout: layout ?? this.layout, view: view ?? this.view);

  /// Normalises raw stored strings; anything unknown falls back to defaults.
  factory LibraryPrefs.fromStorage(Object? layout, Object? view) =>
      LibraryPrefs(
        layout: layout == 'list' ? 'list' : 'grid',
        view: view == 'folders' ? 'folders' : 'all',
      );

  @override
  bool operator ==(Object other) =>
      other is LibraryPrefs && other.layout == layout && other.view == view;

  @override
  int get hashCode => Object.hash(layout, view);
}

class LibraryPrefsKeys {
  LibraryPrefsKeys._();
  static const layout = 'library_layout';
  static const view = 'library_view';
}

class LibraryPrefsController extends AsyncNotifier<LibraryPrefs> {
  @override
  Future<LibraryPrefs> build() async {
    final repo = ref.watch(settingsRepositoryProvider);
    final layout = await repo.getSetting<String>(
      LibraryPrefsKeys.layout,
      defaultValue: 'grid',
    );
    final view = await repo.getSetting<String>(
      LibraryPrefsKeys.view,
      defaultValue: 'all',
    );
    return LibraryPrefs.fromStorage(layout, view);
  }

  Future<void> _apply(LibraryPrefs next) async {
    state = AsyncData(next);
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setSetting(LibraryPrefsKeys.layout, next.layout);
    await repo.setSetting(LibraryPrefsKeys.view, next.view);
  }

  /// Grid ↔ list.
  Future<void> toggleLayout() async {
    final current = state.value ?? const LibraryPrefs();
    await _apply(current.copyWith(layout: current.isGrid ? 'list' : 'grid'));
  }

  /// Folders ↔ all items.
  Future<void> setView(String view) async {
    final current = state.value ?? const LibraryPrefs();
    if (view != 'folders' && view != 'all') return;
    if (current.view == view) return;
    await _apply(current.copyWith(view: view));
  }

  Future<void> showFolders() => setView('folders');

  Future<void> showAll() => setView('all');
}

final libraryPrefsProvider =
    AsyncNotifierProvider<LibraryPrefsController, LibraryPrefs>(
      LibraryPrefsController.new,
    );

/// Synchronous accessor: defaults while settings load or on error.
final libraryPrefsValueProvider = Provider<LibraryPrefs>(
  (ref) => ref.watch(libraryPrefsProvider).value ?? const LibraryPrefs(),
);
