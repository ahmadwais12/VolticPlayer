import 'package:flutter/material.dart';

import '../../core/constants/ui_helper.dart';

/// Real-time playback statistics overlay for the video player.
/// Shows resolution, FPS, video codec, audio codec, bitrate,
/// dropped frames, and hardware decoder status.
class PlaybackStatsOverlay extends StatelessWidget {
  final String? resolution;
  final String? fps;
  final String? videoCodec;
  final String? audioCodec;
  final int? videoBitrate;
  final int? audioBitrate;
  final int droppedFrames;
  final bool hwDecoder;
  final bool isVisible;
  final VoidCallback? onClose;

  const PlaybackStatsOverlay({
    super.key,
    this.resolution,
    this.fps,
    this.videoCodec,
    this.audioCodec,
    this.videoBitrate,
    this.audioBitrate,
    this.droppedFrames = 0,
    this.hwDecoder = true,
    this.isVisible = false,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Positioned(
      top: UIHelper.spaceXXL,
      left: UIHelper.spaceMD,
      right: UIHelper.spaceMD,
      child: Container(
        padding: const EdgeInsets.all(UIHelper.spaceMD),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(UIHelper.radiusMD),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Playback Statistics',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (onClose != null)
                  GestureDetector(
                    onTap: onClose,
                    child: const Icon(Icons.close, color: Colors.white70, size: 20),
                  ),
              ],
            ),
            const Divider(color: Colors.white24),
            _StatRow(label: 'Resolution', value: resolution ?? 'N/A'),
            _StatRow(label: 'Frame Rate', value: fps != null ? '$fps FPS' : 'N/A'),
            _StatRow(label: 'Video Codec', value: videoCodec ?? 'N/A'),
            _StatRow(label: 'Audio Codec', value: audioCodec ?? 'N/A'),
            if (videoBitrate != null)
              _StatRow(
                  label: 'Video Bitrate',
                  value: '${(videoBitrate! / 1000).round()} kbps'),
            if (audioBitrate != null)
              _StatRow(
                  label: 'Audio Bitrate',
                  value: '${(audioBitrate! / 1000).round()} kbps'),
            _StatRow(label: 'Dropped Frames', value: '$droppedFrames'),
            _StatRow(
              label: 'HW Decoder',
              value: hwDecoder ? 'Enabled' : 'Disabled',
              valueColor: hwDecoder ? Colors.greenAccent : Colors.orangeAccent,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
