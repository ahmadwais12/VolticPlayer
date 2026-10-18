import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the current multi-select state for media browsing screens.
class SelectionState {
  final Set<int> selected;

  const SelectionState({this.selected = const {}});

  bool get isSelecting => selected.isNotEmpty;

  int get count => selected.length;

  bool isSelected(int id) => selected.contains(id);

  @override
  bool operator ==(Object other) =>
      other is SelectionState && other.selected.length == selected.length &&
      other.selected.containsAll(selected);

  @override
  int get hashCode => Object.hashAll([...selected]);
}

/// Notifier that manages multi-selection of media items (videos/audio)
/// across the library screens. Only one screen is visible at a time, so a
/// single shared notifier is safe.
class SelectionController extends Notifier<SelectionState> {
  @override
  SelectionState build() => const SelectionState();

  void toggle(int id) {
    final s = {...state.selected};
    if (!s.add(id)) s.remove(id);
    state = SelectionState(selected: s);
  }

  void replaceAll(Iterable<int> ids) =>
      state = SelectionState(selected: ids.toSet());

  void selectAll(Iterable<int> ids) => replaceAll(ids);

  void clear() => state = const SelectionState();
}

final selectionControllerProvider =
    NotifierProvider<SelectionController, SelectionState>(
      SelectionController.new,
    );

/// Independent selection for the Playlists list screen.
final playlistSelectionControllerProvider =
    NotifierProvider<SelectionController, SelectionState>(
      SelectionController.new,
    );

/// Independent selection for playlist detail item rows.
final playlistDetailSelectionControllerProvider =
    NotifierProvider<SelectionController, SelectionState>(
      SelectionController.new,
    );
