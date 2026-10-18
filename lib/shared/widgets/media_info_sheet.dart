import 'package:flutter/material.dart';

import '../../core/constants/ui_helper.dart';

/// Bottom sheet displaying detailed media information.
class MediaInfoSheet extends StatelessWidget {
  final String title;
  final String? path;
  final int? fileSize;
  final Duration? duration;
  final String? resolution;
  final String? fps;
  final String? videoCodec;
  final String? audioCodec;
  final int? bitrate;
  final int? sampleRate;
  final int? channels;
  final List<String>? subtitleTracks;
  final List<String>? audioTracks;
  final String? container;

  const MediaInfoSheet({
    super.key,
    required this.title,
    this.path,
    this.fileSize,
    this.duration,
    this.resolution,
    this.fps,
    this.videoCodec,
    this.audioCodec,
    this.bitrate,
    this.sampleRate,
    this.channels,
    this.subtitleTracks,
    this.audioTracks,
    this.container,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    String? path,
    int? fileSize,
    Duration? duration,
    String? resolution,
    String? fps,
    String? videoCodec,
    String? audioCodec,
    int? bitrate,
  }) {
    return UIHelper.showAppBottomSheet(
      context,
      title: 'Media Information',
      child: MediaInfoSheet(
        title: title,
        path: path,
        fileSize: fileSize,
        duration: duration,
        resolution: resolution,
        fps: fps,
        videoCodec: videoCodec,
        audioCodec: audioCodec,
        bitrate: bitrate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _InfoRow(label: 'Title', value: title),
        if (path != null) _InfoRow(label: 'Path', value: path!),
        if (fileSize != null) _InfoRow(label: 'File Size', value: _formatBytes(fileSize!)),
        if (duration != null) _InfoRow(label: 'Duration', value: _formatDuration(duration!)),
        if (container != null) _InfoRow(label: 'Container', value: container!),
        if (resolution != null) _InfoRow(label: 'Resolution', value: resolution!),
        if (fps != null) _InfoRow(label: 'Frame Rate', value: '${fps} fps'),
        if (videoCodec != null) _InfoRow(label: 'Video Codec', value: videoCodec!),
        if (audioCodec != null) _InfoRow(label: 'Audio Codec', value: audioCodec!),
        if (bitrate != null) _InfoRow(label: 'Bitrate', value: '${(bitrate! / 1000).round()} kbps'),
        if (sampleRate != null) _InfoRow(label: 'Sample Rate', value: '${(sampleRate! / 1000).round()} kHz'),
        if (channels != null) _InfoRow(label: 'Channels', value: _channelLabel(channels!)),
        if (audioTracks != null && audioTracks!.isNotEmpty)
          _InfoRow(label: 'Audio Tracks', value: audioTracks!.join(', ')),
        if (subtitleTracks != null && subtitleTracks!.isNotEmpty)
          _InfoRow(label: 'Subtitle Tracks', value: subtitleTracks!.join(', ')),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    return '${m}m ${s}s';
  }

  String _channelLabel(int channels) {
    switch (channels) {
      case 1:
        return 'Mono';
      case 2:
        return 'Stereo';
      case 6:
        return '5.1 Surround';
      case 8:
        return '7.1 Surround';
      default:
        return '$channels channels';
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
