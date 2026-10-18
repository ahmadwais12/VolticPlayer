import 'package:equatable/equatable.dart';

/// A user-created bookmark at a specific position in a media file.
class BookmarkItem extends Equatable {
  final int? id;
  final int mediaId;
  final int positionMs;
  final String? title;
  final String? note;
  final DateTime createdAt;

  const BookmarkItem({
    this.id,
    required this.mediaId,
    this.positionMs = 0,
    this.title,
    this.note,
    required this.createdAt,
  });

  BookmarkItem copyWith({
    int? id,
    int? mediaId,
    int? positionMs,
    String? title,
    String? note,
    DateTime? createdAt,
  }) =>
      BookmarkItem(
        id: id ?? this.id,
        mediaId: mediaId ?? this.mediaId,
        positionMs: positionMs ?? this.positionMs,
        title: title ?? this.title,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
      );

  String get positionFormatted {
    final h = positionMs ~/ 3600000;
    final m = (positionMs % 3600000) ~/ 60000;
    final s = (positionMs % 60000) ~/ 1000;
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [id, mediaId, positionMs, title, note, createdAt];
}
