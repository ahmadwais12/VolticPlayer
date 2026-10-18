import 'dart:io';

/// Validates that a downloaded file really is the media type it claims
/// to be (prompt §16: "Never trust the original extension.
/// Detect the actual resulting file type. Validate generated files before
/// making them available for download.").
///
/// This is a lightweight content sniff — it protects against servers that
/// return an HTML error page (or other markup) with a `200` status while a
/// `.mp3` / `.mp4` filename is requested. It is intentionally conservative:
/// unknown binary payloads pass, markup and empty files fail.
class FileTypeValidator {
  FileTypeValidator._();

  /// Reads the first [sampleSize] bytes of [file] and checks them against
  /// markup signatures that must never appear in a media file.
  static Future<FileValidationResult> validate(
    File file, {
    int sampleSize = 512,
  }) async {
    if (!await file.exists()) {
      return const FileValidationResult(false, 'The downloaded file is missing.');
    }
    final length = await file.length();
    if (length == 0) {
      return const FileValidationResult(
        false,
        'The downloaded file is empty.',
      );
    }

    final raf = await file.open();
    List<int> bytes;
    try {
      final count = length < sampleSize ? length : sampleSize;
      bytes = await raf.read(count);
    } finally {
      await raf.close();
    }

    final text = String.fromCharCodes(
      bytes.map((b) => b < 128 ? b : 0x20),
    ).trimLeft().toLowerCase();

    if (text.startsWith('<!doctype html') ||
        text.startsWith('<html') ||
        text.startsWith('<?xml') ||
        text.startsWith('<head') ||
        text.startsWith('<body') ||
        text.startsWith('{')) {
      return const FileValidationResult(
        false,
        'The server returned a web page instead of a media file.',
      );
    }

    return FileValidationResult(true, null, detectedType: _detect(bytes));
  }

  static String? _detect(List<int> bytes) {
    if (bytes.length >= 12 &&
        bytes[4] == 0x66 && // 'f'
        bytes[5] == 0x74 && // 't'
        bytes[6] == 0x79 && // 'y'
        bytes[7] == 0x70) {
      // ISO BMFF: mp4 / m4a / mov
      return 'mp4';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0x49 && // 'I'
        bytes[1] == 0x44 && // 'D'
        bytes[2] == 0x33) {
      return 'mp3';
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0) {
      return 'mp3';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x52 && // 'R'
        bytes[1] == 0x49 && // 'I'
        bytes[2] == 0x46 && // 'F'
        bytes[3] == 0x46) {
      // RIFF: wav / avi
      return 'riff';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x4F && // 'O'
        bytes[1] == 0x67 && // 'g'
        bytes[2] == 0x67 && // 'g'
        bytes[3] == 0x53) {
      return 'ogg';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x66 && // 'f'
        bytes[1] == 0x4C && // 'L'
        bytes[2] == 0x61 && // 'a'
        bytes[3] == 0x43) {
      return 'flac';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x1A &&
        bytes[1] == 0x45 &&
        bytes[2] == 0xDF &&
        bytes[3] == 0xA3) {
      // Matroska / WebM
      return 'matroska';
    }
    return null;
  }
}

class FileValidationResult {
  const FileValidationResult(this.isValid, this.error, {this.detectedType});

  final bool isValid;
  final String? error;

  /// Best-effort content type derived from magic bytes, when recognized.
  final String? detectedType;
}
