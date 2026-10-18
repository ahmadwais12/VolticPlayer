import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../../core/constants/ui_helper.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/download_manager.dart';
import '../../../../core/services/downloader_settings.dart';
import '../../../../core/services/video_downloader_service.dart';
import '../../domain/web_search_models.dart';

/// Opens the two-section (Music / Video) download sheet for [result].
Future<void> showDownloadOptionsSheet(BuildContext context, WebResult result) {
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: scheme.surface,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(UIHelper.radiusLG),
      ),
    ),
    builder: (_) => DownloadOptionsSheet(result: result),
  );
}

class _QualityOption {
  final String label;
  final String container;
  final int value; // kbps for audio, height for video
  final bool audio;

  const _QualityOption.audio(this.label, this.container, this.value)
    : audio = true;
  const _QualityOption.video(this.label, this.value)
    : container = 'mp4',
      audio = false;
}

const _musicOptions = [
  _QualityOption.audio('128k', 'm4a', 128),
  _QualityOption.audio('128k', 'mp3', 128),
  _QualityOption.audio('48k', 'mp3', 48),
  _QualityOption.audio('256k', 'mp3', 256),
];

const _videoOptions = [
  _QualityOption.video('144p', 144),
  _QualityOption.video('240p', 240),
  _QualityOption.video('360p', 360),
  _QualityOption.video('480p', 480),
  _QualityOption.video('720p', 720),
  _QualityOption.video('1080p', 1080),
];

/// Puts a [UIHelper.vSM] gap between siblings so tile lists keep an even
/// rhythm without each tile carrying its own margin.
List<Widget> _spaced(List<Widget> children) => [
  for (var i = 0; i < children.length; i++) ...[
    if (i > 0) UIHelper.vSM,
    children[i],
  ],
];

class DownloadOptionsSheet extends ConsumerStatefulWidget {
  final WebResult result;

  const DownloadOptionsSheet({super.key, required this.result});

  @override
  ConsumerState<DownloadOptionsSheet> createState() =>
      _DownloadOptionsSheetState();
}

class _DownloadOptionsSheetState extends ConsumerState<DownloadOptionsSheet> {
  final _service = VideoDownloaderService();
  late final Future<MediaMetadata> _analysis = _service.resolveFromUrl(
    widget.result.url,
  );

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Music and Video get distinct accents so the two sections read apart at a
    // glance; both come from the active scheme so dark mode stays correct.
    final musicAccent = scheme.primary;
    final videoAccent = scheme.tertiary;
    // Fixed-size sheet: a stable width/height that never resizes by drag,
    // while the option list itself stays scrollable.
    final size = MediaQuery.sizeOf(context);
    final sheetWidth = size.width > 620 ? 560.0 : size.width;
    final sheetHeight = size.height * 0.78;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: sheetWidth,
          maxHeight: sheetHeight,
        ),
        child: SizedBox(
          width: sheetWidth,
          height: sheetHeight,
          child: FutureBuilder<MediaMetadata>(
            future: _analysis,
            builder: (context, snap) {
              final media = snap.data;
              final formats = (media?.formats ?? const <MediaFormat>[])
                  .where((f) => f.label != 'Media')
                  .toList();
              final loading = snap.connectionState != ConnectionState.done;
              final matched = <_QualityOption, MediaFormat>{
                for (final o in [..._musicOptions, ..._videoOptions])
                  o: ?_match(o, formats),
              };
              final others = formats
                  .where((f) => !matched.values.contains(f))
                  .toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  UIHelper.spaceMD,
                  0,
                  UIHelper.spaceMD,
                  UIHelper.spaceLG,
                ),
                children: [
                  _Header(result: widget.result, media: media),
                  UIHelper.vMD,
                  if (loading)
                    const _LoadingBanner()
                  else if (snap.hasError || formats.isEmpty)
                    _Notice(
                      icon: snap.hasError
                          ? Icons.wifi_off_rounded
                          : Icons.info_outline_rounded,
                      text: snap.hasError
                          ? 'Could not read download options for this link. '
                                'Check your connection and try again.'
                          : 'This source did not provide a downloadable file, '
                                'so the options below are unavailable.',
                    ),
                  _SectionTitle(
                    icon: Icons.music_note_rounded,
                    title: 'Music',
                    accent: musicAccent,
                    meta: _meta(matched, _musicOptions),
                  ),
                  ..._spaced([
                    for (final o in _musicOptions)
                      _OptionTile(
                        option: o,
                        format: matched[o],
                        accent: musicAccent,
                        loading: loading,
                        onDownload: (f) => _download(media!, f, audio: true),
                      ),
                  ]),
                  UIHelper.vLG,
                  _SectionTitle(
                    icon: Icons.movie_rounded,
                    title: 'Video',
                    accent: videoAccent,
                    meta: _meta(matched, _videoOptions),
                  ),
                  ..._spaced([
                    for (final o in _videoOptions)
                      _OptionTile(
                        option: o,
                        format: matched[o],
                        accent: videoAccent,
                        loading: loading,
                        onDownload: (f) => _download(media!, f, audio: false),
                      ),
                  ]),
                  if (others.isNotEmpty) ...[
                    UIHelper.vLG,
                    _SectionTitle(
                      icon: Icons.file_present_rounded,
                      title: 'Other formats',
                      accent: scheme.secondary,
                      meta: '${others.length} found',
                    ),
                    ..._spaced([
                      for (final f in others)
                        _FormatTile(
                          icon: f.isAudioOnly
                              ? Icons.audiotrack_rounded
                              : Icons.videocam_rounded,
                          title: f.label,
                          subtitle: f.fileSize != null
                              ? _formatBytes(f.fileSize!)
                              : (f.isAudioOnly ? 'Audio track' : 'Video track'),
                          accent: f.isAudioOnly ? musicAccent : videoAccent,
                          onDownload: () =>
                              _download(media!, f, audio: f.isAudioOnly),
                        ),
                    ]),
                  ],
                  UIHelper.vLG,
                  const _Footer(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// "n of m available" caption shown on a section header.
  String _meta(
    Map<_QualityOption, MediaFormat> matched,
    List<_QualityOption> options,
  ) {
    final available = options.where((o) => matched[o] != null).length;
    return '$available of ${options.length} available';
  }

  MediaFormat? _match(_QualityOption o, List<MediaFormat> formats) {
    MediaFormat? best;
    var bestDelta = 1 << 30;
    for (final f in formats) {
      if (f.isAudioOnly != o.audio) continue;
      final text = '${f.label} ${f.quality ?? ''} ${f.url ?? ''}'.toLowerCase();
      if (o.audio) {
        // Prefer matching container when present (mp3/m4a/webm…).
        if (!text.contains(o.container) &&
            o.container != 'mp3' &&
            o.container != 'm4a') {
          continue;
        }
        final kbps =
            int.tryParse(
              RegExp(r'(\d{2,3})\s*k').firstMatch(text)?.group(1) ?? '',
            ) ??
            0;
        if (kbps == 0) continue;
        final delta = (kbps - o.value).abs();
        if (delta < bestDelta) {
          bestDelta = delta;
          best = f;
        }
      } else {
        final height =
            int.tryParse(
              RegExp(r'(\d{3,4})\s*p').firstMatch(text)?.group(1) ?? '',
            ) ??
            0;
        if (height == 0) continue;
        // Skip pure video-only when a muxed match exists at similar height.
        final delta = (height - o.value).abs();
        final penalized = text.contains('video-only') ? delta + 40 : delta;
        if (penalized < bestDelta) {
          bestDelta = penalized;
          best = f;
        }
      }
    }
    // Accept nearest quality within a reasonable window.
    if (best != null && bestDelta <= (o.audio ? 64 : 120)) return best;
    return null;
  }

  void _download(
    MediaMetadata media,
    MediaFormat format, {
    required bool audio,
  }) {
    final settings = ref.read(downloaderSettingsValueProvider);
    // Prefer the resolved direct URL; fall back to the page URL
    final url = (format.url?.isNotEmpty == true)
        ? format.url!
        : widget.result.url;
    debugPrint(
      '[DL-diag] sheet _download tapped title="${media.title}" '
      'format="${format.label}" audio=$audio fileSize=${format.fileSize} '
      'hasDirectUrl=${format.url?.isNotEmpty == true} url=${_shortUrl(url)}',
    );
    String? error;
    if (!settings.enabled) {
      error = 'The downloader is disabled in settings.';
    } else if (audio && !settings.audioEnabled) {
      error = 'Audio downloads are disabled in settings.';
    } else if (!audio && !settings.videoEnabled) {
      error = 'Video downloads are disabled in settings.';
    } else if (format.fileSize != null &&
        format.fileSize! > settings.maxFileSizeBytes) {
      error = 'This file exceeds the maximum allowed download size.';
    }
    final messenger = ScaffoldMessenger.of(context);
    if (error != null) {
      debugPrint('[DL-diag] sheet _download blocked: $error');
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final ext = _extensionFor(url, format, audio: audio);
    final safeTitle = media.title
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    final fileTitle = safeTitle.isEmpty ? 'download' : safeTitle;
    debugPrint(
      '[DL-diag] sheet _download dispatching fileName="$fileTitle.$ext" '
      'mediaType=${audio ? 'audio' : 'video'}',
    );
    ref
        .read(downloadManagerProvider.notifier)
        .download(
          uri: url,
          fileName: '$fileTitle.$ext',
          title: media.title,
          sourceUrl: widget.result.url,
          format: format.label,
          mediaType: audio ? 'audio' : 'video',
          thumbnailUrl: media.thumbnailUrl ?? widget.result.thumbnailUrl,
          expectedBytes: format.fileSize,
          // Direct stream URLs (incl. googlevideo) skip page-URL checks.
          skipUrlValidation: true,
        );
    final router = GoRouter.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Downloading "${media.title}"'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => router.go(AppRouter.downloadDetails),
        ),
      ),
    );
  }

  /// Truncates a URL for diagnostic logs (scheme+host+first path segment),
  /// so googlevideo query tokens are never dumped to the console.
  String _shortUrl(String url) {
    final parsed = Uri.tryParse(url);
    if (parsed == null || parsed.host.isEmpty) {
      return url.length > 60 ? '${url.substring(0, 60)}…' : url;
    }
    final firstSeg = parsed.pathSegments.isEmpty
        ? ''
        : '/${parsed.pathSegments.first}';
    return '${parsed.scheme}://${parsed.host}$firstSeg…';
  }

  String _extensionFor(String url, MediaFormat f, {required bool audio}) {
    final ext = p
        .extension(Uri.tryParse(url)?.path ?? '')
        .replaceFirst('.', '')
        .toLowerCase();
    if (RegExp(r'^[a-z0-9]{1,5}$').hasMatch(ext)) return ext;
    final label = f.label.toLowerCase();
    if (label.contains('m4a')) return 'm4a';
    if (label.contains('mp3') || audio) return 'mp3';
    return 'mp4';
  }
}

/// Saves an image search result straight to the download manager.
void downloadImageResult(BuildContext context, WidgetRef ref, WebResult r) {
  final uri = Uri.tryParse(r.url);
  var ext = p.extension(uri?.path ?? '').replaceFirst('.', '').toLowerCase();
  if (!const {'jpg', 'jpeg', 'png', 'gif', 'webp'}.contains(ext)) ext = 'jpg';
  final safeTitle = r.title.length > 60 ? r.title.substring(0, 60) : r.title;
  ref
      .read(downloadManagerProvider.notifier)
      .download(
        uri: r.url,
        fileName: '$safeTitle.$ext',
        title: r.title,
        sourceUrl: r.url,
        format: ext.toUpperCase(),
        mediaType: 'image',
        thumbnailUrl: r.thumbnailUrl,
      );
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('Picture added to downloads'),
      action: SnackBarAction(
        label: 'View',
        onPressed: () => context.go(AppRouter.downloadDetails),
      ),
    ),
  );
}

String _formatBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

class _Header extends StatelessWidget {
  final WebResult result;
  final MediaMetadata? media;

  const _Header({required this.result, required this.media});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(UIHelper.spaceSM),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.45),
            scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(UIHelper.radiusMD),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Thumb(
            url: media?.thumbnailUrl ?? result.thumbnailUrl,
            duration: media?.duration,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  media?.title ?? result.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                UIHelper.vXS,
                Row(
                  children: [
                    Icon(
                      Icons.public_rounded,
                      size: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        media?.author ?? result.source,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String? url;
  final Duration? duration;

  const _Thumb({required this.url, required this.duration});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget placeholder(IconData icon) => ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(icon, size: 22, color: scheme.onSurfaceVariant),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(UIHelper.radiusSM),
      child: SizedBox(
        width: 104,
        height: 60,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url == null)
              placeholder(Icons.download_rounded)
            else
              Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    placeholder(Icons.broken_image_outlined),
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : placeholder(Icons.image_outlined),
              ),
            if (duration != null && duration! > Duration.zero)
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(UIHelper.radiusXS),
                  ),
                  child: Text(
                    _formatDuration(duration!),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;
  final String? meta;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.accent,
    this.meta,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: UIHelper.spaceSM),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(UIHelper.radiusSM),
            ),
            child: Icon(icon, size: 17, color: accent),
          ),
          UIHelper.hSM,
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
          ),
          UIHelper.hMD,
          Expanded(child: Container(height: 1, color: scheme.outlineVariant)),
          if (meta != null) ...[
            UIHelper.hSM,
            Text(
              meta!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final _QualityOption option;
  final MediaFormat? format;
  final Color accent;
  final bool loading;
  final ValueChanged<MediaFormat> onDownload;

  const _OptionTile({
    required this.option,
    required this.format,
    required this.accent,
    required this.loading,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final available = format != null;
    final size = format?.fileSize;
    return _FormatTile(
      icon: option.audio
          ? Icons.audiotrack_rounded
          : Icons.smart_display_rounded,
      title: option.label,
      badge: option.container.toUpperCase(),
      subtitle: loading
          ? 'Checking source…'
          : available
          ? (size != null ? _formatBytes(size) : 'Size unknown')
          : 'Not available from this source',
      accent: accent,
      available: available,
      onDownload: available ? () => onDownload(format!) : null,
    );
  }
}

/// Card-style row shared by the quality options and the "Other formats" list.
///
/// The whole row is tappable — the circular trailing control is a visual
/// affordance, not a separate button, so there is only one hit target.
class _FormatTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final String? badge;
  final bool available;
  final VoidCallback? onDownload;

  const _FormatTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    this.badge,
    this.available = true,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tint = available ? accent : scheme.onSurfaceVariant;
    final radius = BorderRadius.circular(UIHelper.radiusMD);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: available ? scheme.surfaceContainerLow : scheme.surface,
        borderRadius: radius,
        border: Border.all(
          color: available
              ? accent.withValues(alpha: 0.25)
              : scheme.outlineVariant,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onDownload,
          child: Padding(
            padding: const EdgeInsets.all(UIHelper.spaceSM),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: available ? 0.14 : 0.08),
                    borderRadius: BorderRadius.circular(UIHelper.radiusSM),
                  ),
                  child: Icon(icon, size: 20, color: tint),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: available
                                    ? scheme.onSurface
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (badge != null) ...[
                            UIHelper.hSM,
                            _Pill(label: badge!, color: tint),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                UIHelper.hSM,
                _DownloadAction(accent: accent, enabled: available),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadAction extends StatelessWidget {
  final Color accent;
  final bool enabled;

  const _DownloadAction({required this.accent, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: enabled
            ? accent.withValues(alpha: 0.16)
            : scheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: Border.all(
          color: enabled
              ? accent.withValues(alpha: 0.35)
              : scheme.outlineVariant,
        ),
      ),
      child: Icon(
        Icons.download_rounded,
        size: 19,
        semanticLabel: enabled ? 'Download' : 'Not available',
        color: enabled
            ? accent
            : scheme.onSurfaceVariant.withValues(alpha: 0.55),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(UIHelper.radiusCircular),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 10,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: color,
        ),
      ),
    );
  }
}

class _LoadingBanner extends StatelessWidget {
  const _LoadingBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: UIHelper.spaceSM),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(UIHelper.radiusSM),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: scheme.primary,
            ),
          ),
          UIHelper.hMD,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Checking available formats…',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Reading the source takes a moment',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Notice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: UIHelper.spaceSM),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(UIHelper.radiusSM),
        border: Border.all(color: scheme.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.error),
          UIHelper.hSM,
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.verified_user_outlined, size: 13, color: scheme.outline),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Only download content you have permission to save and use.',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline),
          ),
        ),
      ],
    );
  }
}

String _formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}
