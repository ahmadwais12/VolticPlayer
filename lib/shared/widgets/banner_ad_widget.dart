import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/services/ad_service.dart';

/// A self-managing banner ad widget.
///
/// Loads and disposes the ad automatically. Wrap in a Visibility detector
/// or setState to control when ads are visible.
class BannerAdWidget extends StatefulWidget {
  final AdSize? adSize;

  const BannerAdWidget({super.key, this.adSize});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _ad = AdService.createBannerAd(
      size: widget.adSize ?? AdSize.banner,
      onLoaded: () {
        if (mounted) setState(() => _isLoaded = true);
      },
      onFailedToLoad: () {
        if (mounted) setState(() => _isLoaded = false);
      },
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}

/// Smart banner that adapts to screen width.
class SmartBannerAd extends StatelessWidget {
  const SmartBannerAd({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    AdSize size;
    if (width >= 728) {
      size = AdSize.leaderboard; // 728x90
    } else if (width >= 468) {
      size = AdSize.largeBanner; // 468x60
    } else {
      size = AdSize.banner; // 320x50
    }
    return Center(
      child: BannerAdWidget(adSize: size),
    );
  }
}
