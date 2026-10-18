import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:voltic_player/core/services/download_manager.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
  @override
  Future<String?> getTemporaryPath() async => dir;
  @override
  Future<String?> getApplicationSupportPath() async => dir;
}

void main() {
  test('DownloadManager completes a range download using bounded chunks',
      () async {
    final tmp = await Directory.systemTemp.createTemp('dmtest');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    addTearDown(() async {
      // Windows can lag releasing the just-written file handle; cleanup is
      // best-effort so it never masks a real assertion failure.
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    });

    // 3 MiB payload with a non-markup byte pattern.
    final payload = List<int>.generate(3 * 1024 * 1024, (i) => (i % 251) + 1);

    var rangeRequests = 0;
    var unboundedGets = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      if (req.method == 'HEAD') {
        req.response
          ..statusCode = 200
          ..headers.set(
            HttpHeaders.contentLengthHeader,
            payload.length.toString(),
          )
          ..headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
        await req.response.close();
        return;
      }
      final range = req.headers.value(HttpHeaders.rangeHeader);
      if (range != null) {
        rangeRequests++;
        final m = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range)!;
        final start = int.parse(m.group(1)!);
        final end = m.group(2)!.isEmpty
            ? payload.length - 1
            : int.parse(m.group(2)!);
        req.response
          ..statusCode = 206
          ..headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes $start-$end/${payload.length}',
          )
          ..headers.set(
            HttpHeaders.contentLengthHeader,
            (end - start + 1).toString(),
          )
          ..add(payload.sublist(start, end + 1));
        await req.response.close();
        return;
      }
      // Unbounded GET: emulate a throttling host that never finishes in time.
      unboundedGets++;
      req.response
        ..statusCode = 200
        ..headers.set(
          HttpHeaders.contentLengthHeader,
          payload.length.toString(),
        )
        ..headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      for (var i = 0; i < payload.length; i += 2048) {
        final e = (i + 2048).clamp(0, payload.length);
        req.response.add(payload.sublist(i, e));
        await req.response.flush();
        await Future.delayed(const Duration(milliseconds: 50));
      }
      await req.response.close();
    });
    addTearDown(() => server.close(force: true));

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final url = 'http://127.0.0.1:${server.port}/media.bin';

    await container.read(downloadManagerProvider.notifier).download(
      uri: url,
      fileName: 'media.bin',
      title: 'Test media',
      mediaType: 'video',
      skipUrlValidation: true,
    );

    final deadline = DateTime.now().add(const Duration(seconds: 25));
    DownloadItem? item;
    while (DateTime.now().isBefore(deadline)) {
      item = container.read(downloadManagerProvider).findByUri(url);
      if (item != null &&
          (item.isCompleted || item.status == DownloadStatus.failed)) {
        break;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    expect(item, isNotNull);
    expect(
      item!.status,
      DownloadStatus.completed,
      reason: 'download failed: ${item.error}',
    );
    expect(rangeRequests, greaterThan(0), reason: 'must fetch via Range chunks');
    expect(unboundedGets, 0, reason: 'must not rely on a throttled full GET');
    expect(item.progress, 1.0);
    expect(item.totalBytes, payload.length);

    final file = File(item.filePath!);
    expect(await file.exists(), isTrue);
    expect(await file.length(), payload.length);
    expect(await file.readAsBytes(), payload);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test(
    'DownloadManager falls through to ranged GET when HEAD/plain GET 403 '
    '(googlevideo behaviour)',
    () async {
      final tmp = await Directory.systemTemp.createTemp('dmgv');
      PathProviderPlatform.instance = _FakePathProvider(tmp.path);
      addTearDown(() async {
        try {
          await tmp.delete(recursive: true);
        } catch (_) {}
      });

      final payload = List<int>.generate(
        2 * 1024 * 1024 + 12345,
        (i) => (i % 199) + 1,
      );

      var headRequests = 0;
      var plainGets = 0;
      var rangeRequests = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        // googlevideo rejects HEAD outright.
        if (req.method == 'HEAD') {
          headRequests++;
          req.response.statusCode = 403;
          await req.response.close();
          return;
        }
        final range = req.headers.value(HttpHeaders.rangeHeader);
        // googlevideo also rejects a plain, range-less GET.
        if (range == null) {
          plainGets++;
          req.response.statusCode = 403;
          await req.response.close();
          return;
        }
        // ...but serves ranged GETs with 206.
        rangeRequests++;
        final m = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range)!;
        final start = int.parse(m.group(1)!);
        final end = m.group(2)!.isEmpty
            ? payload.length - 1
            : int.parse(m.group(2)!);
        req.response
          ..statusCode = 206
          ..headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes $start-$end/${payload.length}',
          )
          ..headers.set(
            HttpHeaders.contentLengthHeader,
            (end - start + 1).toString(),
          )
          ..add(payload.sublist(start, end + 1));
        await req.response.close();
      });
      addTearDown(() => server.close(force: true));

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final url = 'http://127.0.0.1:${server.port}/videoplayback';

      await container.read(downloadManagerProvider.notifier).download(
        uri: url,
        fileName: 'media.bin',
        title: 'googlevideo test',
        mediaType: 'video',
        skipUrlValidation: true,
      );

      final deadline = DateTime.now().add(const Duration(seconds: 25));
      DownloadItem? item;
      while (DateTime.now().isBefore(deadline)) {
        item = container.read(downloadManagerProvider).findByUri(url);
        if (item != null &&
            (item.isCompleted || item.status == DownloadStatus.failed)) {
          break;
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }

      expect(item, isNotNull);
      expect(
        item!.status,
        DownloadStatus.completed,
        reason: 'download failed: ${item.error}',
      );
      expect(headRequests, greaterThan(0), reason: 'HEAD must be attempted');
      expect(
        rangeRequests,
        greaterThan(1),
        reason: 'probe (bytes=0-0) + chunk fetches must use Range',
      );
      expect(
        plainGets,
        0,
        reason: 'must never fall back to a range-less GET that 403s',
      );
      expect(item.progress, 1.0);
      expect(item.totalBytes, payload.length);

      final file = File(item.filePath!);
      expect(await file.exists(), isTrue);
      expect(await file.length(), payload.length);
      expect(await file.readAsBytes(), payload);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
