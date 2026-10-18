import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voltic_player/core/services/file_type_validator.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fv_validator_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<File> write(String name, List<int> bytes) async {
    final file = File('${tempDir.path}/$name');
    await file.writeAsBytes(bytes);
    return file;
  }

  group('FileTypeValidator (§16)', () {
    test('accepts a file with an MP3 ID3 header', () async {
      final file = await write('song.part', [
        0x49, 0x44, 0x33, // 'ID3'
        ...List.filled(64, 0x20),
      ]);
      final result = await FileTypeValidator.validate(file);
      expect(result.isValid, isTrue);
      expect(result.detectedType, 'mp3');
    });

    test('accepts an ISO BMFF (mp4) file', () async {
      final file = await write(
        'video.part',
        [0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, ...List.filled(64, 0)],
      );
      final result = await FileTypeValidator.validate(file);
      expect(result.isValid, isTrue);
      expect(result.detectedType, 'mp4');
    });

    test('rejects an HTML error page disguised as media', () async {
      final file = await write(
        'fake.mp3.part',
        '<!DOCTYPE html><html><body>404 Not Found</body></html>'.codeUnits,
      );
      final result = await FileTypeValidator.validate(file);
      expect(result.isValid, isFalse);
      expect(result.error, contains('web page'));
    });

    test('rejects an empty download', () async {
      final file = await write('empty.part', const []);
      final result = await FileTypeValidator.validate(file);
      expect(result.isValid, isFalse);
      expect(result.error, contains('empty'));
    });

    test('rejects a missing file', () async {
      final result = await FileTypeValidator.validate(
        File('${tempDir.path}/gone.part'),
      );
      expect(result.isValid, isFalse);
      expect(result.error, contains('missing'));
    });

    test('accepts unknown binary payloads (conservative)', () async {
      final file = await write('data.part', [0x01, 0x02, 0x03, 0x04, 0xFF]);
      final result = await FileTypeValidator.validate(file);
      expect(result.isValid, isTrue);
      expect(result.detectedType, isNull);
    });
  });
}
