import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

/// Reusable subtitle track selector bottom sheet.
///
/// Used by the video player to avoid duplicating the subtitle selection UI.
class SubtitleSheet extends StatelessWidget {
  final List<SubtitleTrack> tracks;
  final SubtitleTrack? selected;
  final ValueChanged<SubtitleTrack?> onSelected;

  const SubtitleSheet({
    super.key,
    required this.tracks,
    this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      shrinkWrap: true,
      children: [
        ListTile(
          title: const Text('Off'),
          trailing: selected == null
              ? Icon(Icons.check, color: theme.colorScheme.primary)
              : null,
          onTap: () => onSelected(null),
        ),
        for (final track in tracks)
          ListTile(
            title: Text(
              track.title ?? track.language ?? 'Track',
            ),
            trailing: selected == track
                ? Icon(Icons.check, color: theme.colorScheme.primary)
                : null,
            onTap: () => onSelected(track),
          ),
    ]);
  }
}
