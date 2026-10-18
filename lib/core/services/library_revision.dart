import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Per-section revisions let library screens refresh only changed data.
class LibraryRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final videoLibraryRevisionProvider = NotifierProvider<LibraryRevision, int>(
  LibraryRevision.new,
);
final audioLibraryRevisionProvider = NotifierProvider<LibraryRevision, int>(
  LibraryRevision.new,
);
final playlistLibraryRevisionProvider = NotifierProvider<LibraryRevision, int>(
  LibraryRevision.new,
);
