import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Centralized ad management service.
///
/// Uses Google's **test ad unit IDs** so ads always render during development.
/// Replace with real ad unit IDs before publishing.
class AdService {
  AdService._();

  static bool _initialized = false;

  // ── Test Ad Unit IDs (Google official) ─────────────────────────────────
  // These ALWAYS show test ads — safe for development.

  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716';
    }
    return 'ca-app-pub-3940256099942544/6300978111'; // fallback
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910';
    }
    return 'ca-app-pub-3940256099942544/1033173712';
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313';
    }
    return 'ca-app-pub-3940256099942544/5224354917';
  }

  // ── Initialization ─────────────────────────────────────────────────────

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.initialize();
      // Optionally set test device IDs for emulators
      if (kDebugMode) {
        MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(
            testDeviceIds: [
              '33BE2250B43518CCDA7DE4269088751A', // common emulator ID
            ],
          ),
        );
      }
      _initialized = true;
      debugPrint('[AdService] Initialized successfully');
    } catch (e) {
      debugPrint('[AdService] Initialization failed: $e');
    }
  }

  // ── Banner Ads ─────────────────────────────────────────────────────────

  /// Creates a banner ad. Caller must manage lifecycle (dispose when done).
  static BannerAd createBannerAd({
    AdSize size = AdSize.banner,
    VoidCallback? onLoaded,
    VoidCallback? onFailedToLoad,
  }) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('[AdService] Banner ad loaded');
          onLoaded?.call();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AdService] Banner ad failed: ${error.message}');
          ad.dispose();
          onFailedToLoad?.call();
        },
        onAdOpened: (ad) => debugPrint('[AdService] Banner ad opened'),
        onAdClosed: (ad) => debugPrint('[AdService] Banner ad closed'),
      ),
    );
  }

  // ── Interstitial Ads ───────────────────────────────────────────────────

  static InterstitialAd? _interstitialAd;
  static int _interstitialLoadCount = 0;

  /// Pre-load an interstitial ad. Call once during app init.
  static void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialLoadCount++;
          debugPrint('[AdService] Interstitial loaded (#$_interstitialLoadCount)');
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              // Pre-load next one
              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('[AdService] Interstitial show failed: ${error.message}');
              ad.dispose();
              _interstitialAd = null;
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdService] Interstitial load failed: ${error.message}');
          _interstitialAd = null;
        },
      ),
    );
  }

  /// Show interstitial if loaded. Safe to call anytime — no-ops if not ready.
  /// Returns true if the ad was shown.
  static bool showInterstitialAd() {
    final ad = _interstitialAd;
    if (ad == null) {
      debugPrint('[AdService] Interstitial not ready');
      return false;
    }
    ad.show();
    return true;
  }

  // ── Rewarded Ads ───────────────────────────────────────────────────────

  static RewardedAd? _rewardedAd;

  /// Pre-load a rewarded ad.
  static void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          debugPrint('[AdService] Rewarded ad loaded');
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('[AdService] Rewarded show failed: ${error.message}');
              ad.dispose();
              _rewardedAd = null;
              loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdService] Rewarded load failed: ${error.message}');
          _rewardedAd = null;
        },
      ),
    );
  }

  /// Show rewarded ad. Calls [onReward] when user earns the reward.
  /// Returns true if the ad was shown.
  static Future<bool> showRewardedAd({
    required void Function(int amount) onReward,
  }) async {
    final ad = _rewardedAd;
    if (ad == null) {
      debugPrint('[AdService] Rewarded ad not ready');
      return false;
    }

    final completer = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        if (!completer.isCompleted) completer.complete(false);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdService] Rewarded show failed: ${error.message}');
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    await ad.show(
      onUserEarnedReward: (ad, reward) {
        debugPrint('[AdService] User earned reward: ${reward.amount} ${reward.type}');
        onReward(reward.amount.toInt());
        if (!completer.isCompleted) completer.complete(true);
      },
    );

    return completer.future;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────

  static void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _interstitialAd = null;
    _rewardedAd = null;
  }
}


