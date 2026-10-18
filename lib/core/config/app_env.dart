import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Runtime config from `.env` (via flutter_dotenv), with `--dart-define`
/// fallbacks for CI / release builds that inject keys at compile time.
class AppEnv {
  AppEnv._();

  static bool _loaded = false;
  static final Map<String, String> _fallback = {};

  static Future<void> load() async {
    if (_loaded) return;
    try {
      await dotenv.load(fileName: '.env', isOptional: true);
    } catch (e) {
      debugPrint('[AppEnv] dotenv.load failed: $e');
    }

    // Some installs leave dotenv empty even when the asset exists. Parse the
    // bundled `.env` asset ourselves as a hard fallback.
    if (_youtubeFromDotenv.isEmpty) {
      try {
        final raw = await rootBundle.loadString('.env');
        _parseEnv(raw);
        debugPrint('[AppEnv] loaded .env via rootBundle fallback');
      } catch (e) {
        debugPrint('[AppEnv] rootBundle .env fallback failed: $e');
      }
    }

    _loaded = true;
    debugPrint(
      '[AppEnv] ready (youtubeKey=${youtubeApiKey.isNotEmpty ? "yes" : "no"}, '
      'len=${youtubeApiKey.length})',
    );
  }

  static void _parseEnv(String raw) {
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final eq = trimmed.indexOf('=');
      if (eq <= 0) continue;
      final key = trimmed.substring(0, eq).trim();
      var value = trimmed.substring(eq + 1).trim();
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }
      if (key.isNotEmpty) _fallback[key] = value;
    }
  }

  static String get _youtubeFromDotenv => dotenv.isInitialized
      ? (dotenv.maybeGet('YOUTUBE_API_KEY')?.trim() ?? '')
      : '';

  static String _get(String key, {String defineFallback = ''}) {
    final fromFile = dotenv.isInitialized
        ? (dotenv.maybeGet(key)?.trim() ?? '')
        : '';
    if (fromFile.isNotEmpty) return fromFile;
    final fromFallback = _fallback[key]?.trim() ?? '';
    if (fromFallback.isNotEmpty) return fromFallback;
    return defineFallback;
  }

  static String get youtubeApiKey => _get(
    'YOUTUBE_API_KEY',
    defineFallback: const String.fromEnvironment('YOUTUBE_API_KEY'),
  );

  static String get googleCseKey => _get(
    'GOOGLE_CSE_KEY',
    defineFallback: const String.fromEnvironment('GOOGLE_CSE_KEY'),
  );

  static String get googleCseId => _get(
    'GOOGLE_CSE_ID',
    defineFallback: const String.fromEnvironment('GOOGLE_CSE_ID'),
  );

  static String get googleServerClientId => _get(
    'GOOGLE_SERVER_CLIENT_ID',
    defineFallback: const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
  );

  static String get googleIosClientId => _get(
    'GOOGLE_IOS_CLIENT_ID',
    defineFallback: const String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),
  );
}
