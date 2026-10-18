import 'package:drift/drift.dart';

import '../../domain/entities/media_item.dart';
import '../../domain/entities/library_entities.dart';
import 'app_database.dart';

extension MediaItemRowX on MediaItemRow {
  MediaItem toEntity() => MediaItem(
        id: id,
        uri: uri,
        path: path,
        fileName: fileName,
        displayName: displayName,
        extension: extension,
        size: size,
        durationMs: durationMs,
        isVideo: isVideo,
        isAudio: isAudio,
        isFavorite: isFavorite,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        lastScannedAt: lastScannedAt,
        thumbnailPath: thumbnailPath,
        artist: artist,
        album: album,
        albumArtist: albumArtist,
        genre: genre,
        year: year,
        trackNumber: trackNumber,
      );

  MediaItemsCompanion toCompanion() => MediaItemsCompanion(
        id: Value(id),
        uri: Value(uri),
        path: Value(path),
        fileName: Value(fileName),
        displayName: Value(displayName),
        extension: Value(extension),
        size: Value(size),
        durationMs: Value(durationMs),
        isVideo: Value(isVideo),
        isAudio: Value(isAudio),
        isFavorite: Value(isFavorite),
        createdAt: Value(createAtOrNow(createdAt)),
        modifiedAt: Value(modifiedAt),
        lastScannedAt: Value(lastScannedAt),
        thumbnailPath: Value(thumbnailPath),
        artist: Value(artist),
        album: Value(album),
        albumArtist: Value(albumArtist),
        genre: Value(genre),
        year: Value(year),
        trackNumber: Value(trackNumber),
      );
}

DateTime createAtOrNow(DateTime? v) => v ?? DateTime.now();

/// Builds a Drift companion directly from a domain [MediaItem].
extension MediaItemX on MediaItem {
  MediaItemsCompanion toCompanion() => MediaItemsCompanion(
        id: id == null ? const Value.absent() : Value(id!),
        uri: Value(uri),
        path: Value(path),
        fileName: Value(fileName),
        displayName: Value(displayName),
        extension: Value(extension),
        size: Value(size),
        durationMs: Value(durationMs),
        isVideo: Value(isVideo),
        isAudio: Value(isAudio),
        isFavorite: Value(isFavorite),
        createdAt: Value(createdAt ?? DateTime.now()),
        modifiedAt: Value(modifiedAt),
        lastScannedAt: Value(lastScannedAt),
        thumbnailPath: Value(thumbnailPath),
        artist: Value(artist),
        album: Value(album),
        albumArtist: Value(albumArtist),
        genre: Value(genre),
        year: Value(year),
        trackNumber: Value(trackNumber),
      );
}

extension HistoryRowX on HistoryRow {
  HistoryEntry toEntity() => HistoryEntry(
        id: id,
        mediaId: mediaId,
        lastPositionMs: lastPositionMs,
        durationMs: durationMs,
        playedAt: playedAt,
        completed: completed,
        playCount: playCount,
      );
}

extension PlaylistRowX on PlaylistRow {
  Playlist toEntity() => Playlist(
        id: id,
        name: name,
        type: type,
        description: description,
        coverPath: coverPath,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
