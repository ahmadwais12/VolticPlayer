import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltic_player/core/services/download_manager.dart';
import 'package:voltic_player/core/services/video_downloader_service.dart';
import 'package:voltic_player/features/downloads/presentation/widgets/download_progress_card.dart';
import 'package:voltic_player/features/downloads/presentation/widgets/download_status_badge.dart';
import 'package:voltic_player/features/downloads/presentation/widgets/format_selector_card.dart';
import 'package:voltic_player/features/downloads/presentation/widgets/url_input_card.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

const _video1080 = MediaFormat(
  label: '1080p',
  quality: '1080p',
  fileSize: 99614720,
  url: 'https://media.example.com/v-1080.mp4',
);
const _video720 = MediaFormat(
  label: '720p',
  quality: '720p',
  fileSize: 57671680,
  url: 'https://media.example.com/v-720.mp4',
);
const _audio320 = MediaFormat(
  label: 'Audio (MP3 320kbps)',
  isAudioOnly: true,
  fileSize: 12582912,
  url: 'https://media.example.com/a-320.mp3',
);

void main() {
  group('UrlInputCard (§1)', () {
    testWidgets('renders exact placeholder and Download button',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var analyzed = 0;
      await tester.pumpWidget(
        _wrap(
          UrlInputCard(
            controller: controller,
            focusNode: FocusNode(),
            onAnalyze: () => analyzed++,
            onPaste: () {},
            onClear: () {},
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.text('Enter video or audio URL here'),
        findsOneWidget,
      );
      expect(find.text('Download'), findsOneWidget);

      await tester.tap(find.text('Download'));
      expect(analyzed, 1);
    });

    testWidgets('paste and clear controls fire their callbacks',
        (tester) async {
      final controller = TextEditingController(text: 'https://x.example/v');
      addTearDown(controller.dispose);
      var pasted = 0;
      var cleared = 0;
      await tester.pumpWidget(
        _wrap(
          UrlInputCard(
            controller: controller,
            focusNode: FocusNode(),
            onAnalyze: () {},
            onPaste: () => pasted++,
            onClear: () => cleared++,
            onChanged: (_) {},
          ),
        ),
      );

      await tester.tap(find.byTooltip('Paste from clipboard'));
      await tester.tap(find.byTooltip('Clear URL'));
      expect(pasted, 1);
      expect(cleared, 1);
    });

    testWidgets('analyze button is disabled while analyzing',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          UrlInputCard(
            controller: controller,
            focusNode: FocusNode(),
            analyzing: true,
            onAnalyze: () => fail('must not fire while analyzing'),
            onPaste: () {},
            onClear: () {},
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.text('Analyzing...'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('FormatSelectorCard (§4/§5)', () {
    Widget build({
      int tab = 0,
      bool videoEnabled = true,
      bool audioEnabled = true,
      List<MediaFormat> formats = const [
        _video1080,
        _video720,
        _audio320,
      ],
      void Function(int)? onTabChanged,
    }) => _wrap(
      FormatSelectorCard(
        metadata: MediaMetadata(
          title: 'Example Video',
          sourceUrl: 'https://example.com/watch?v=1',
          formats: formats,
        ),
        activeTab: tab,
        onTabChanged: onTabChanged ?? (_) {},
        onSelect: (_) {},
        onDownload: (_) {},
        videoEnabled: videoEnabled,
        audioEnabled: audioEnabled,
      ),
    );

    testWidgets('video tab lists only actual video formats', (tester) async {
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      expect(find.text('1080p'), findsOneWidget);
      expect(find.text('720p'), findsOneWidget);
      expect(find.text('Audio (MP3 320kbps)'), findsNothing);
      // One Download button per available format.
      expect(find.text('Download'), findsNWidgets(2));
      // Real sizes, no invented qualities.
      expect(find.textContaining('95.0 MB'), findsOneWidget);
      expect(find.textContaining('55.0 MB'), findsOneWidget);
      expect(find.text('4K'), findsNothing);
    });

    testWidgets('audio tab shows bitrate only when the source states it',
        (tester) async {
      await tester.pumpWidget(build(tab: 1));
      await tester.pumpAndSettle();

      expect(find.text('Audio (MP3 320kbps)'), findsOneWidget);
      expect(find.text('MP3 • 320kbps • 12.0 MB'), findsOneWidget);
      expect(find.text('1080p'), findsNothing);
      // Never advertise a bitrate the source did not provide.
      expect(find.textContaining('128kbps'), findsNothing);
      expect(find.textContaining('256kbps'), findsNothing);
    });

    testWidgets('shows an empty state when a tab has no formats',
        (tester) async {
      await tester.pumpWidget(
        build(tab: 1, formats: const [_video1080, _video720]),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('No audio format is available for this link.'),
        findsOneWidget,
      );
    });

    testWidgets('respects admin media-type switches (§25)', (tester) async {
      await tester.pumpWidget(build(tab: 1, audioEnabled: false));
      await tester.pumpAndSettle();
      expect(
        find.text('Audio downloads are disabled in settings.'),
        findsOneWidget,
      );
      expect(find.text('Download'), findsNothing);
    });
  });

  group('DownloadProgressCard (§7)', () {
    testWidgets('shows real percentage, bytes, speed and ETA', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DownloadProgressCard(
            stage: 'Downloading...',
            progress: 0.78,
            bytesReceived: 42000000,
            totalBytes: 54000000,
            speed: 4800000,
            onCancel: () {},
          ),
        ),
      );

      expect(find.text('Downloading...'), findsOneWidget);
      expect(find.text('78%'), findsOneWidget);
      expect(find.textContaining('40.1 MB / 51.5 MB'), findsOneWidget);
      expect(find.textContaining('4.6 MB/s'), findsOneWidget);
      expect(find.textContaining('ETA: 00:03'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('does not fake a percentage when the total is unknown',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          DownloadProgressCard(
            stage: 'Downloading...',
            progress: 0,
            bytesReceived: 1024,
            totalBytes: 0,
            speed: 0,
            onCancel: () {},
          ),
        ),
      );

      expect(find.text('Preparing...'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, isNull, reason: 'indeterminate until total is known');
    });
  });

  group('DownloadStatusBadge (§9)', () {
    test('labels every status', () {
      expect(
        DownloadStatusBadge.statusLabel(DownloadStatus.pending),
        'Queued',
      );
      expect(
        DownloadStatusBadge.statusLabel(DownloadStatus.downloading),
        'Downloading',
      );
      expect(
        DownloadStatusBadge.statusLabel(DownloadStatus.processing),
        'Processing',
      );
      expect(DownloadStatusBadge.statusLabel(DownloadStatus.paused), 'Paused');
      expect(
        DownloadStatusBadge.statusLabel(DownloadStatus.completed),
        'Completed',
      );
      expect(
        DownloadStatusBadge.statusLabel(DownloadStatus.failed),
        'Failed',
      );
      expect(
        DownloadStatusBadge.statusLabel(DownloadStatus.cancelled),
        'Cancelled',
      );
    });

    testWidgets('renders the label in a chip', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DownloadStatusBadge(status: DownloadStatus.completed),
        ),
      );
      expect(find.text('Completed'), findsOneWidget);
    });
  });
}
