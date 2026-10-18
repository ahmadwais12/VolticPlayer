import 'package:flutter_test/flutter_test.dart';
import 'package:voltic_player/core/services/video_downloader_service.dart';

void main() {
  group('VideoDownloaderService URL validation', () {
    final service = VideoDownloaderService();

    tearDownAll(service.dispose);

    test('accepts public HTTPS URLs', () {
      expect(
        service.isSupportedUrl('https://media.example.com/video.mp4'),
        isTrue,
      );
      expect(service.isSupportedUrl('https://8.8.8.8/media.mp4'), isTrue);
    });

    test('rejects insecure, malformed, and credentialed URLs', () {
      expect(
        service.isSupportedUrl('http://media.example.com/video.mp4'),
        isFalse,
      );
      expect(service.isSupportedUrl('not a URL'), isFalse);
      expect(
        service.isSupportedUrl('https://user:password@media.example.com/file'),
        isFalse,
      );
    });

    test('rejects localhost, internal hostnames, and private addresses', () {
      expect(service.isSupportedUrl('https://localhost/video.mp4'), isFalse);
      expect(service.isSupportedUrl('https://nas.local/video.mp4'), isFalse);
      expect(service.isSupportedUrl('https://127.0.0.1/video.mp4'), isFalse);
      expect(service.isSupportedUrl('https://10.0.0.8/video.mp4'), isFalse);
      expect(service.isSupportedUrl('https://192.168.1.2/video.mp4'), isFalse);
      expect(service.isSupportedUrl('https://169.254.169.254/latest'), isFalse);
      expect(service.isSupportedUrl('https://[::1]/video.mp4'), isFalse);
    });

    test('rejects non-HTTP schemes and unsupported schemes', () {
      expect(service.isSupportedUrl('file:///etc/passwd'), isFalse);
      expect(service.isSupportedUrl('ftp://files.example.com/v.mp4'), isFalse);
      expect(service.isSupportedUrl('javascript:alert(1)'), isFalse);
      expect(service.isSupportedUrl('rtsp://cam.example.com/stream'), isFalse);
      expect(service.isSupportedUrl(''), isFalse);
      expect(service.isSupportedUrl('https://'), isFalse);
    });

    test('blocks cloud metadata endpoints and CGNAT ranges', () {
      expect(service.isSupportedUrl('https://100.64.0.1/v.mp4'), isFalse);
      expect(service.isSupportedUrl('https://0.0.0.0/v.mp4'), isFalse);
      expect(service.isSupportedUrl('https://[fd00::1]/v.mp4'), isFalse);
      expect(service.isSupportedUrl('https://224.0.0.1/v.mp4'), isFalse);
    });

    test('validatePublicDestination rejects private literal destinations',
        () async {
      await expectLater(
        service.validatePublicDestination('https://127.0.0.1/file.mp4'),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        service.validatePublicDestination('https://169.254.169.254/latest'),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        service.validatePublicDestination('https://[::1]/file.mp4'),
        throwsA(isA<FormatException>()),
      );
    });

    test('validatePublicDestination accepts public literal destinations',
        () async {
      // 8.8.8.8 is a public address; no DNS lookup is needed.
      await expectLater(
        service.validatePublicDestination('https://8.8.8.8/file.mp4'),
        completes,
      );
    });
  });
}
