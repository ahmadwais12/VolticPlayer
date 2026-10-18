import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../core/constants/ui_helper.dart';

/// Reusable audio track selector bottom sheet.
///
/// Used by the video player to avoid duplicating the audio track selection UI.
class AudioTrackSheet extends StatelessWidget {
  final List<AudioTrack> tracks;
  final AudioTrack? selected;
  final ValueChanged<AudioTrack> onSelected;

  const AudioTrackSheet({
    super.key,
    required this.tracks,
    this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (tracks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(UIHelper.spaceXL),
        child: Center(
          child: Text('No audio tracks available.'),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: tracks.length,
      itemBuilder: (context, i) {
        final track = tracks[i];
        return ListTile(
          title: Text(
            track.title ?? track.language ?? 'Track ${i + 1}',
          ),
          trailing: selected == track
              ? Icon(Icons.check, color: theme.colorScheme.primary)
              : null,
          onTap: () => onSelected(track),
        );
      },
    );
  }
}
