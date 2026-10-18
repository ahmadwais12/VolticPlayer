import 'package:equatable/equatable.dart';

/// A persisted playback history entry for a media item.
class HistoryEntry extends Equatable {
  final int? id;
  final int mediaId;
  final int lastPositionMs;
  final int durationMs;
  final DateTime playedAt;
  final bool completed;
  final int playCount;

  const HistoryEntry({
    this.id,
    required this.mediaId,
    this.lastPositionMs = 0,
    this.durationMs = 0,
    required this.playedAt,
    this.completed = false,
    this.playCount = 1,
  });

  double get progress =>
      durationMs > 0 ? (lastPositionMs / durationMs).clamp(0.0, 1.0) : 0.0;

  @override
  List<Object?> get props =>
      [id, mediaId, lastPositionMs, durationMs, playedAt, completed, playCount];
}

/// A user-created playlist.
class Playlist extends Equatable {
  final int? id;
  final String name;
  final String type; // 'video' | 'audio' | 'mixed'
  final String? description;
  final String? coverPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Playlist({
    this.id,
    required this.name,
    this.type = 'mixed',
    this.description,
    this.coverPath,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props =>
      [id, name, type, description, coverPath, createdAt, updatedAt];
}

/// A browsable storage folder.
class Folder extends Equatable {
  final int? id;
  final String path;
  final String name;
  final int? parentId;
  final bool isExcluded;
  final bool isFavorite;

  const Folder({
    this.id,
    required this.path,
    required this.name,
    this.parentId,
    this.isExcluded = false,
    this.isFavorite = false,
  });

  @override
  List<Object?> get props => [id, path, name, parentId, isExcluded, isFavorite];
}
