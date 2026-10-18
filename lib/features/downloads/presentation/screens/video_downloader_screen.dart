import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/ui_helper.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/download_manager.dart';
import '../../../../core/services/downloader_settings.dart';
import '../controllers/video_downloader_notifier.dart';
import '../widgets/download_completed_card.dart';
import '../widgets/download_progress_card.dart';
import '../widgets/downloader_error_card.dart';
import '../widgets/downloader_hero.dart';
import '../widgets/format_selector_card.dart';
import '../widgets/media_preview_card.dart';
import '../widgets/media_skeleton_loader.dart';
import '../widgets/url_input_card.dart';

/// Dedicated "Video & Audio Downloader" page (prompt §1).
///
/// The flow is: paste URL → analyze → preview → choose video/audio tab →
/// choose quality → download → progress → completed (§28).
class VideoDownloaderScreen extends ConsumerStatefulWidget {
  const VideoDownloaderScreen({super.key, this.initialUrl});

  final String? initialUrl;

  @override
  ConsumerState<VideoDownloaderScreen> createState() =>
      _VideoDownloaderScreenState();
}

class _VideoDownloaderScreenState extends ConsumerState<VideoDownloaderScreen> {
  final _urlController = TextEditingController();
  final _urlFocusNode = FocusNode();
  int _mediaTab = 0;

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final initialUrl = widget.initialUrl;
    if (initialUrl != null && initialUrl.isNotEmpty) {
      _urlController.text = initialUrl;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resolveUrl();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(videoDownloaderProvider);
    final settings = ref.watch(downloaderSettingsValueProvider);
    final downloads = ref.watch(downloadManagerProvider);
    ref.listen(videoDownloaderProvider, (previous, next) {
      if (next.phase == DownloaderPhase.resolved &&
          previous?.phase != DownloaderPhase.resolved &&
          next.metadata != null) {
        final formats = next.metadata!.formats;
        setState(
          () => _mediaTab =
              formats.isNotEmpty &&
                  formats.every((format) => format.isAudioOnly)
              ? 1
              : 0,
        );
      }
    });
    final theme = Theme.of(context);
    final wideLayout = UIHelper.isWide(context);

    // If a tab's media type is disabled in settings, fall back to the
    // other tab instead of showing a dead end.
    var tab = _mediaTab;
    if (tab == 0 && !settings.videoEnabled && settings.audioEnabled) tab = 1;
    if (tab == 1 && !settings.audioEnabled && settings.videoEnabled) tab = 0;

    final resolving = state.phase == DownloaderPhase.resolving;
    final downloading = state.phase == DownloaderPhase.downloading;
    final inputEnabled =
        settings.enabled && !downloading && !resolving;

    final activeUri = state.selectedFormat?.url ?? state.url;
    final activeItem = downloads.findByUri(activeUri);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Download'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Downloader settings',
            onPressed: () => context.push(AppRouter.downloaderSettings),
          ),
          if (downloading)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancel download',
              onPressed: () => _confirmCancel(context),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: SingleChildScrollView(
            padding: UIHelper.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                const DownloaderHero(),
                UIHelper.vLG,

                // ── URL input ───────────────────────────────────────
                UrlInputCard(
                  controller: _urlController,
                  focusNode: _urlFocusNode,
                  enabled: inputEnabled,
                  analyzing: resolving,
                  onAnalyze: _resolveUrl,
                  onPaste: _pasteFromClipboard,
                  onClear: () {
                    _urlController.clear();
                    setState(() {});
                  },
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _resolveUrl(),
                ),

                UIHelper.vMD,

                if (!settings.enabled) ...[
                  UIHelper.vMD,
                  _DisabledNotice(theme: theme),
                ],

                // ── Error ──────────────────────────────────────────
                if (state.error != null && state.phase == DownloaderPhase.error) ...[
                  UIHelper.vMD,
                  DownloaderErrorCard(message: state.error!),
                ],

                // ── Loading skeleton ──────────────────────────────
                if (resolving) ...[
                  UIHelper.vMD,
                  const MediaSkeletonLoader(),
                ],

                // ── Preview + formats (two-column on wide screens) ──
                if (!resolving && state.metadata != null) ...[
                  UIHelper.vMD,
                  if (wideLayout &&
                      state.phase == DownloaderPhase.resolved)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _preview(state)),
                        UIHelper.hMD,
                        Expanded(child: _formats(state, settings, tab)),
                      ],
                    )
                  else ...[
                    _preview(state),
                    if (state.phase == DownloaderPhase.resolved) ...[
                      UIHelper.vMD,
                      _formats(state, settings, tab),
                    ],
                  ],
                ],

                // ── Download progress ──────────────────────────────
                if (downloading) ...[
                  UIHelper.vMD,
                  DownloadProgressCard(
                    stage: switch (activeItem?.status) {
                      DownloadStatus.pending => 'Preparing...',
                      DownloadStatus.processing => 'Processing...',
                      _ => 'Downloading...',
                    },
                    paused: activeItem?.isPaused ?? false,
                    progress: state.progress,
                    bytesReceived: state.bytesReceived,
                    totalBytes: state.totalBytes,
                    speed: state.speed,
                    onCancel: () => _confirmCancel(context),
                    onResume: activeItem?.isPaused == true
                        ? () => ref
                              .read(videoDownloaderProvider.notifier)
                              .resumeDownload()
                        : null,
                  ),
                ],

                // ── Completed ──────────────────────────────────────
                if (state.phase == DownloaderPhase.completed) ...[
                  UIHelper.vMD,
                  DownloadCompletedCard(
                    fileName: state.savedPath?.split(RegExp(r'[/\\]')).last,
                    onPlay: state.savedPath == null
                        ? null
                        : () => _playSavedFile(state.savedPath!),
                    onDownloadMore: () {
                      ref.read(videoDownloaderProvider.notifier).reset();
                      _urlController.clear();
                    },
                  ),
                ],

                // ── Recent URLs ────────────────────────────────────
                if (state.phase == DownloaderPhase.idle &&
                    state.recentUrls.isNotEmpty)
                  _buildRecentUrls(state, theme),

                // ── Queue + history ────────────────────────────────
                if (downloads.items.isNotEmpty)
                  _buildQueueAndHistory(downloads.items, theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _preview(VideoDownloaderState state) =>
      MediaPreviewCard(metadata: state.metadata!);

  Widget _formats(
    VideoDownloaderState state,
    DownloaderSettings settings,
    int tab,
  ) => FormatSelectorCard(
    metadata: state.metadata!,
    activeTab: tab,
    selectedFormat: state.selectedFormat,
    videoEnabled: settings.videoEnabled,
    audioEnabled: settings.audioEnabled,
    onTabChanged: (value) => setState(() => _mediaTab = value),
    onSelect: (format) =>
        ref.read(videoDownloaderProvider.notifier).selectFormat(format),
    onDownload: (format) {
      final notifier = ref.read(videoDownloaderProvider.notifier);
      notifier.selectFormat(format);
      notifier.startDownload();
    },
  );

  Widget _buildRecentUrls(VideoDownloaderState state, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UIHelper.vLG,
        Text(
          'Recent',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        UIHelper.vSM,
        for (final url in state.recentUrls.take(5))
          ListTile(
            dense: true,
            leading: const Icon(Icons.history, size: 20),
            title: Text(
              url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            onTap: () {
              _urlController.text = url;
              _resolveUrl();
            },
          ),
      ],
    );
  }

  Widget _buildQueueAndHistory(List<DownloadItem> items, ThemeData theme) {
    final active = items
        .where((item) => item.isActive || item.isPaused)
        .take(3)
        .toList();
    final recent =
        items.where((item) => !item.isActive && !item.isPaused).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UIHelper.vLG,
        Row(
          children: [
            Expanded(
              child: Text(
                'Download queue',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.go(AppRouter.downloads),
              child: const Text('Manage'),
            ),
          ],
        ),
        if (active.isEmpty)
          Text(
            'Nothing in the queue right now.',
            style: theme.textTheme.bodySmall,
          )
        else
          for (final item in active)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                item.isPaused
                    ? Icons.pause_circle_outline
                    : Icons.downloading,
              ),
              title: Text(
                item.title ?? item.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                item.status == DownloadStatus.pending
                    ? 'Waiting in queue'
                    : item.status == DownloadStatus.processing
                    ? 'Processing...'
                    : item.isPaused
                    ? 'Paused'
                    : '${(item.progress * 100).round()}%',
              ),
            ),
        if (recent.isNotEmpty) ...[
          UIHelper.vMD,
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent downloads',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.go(AppRouter.downloads),
                child: const Text('View all'),
              ),
            ],
          ),
          for (final item in recent.take(3))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                item.isCompleted
                    ? Icons.check_circle_outline
                    : Icons.history,
              ),
              title: Text(
                item.title ?? item.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(item.format ?? item.status.name),
            ),
        ],
      ],
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      _urlController.text = data.text!.trim();
      setState(() {});
      _resolveUrl();
    }
  }

  void _resolveUrl() {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      ref.read(videoDownloaderProvider.notifier).setUrl(url);
    }
  }

  void _playSavedFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    const videoExts = {'mp4', 'mkv', 'avi', 'mov', 'webm', 'm4v', '3gp'};
    if (videoExts.contains(ext)) {
      context.push(
        AppRouter.videoPlayer,
        extra: {
          'uri': path,
          'title': ref.read(videoDownloaderProvider).metadata?.title ?? 'Video',
        },
      );
    } else {
      context.push(
        AppRouter.audioPlayer,
        extra: {
          'uri': path,
          'title': ref.read(videoDownloaderProvider).metadata?.title ?? 'Audio',
        },
      );
    }
  }

  void _confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Download?'),
        content: const Text('The current download will be cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(videoDownloaderProvider.notifier).cancelDownload();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

/// Shown when an admin turned the downloader off (prompt §25).
class _DisabledNotice extends StatelessWidget {
  const _DisabledNotice({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.block, color: theme.colorScheme.outline),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'The downloader is disabled in settings. Enable it under '
                'Settings → Downloader settings.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
