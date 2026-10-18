# media_metadata

A Flutter plugin to read (and partially write) metadata from media files (audio and video) on **Android**, **iOS**, **macOS**, **Windows**, and **Linux**.

## Fields returned

### `Metadata`

| Field           | Type              | Description                                          |
|------------------|-------------------|-------------------------------------------------------|
| `title`          | `String?`         | Title tag                                              |
| `duration`        | `Duration?`       | Total duration                                         |
| `artist`          | `String?`         | Primary artist                                         |
| `album`           | `String?`         | Album name                                             |
| `albumArtist`     | `String?`         | Album artist                                           |
| `trackNumber`     | `int?`            | Track number                                           |
| `trackTotal`      | `int?`            | Total tracks on the album                              |
| `discNumber`      | `int?`            | Disc number                                            |
| `discTotal`       | `int?`            | Total discs                                            |
| `year`            | `int?`            | Release year                                           |
| `genre`           | `String?`         | Genre                                                  |
| `comment`         | `String?`         | Free-text comment tag (ID3 `COMM`, iTunes `©cmt`, ...) |
| `imageMetadata`   | `ImageMetadata?`  | Artwork / thumbnail, see below                         |
| `fileSize`        | `BigInt?`         | File size in bytes                                     |
| `sampleRate`      | `int?`            | Audio sample rate, in Hz                                |
| `audioBitrate`    | `int?`            | Audio bitrate, in bits per second                       |
| `audioChannels`   | `int?`            | Number of audio channels                                |
| `bitsPerSample`   | `int?`            | Audio bit depth, when available                         |
| `audioCodec`      | `String?`         | Audio codec identifier (platform-dependent format)      |
| `videoCodec`      | `String?`         | Video codec identifier (platform-dependent format)      |
| `videoBitrate`    | `int?`            | Video bitrate, in bits per second                        |
| `frameRate`       | `double?`         | Video frame rate, in frames per second                   |
| `videoWidth`      | `int?`            | Video frame width, in pixels                              |
| `videoHeight`     | `int?`            | Video frame height, in pixels                             |

### `ImageMetadata`

All image data — embedded artwork, a generated video thumbnail, or a standalone image file's own content — is exposed through a single `ImageMetadata` object on `metadata.imageMetadata`.

| Field           | Type          | Description                                                              |
|------------------|---------------|----------------------------------------------------------------------------|
| `data`           | `Uint8List?`  | Raw encoded image bytes                                                    |
| `type`           | `String?`     | Image type, e.g. `"jpeg"`, `"png"`, `"heic"`, `"webp"`                     |
| `fileSizeBytes`  | `int?`        | Size of the encoded image data, in bytes                                    |
| `width`          | `int?`        | Pixel width                                                                 |
| `height`         | `int?`        | Pixel height                                                                |
| `description`    | `String?`     | EXIF `UserComment` / IPTC caption / similar, when available                |
| `isGenerated`    | `bool`        | `true` if this picture was generated from a video frame (see below), `false` for a real embedded cover or a standalone image file |

## Usage

```dart
import 'package:media_metadata/media_metadata.dart';

// Read metadata from a file path
final metadata = await MediaMetadata.read('/storage/emulated/0/Music/song.mp3');

if (metadata != null) {
  print(metadata.title);       // "Bohemian Rhapsody"
  print(metadata.artist);      // "Queen"
  print(metadata.album);       // "A Night at the Opera"
  print(metadata.duration);    // Duration(minutes: 5, seconds: 55)
  print(metadata.year);        // 1975
  print(metadata.trackNumber); // 11
  print(metadata.comment);     // any free-text comment tag
  print(metadata.audioCodec);  // e.g. "MP3", "AAC"
  print(metadata.sampleRate);  // e.g. 44100

  // Display the album art
  final art = metadata.imageMetadata;
  if (art?.data != null) {
    Image.memory(art!.data!);
    print('${art.type} ${art.width}x${art.height}, generated: ${art.isGenerated}');
  }
}

// Write metadata back to a file
final success = await MediaMetadata.write(
  '/storage/emulated/0/Pictures/photo.jpg',
  Metadata(title: 'Vacation', artist: 'Unknown', year: 2024),
);
if (success) {
  print('Metadata written successfully');
}

// Check if a file is supported before reading
if (MediaMetadata.isSupported('/path/to/file.mp3')) {
  // supported
}
```

### Generating a thumbnail for videos without cover art (`createThumbnail`)

Many video files simply don't have an embedded cover (unlike most music files). Pass `createThumbnail: true` to have the plugin capture a real frame from the video — the same kind of image a file explorer or media player would show — whenever no real embedded artwork is found:

```dart
final metadata = await MediaMetadata.read(
  '/storage/emulated/0/Movies/clip.mp4',
  createThumbnail: true,
);

final art = metadata?.imageMetadata;
if (art?.data != null) {
  Image.memory(art!.data!);
  if (art.isGenerated) {
    // This is a captured video frame, not a real embedded cover.
  }
}
```

Notes:

- `createThumbnail` only has an effect for **video** files (`.mp4`, `.mkv`, `.3gp`, `.3gpp`, `.mov`) that have **no real embedded artwork**. If a real cover is found, it is always returned as-is and `isGenerated` stays `false`.
- It is `false` by default, since generating a thumbnail (decoding/seeking into the video) is significantly more expensive than reading existing tags.
- The plugin never fabricates a generic file-type/media-player icon as a substitute for missing artwork — `createThumbnail` always captures genuine video content, or returns nothing.
- Generated thumbnails (`isGenerated == true`) are intentionally **not** written back by `MediaMetadata.write` even if you pass them along in an updated `Metadata`, to avoid accidentally saving a generated frame as if it were a real cover.

## Write support

The `MediaMetadata.write` API writes the metadata fields supported by the current platform and returns `true` when the operation succeeds.

Supported platforms:

- **Android**: audio tags via ID3v2 (best-effort) for `.mp3`; image metadata via `ExifInterface` for `.jpg`, `.jpeg`, `.png`, `.webp`, `.heic`
- **Windows**: file metadata via the Shell Property Store, including `comment` and the album cover (`imageMetadata.data`)
- **Linux**: audio metadata (including `comment`) via TagLib when available
- **iOS / macOS**: currently not supported; the API returns `false`

Technical audio/video info (`sampleRate`, `audioBitrate`, `videoCodec`, `frameRate`, ...) is always derived from the encoded stream itself and is **read-only** on every platform — it is never written back.

## Setup

### Android

Add the following permissions to your `AndroidManifest.xml`:

```xml
<!-- Android < 13 -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />

<!-- Android 13+ -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
```

Request the permission at runtime using `permission_handler` or another package.

The plugin uses Android's built-in `MediaMetadataRetriever` and `MediaExtractor` — **no extra dependencies required** beyond `androidx.exifinterface` (added automatically by the plugin's `build.gradle`). `createThumbnail` uses `MediaMetadataRetriever.getFrameAtTime`, also built-in.

### iOS / macOS

No additional setup needed. Uses `AVFoundation` and `ImageIO` (both system frameworks). `createThumbnail` uses `AVAssetImageGenerator`.

### Windows

Uses the Windows Shell Property Store (`IPropertyStore`) and Media Foundation for tags and technical info, plus direct parsing of ID3v2/MP4 atoms for embedded artwork (no dependency on system thumbnail handlers). Requires Windows 10 or later. No extra SDKs needed — links against `propsys`, `mfplat`, `mfreadwrite`, `shlwapi`, and `windowscodecs`.

`createThumbnail` uses `IShellItemImageFactory` — the same mechanism Explorer uses to show video thumbnails — but only ever for videos, and only when explicitly requested.

### Linux

Uses **TagLib** for metadata extraction. Install the development package:

```bash
sudo apt install libtag1-dev   # Debian/Ubuntu
sudo dnf install taglib-devel  # Fedora
```

The plugin will compile without TagLib but will only return file sizes in that case.

`createThumbnail` shells out to `ffmpeg` if it's installed on the system:

```bash
sudo apt install ffmpeg
```

If `ffmpeg` isn't found, `createThumbnail` simply has no effect (no thumbnail is generated) — it never falls back to a generic icon.

## Platform notes

| Platform | Library used                                   | Real embedded artwork | `createThumbnail` mechanism            |
|----------|--------------------------------------------------|------------------------|------------------------------------------|
| Android  | `MediaMetadataRetriever` + `MediaExtractor` + `ExifInterface` | ✅ | `MediaMetadataRetriever.getFrameAtTime` |
| iOS      | `AVFoundation` + `ImageIO`                        | ✅                      | `AVAssetImageGenerator`                  |
| macOS    | `AVFoundation` + `ImageIO`                        | ✅                      | `AVAssetImageGenerator`                  |
| Windows  | Shell Property Store + Media Foundation + direct ID3v2/MP4 parsing + WIC | ✅ (ID3 `APIC` / MP4 `covr`, `PKEY_ThumbnailStream` fallback) | `IShellItemImageFactory` |
| Linux    | TagLib (+ `ffmpeg` subprocess for thumbnails)     | ✅ (ID3v2 `APIC` only)  | `ffmpeg` (if installed)                  |

On every platform, real embedded artwork is always preferred over a generated thumbnail, and a generated thumbnail is never produced for audio files or silently substituted with a generic icon.
