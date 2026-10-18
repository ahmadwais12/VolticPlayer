import 'package:equatable/equatable.dart';

/// Core media entity used across video & audio (Unified Media Item).
/// Audio-only metadata fields are nullable and only populated for songs.
class MediaItem extends Equatable {
  final int? id;
  final String uri;
  final String path;
  final String fileName;
  final String displayName;
  final String extension;
  final int size;
  final int durationMs;
  final bool isVideo;
  final bool isAudio;
  final bool isFavorite;
  final DateTime? createdAt;
  final DateTime? modifiedAt;
  final DateTime? lastScannedAt;
  final String? thumbnailPath;

  // Audio metadata
  final String? artist;
  final String? album;
  final String? albumArtist;
  final String? genre;
  final int? year;
  final int? trackNumber;

  const MediaItem({
    this.id,
    required this.uri,
    this.path = '',
    required this.fileName,
    required this.displayName,
    this.extension = '',
    this.size = 0,
    this.durationMs = 0,
    this.isVideo = false,
    this.isAudio = false,
    this.isFavorite = false,
    this.createdAt,
    this.modifiedAt,
    this.lastScannedAt,
    this.thumbnailPath,
    this.artist,
    this.album,
    this.albumArtist,
    this.genre,
    this.year,
    this.trackNumber,
  });

  MediaItem copyWith({
    int? id,
    String? uri,
    String? path,
    String? fileName,
    String? displayName,
    String? extension,
    int? size,
    int? durationMs,
    bool? isVideo,
    bool? isAudio,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? modifiedAt,
    DateTime? lastScannedAt,
    String? thumbnailPath,
    String? artist,
    String? album,
    String? albumArtist,
    String? genre,
    int? year,
    int? trackNumber,
  }) {
    return MediaItem(
      id: id ?? this.id,
      uri: uri ?? this.uri,
      path: path ?? this.path,
      fileName: fileName ?? this.fileName,
      displayName: displayName ?? this.displayName,
      extension: extension ?? this.extension,
      size: size ?? this.size,
      durationMs: durationMs ?? this.durationMs,
      isVideo: isVideo ?? this.isVideo,
      isAudio: isAudio ?? this.isAudio,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      lastScannedAt: lastScannedAt ?? this.lastScannedAt,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtist: albumArtist ?? this.albumArtist,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      trackNumber: trackNumber ?? this.trackNumber,
    );
  }

  @override
  List<Object?> get props => [
        id,
        uri,
        path,
        fileName,
        displayName,
        extension,
        size,
        durationMs,
        isVideo,
        isAudio,
        isFavorite,
        thumbnailPath,
        artist,
        album,
      ];
}
