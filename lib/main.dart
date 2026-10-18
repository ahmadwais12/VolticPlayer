import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'core/config/app_env.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/services/ad_service.dart';
import 'core/services/app_media_player.dart';
import 'core/services/audio_background_bootstrap.dart';
import 'core/services/audio_session_helper.dart';
import 'core/services/library_auto_scan.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/presentation/controllers/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    print('════════════════════════════════════════');
    print('[FlutterError] ${details.exceptionAsString()}');
    print('[FlutterError] library=${details.library}');
    print('[FlutterError] context=${details.context}');
    print('[FlutterError] stack=\n${details.stack}');
    print('════════════════════════════════════════');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    print('════════════════════════════════════════');
    print('[PlatformError] $error');
    print('[PlatformError] stack=\n$stack');
    print('════════════════════════════════════════');
    return true;
  };

  // media_kit must init before anything else that might touch the player —
  // late init is a known cause of Android black video surfaces.
  try {
    MediaKit.ensureInitialized();
    AppMediaPlayer.ensureInitialized();
  } catch (e) {
    print('[Main] MediaKit.ensureInitialized failed: $e');
  }

  // Load `.env` API keys / limits before any feature reads AppEnv.
  await AppEnv.load();

  runApp(const ProviderScope(child: AppRoot()));

  // Optional integrations must not block the first frame. Ads can wait on
  // network access, leaving the entire app black if initialized before runApp.
  unawaited(_initializeOptionalServices());
}

Future<void> _initializeOptionalServices() async {
  try {
    await AudioSessionHelper.configure();
  } catch (e) {
    debugPrint('[Main] AudioSession.configure failed: $e');
  }

  try {
    await AudioBackgroundBootstrap.init();
  } catch (e) {
    debugPrint('[Main] AudioBackgroundBootstrap.init failed: $e');
  }

  try {
    await AdService.initialize();
    AdService.loadInterstitialAd();
    AdService.loadRewardedAd();
  } catch (e) {
    debugPrint('[Main] AdService initialization failed: $e');
  }
}

class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kick off seed + silent library scan at process start, even if the user
    // never opens Home / Videos / Music / Playlists.
    ref.watch(libraryAutoScanProvider);

    final theme = ref.watch(themeControllerProvider);

    final light = AppTheme.light();
    final dark = theme.oled ? AppTheme.oled() : AppTheme.dark();
    final mode = AppTheme.themeModeFromName(theme.mode);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: light,
      darkTheme: dark,
      themeMode: mode,
      routerConfig: AppRouter.router,
    );
  }
}
