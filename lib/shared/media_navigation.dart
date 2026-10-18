import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/services/ad_service.dart';
import '../../domain/entities/media_item.dart';

/// Counter for interstitial ad throttling.
/// Shows an interstitial every _adInterval opens.
int _openCount = 0;
const int _adInterval = 5;

/// Opens the appropriate player screen for a [MediaItem]
/// (video vs audio), passing the required route [extra].
/// Shows an interstitial ad every [_adInterval] opens.
void openMedia(BuildContext context, MediaItem item) {
  _openCount++;

  // Show interstitial every N opens (skip first few to avoid annoying users)
  if (_openCount >= _adInterval && _openCount % _adInterval == 0) {
    AdService.showInterstitialAd();
    // If ad was shown, it's full-screen — still navigate after
    // (the ad dismiss callback will handle the next navigation if needed)
  }

  if (item.isAudio) {
    context.push(
      AppRouter.audioPlayer,
      extra: {
        'uri': item.uri,
        'title': item.displayName,
        'artist': item.artist,
        'artworkPath': item.thumbnailPath,
      },
    );
  } else {
    context.push(
      AppRouter.videoPlayer,
      extra: {
        'uri': item.uri,
        'title': item.displayName,
        'thumbnailPath': item.thumbnailPath,
      },
    );
  }
}
