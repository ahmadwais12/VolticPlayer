## 2.2.2

- Fixed implicit coercion warnings by explicitly casting the image metadata dictionary as [String: Any?] and resolved a target compilation error on macOS 10.15 by replacing modern UTType APIs with legacy constants.

## 2.2.1

- Fixed implicit coercion warnings in MediaMetadataPlugin.swift by explicitly casting the image metadata dictionary as [String: Any?].

## 2.2.0

### Fixed
- **Compilation Errors (Linux):** 
  - Fixed a typo where `fl_value_int` was called instead of `fl_value_new_int` when setting the `bitsPerSample` property for MP4 files.
  - Resolved `no member named 'videoWidth' / 'videoHeight' in 'TagLib::MP4::Properties'` errors by removing the non-existent video property getters, as TagLib focuses exclusively on audio metadata.
  - Fixed an unclosed brace (`}`) and conditional block mismatch inside `read_media_metadata` that previously triggered `function definition is not allowed here` and `expected '}'` build failures.

## 2.1.0

### Dependency & Platform Updates
- **Dependencies:** Updated `FilePicker` version and removed the Web version in `pubspec.yaml`.
- **iOS / macOS:** Updated the `.podspec` files.
- **Windows:** The plugin now utilizes the **Shell Property Store** to read metadata.
- **Example App:** Fully updated to reflect all new features and changes.

### New Features & Thumbnail Generation
- **Video Thumbnails:** Added a new parameter to the read function to explicitly enable preview thumbnail generation for video metadata.
- **`ImageMetadata.isGenerated` Property:** - Returns `false` for genuine embedded cover art or standalone image files.
  - Returns `true` **only** for thumbnails generated from a video frame.
- **`createThumbnail` Parameter:** (Added to `MediaMetadata.read`, defaults to `false`):
  - This only triggers for video files that do not have actual embedded cover art.
- **Write Protection:** `MediaMetadata.write` now intentionally ignores any image marked with `isGenerated: true` to prevent saving a generated thumbnail as if it were genuine cover art.

### Platform-Specific Implementation Details
- **Android:** Uses `MediaMetadataRetriever.getFrameAtTime` for thumbnail generation.
- **iOS / macOS:** Uses `AVAssetImageGenerator` for thumbnail generation. Remove the PrivacyInfo file for remove the warning.
- **Windows:** Re-introduced `IShellItemImageFactory`—but **only** under the explicit `createThumbnail` flag and strictly for video extensions (never for audio, and never silently in the background).
- **Linux:** Spawns an `ffmpeg` subprocess if installed. If `ffmpeg` is missing, no thumbnail is generated (does not fall back to a generic icon).

### Documentation & UI
- **Example App UI:** Added a "Generate thumbnail for videos" toggle switch and a visual **"GENERATED"** badge on the thumbnail preview when applicable.
- **README:** Fully rewritten to accurately reflect the current state of the codebase (covering `ImageMetadata`, comments, technical audio/video fields, `createThumbnail`, and Linux `ffmpeg` setup instructions).

## 2.0.0

- iOS and macOS versions are now functional, and added metadata writing, which is partially functional and MIT Licence.

## 1.0.0

- Initial release of the applicatio
