import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../core/services/video_downloader_service.dart';
import 'fade_slide_in.dart';

/// Format selection interface (prompt §4 video options, §5 audio tabs).
///
/// Only formats actually returned by the provider are rendered — qualities
/// are never invented, and bitrates are only shown when the source states
/// them explicitly.
class FormatSelectorCard extends StatelessWidget {
  const FormatSelectorCard({
    super.key,
    required this.metadata,
    required this.activeTab,
    required this.onTabChanged,
    required this.onSelect,
    required this.onDownload,
    this.selectedFormat,
    this.videoEnabled = true,
    this.audioEnabled = true,
  });

  final MediaMetadata metadata;
  final int activeTab; // 0 = video, 1 = audio
  final ValueChanged<int> onTabChanged;
  final ValueChanged<MediaFormat> onSelect;
  final ValueChanged<MediaFormat> onDownload;
  final MediaFormat? selectedFormat;
  final bool videoEnabled;
  final bool audioEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final videoFormats = metadata.formats.where((f) => !f.isAudioOnly).toList();
    final audioFormats = metadata.formats.where((f) => f.isAudioOnly).toList();
    final formats = activeTab == 1 ? audioFormats : videoFormats;
    final tabDisabled = activeTab == 0 ? !videoEnabled : !audioEnabled;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available formats',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('Video'),
                  icon: Icon(Icons.movie_outlined),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Audio'),
                  icon: Icon(Icons.headphones_outlined),
                ),
              ],
              selected: {activeTab},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => onTabChanged(selection.first),
            ),
            const SizedBox(height: 4),
            if (tabDisabled)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: Text(
                    activeTab == 1
                        ? 'Audio downloads are disabled in settings.'
                        : 'Video downloads are disabled in settings.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else if (formats.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: Text(
                    activeTab == 1
                        ? 'No audio format is available for this link.'
                        : 'No video format is available for this link.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ...[
                for (var i = 0; i < formats.length; i++)
                  FadeSlideIn(
                    // Staggered entrance (prompt §21), capped so long lists
                    // do not feel slow.
                    delay: Duration(milliseconds: 120 + (i < 6 ? i * 60 : 300)),
                    offset: const Offset(0, 0.05),
                    child: _FormatRow(
                      format: formats[i],
                      selected: selectedFormat == formats[i],
                      onSelect: () => onSelect(formats[i]),
                      onDownload: () => onDownload(formats[i]),
                    ),
                  ),
              ],
          ],
        ),
      ),
    );
  }
}

class _FormatRow extends StatelessWidget {
  const _FormatRow({
    required this.format,
    required this.selected,
    required this.onSelect,
    required this.onDownload,
  });

  final MediaFormat format;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final container = _containerOf(format);
    final size = format.fileSize != null ? _formatBytes(format.fileSize!) : null;
    final bitrate = _bitrateOf(format);
    final subtitle = [?container, ?bitrate, ?size].join(' • ');

    return InkWell(
      onTap: onSelect,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: RadioGroup<bool>(
          groupValue: selected,
          onChanged: (_) => onSelect(),
          child: Row(
            children: [
              Radio<bool>(
                value: true,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _qualityOf(format),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Download'),
                onPressed: onDownload,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Quality column: the label when it reads like a quality ("1080p",
  /// "320kbps"), otherwise the media/container name.
  static String _qualityOf(MediaFormat format) {
    final label = format.label.trim();
    if (RegExp(r'^\d{3,4}p$').hasMatch(label)) return label;
    if (RegExp(r'^\d+\s*kbps$', caseSensitive: false).hasMatch(label)) {
      return label;
    }
    return label;
  }

  static String? _containerOf(MediaFormat format) {
    final url = format.url;
    if (url != null) {
      final ext = p.extension(Uri.tryParse(url)?.path ?? '').replaceFirst('.', '');
      if (ext.isNotEmpty && RegExp(r'^[a-zA-Z0-9]{2,5}$').hasMatch(ext)) {
        return ext.toUpperCase();
      }
    }
    final match = RegExp(
      r'\b(mp4|mkv|webm|mov|m4v|3gp|mp3|m4a|aac|flac|ogg|opus|wav)\b',
      caseSensitive: false,
    ).firstMatch(format.label);
    if (match != null) return match.group(0)!.toUpperCase();
    return null;
  }

  /// Only surfaces a bitrate when the source explicitly states one.
  static String? _bitrateOf(MediaFormat format) {
    final match = RegExp(r'(\d+)\s*kbps', caseSensitive: false).firstMatch(
      format.label,
    );
    return match?.group(0)!.toLowerCase();
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
