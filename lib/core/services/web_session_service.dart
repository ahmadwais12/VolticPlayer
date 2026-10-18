import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// Persists WebView login cookies/sessions across icon opens and app restarts.
class WebSessionService {
  WebSessionService._();

  static const _prefsKey = 'web_session_cookies_v1';

  static const _mobileChromeUa =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

  static const _desktopChromeUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  static String userAgentFor(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    if (host.contains('whatsapp')) return _desktopChromeUa;
    return _mobileChromeUa;
  }

  /// Enable third-party cookies (needed for Facebook / Instagram / Google login).
  static Future<void> configurePersistentCookies(
    WebViewController controller,
  ) async {
    try {
      if (WebViewPlatform.instance is AndroidWebViewPlatform) {
        final androidController =
            controller.platform as AndroidWebViewController;
        final cookieManager = WebViewCookieManager();
        final androidCookies =
            cookieManager.platform as AndroidWebViewCookieManager;
        await androidCookies.setAcceptThirdPartyCookies(
          androidController,
          true,
        );
      } else if (WebViewPlatform.instance is WebKitWebViewPlatform) {
        // WKWebView already uses the persistent default data store.
      }
    } catch (e) {
      debugPrint('[WebSession] configurePersistentCookies failed: $e');
    }
  }

  /// Restore previously saved cookies for this site before the first load.
  static Future<void> restoreCookies(String pageUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;

      final Map<String, dynamic> store =
          jsonDecode(raw) as Map<String, dynamic>;
      final cookieManager = WebViewCookieManager();
      final hosts = _relatedHosts(pageUrl);

      for (final entry in store.entries) {
        final savedUrl = entry.key;
        final savedHost = Uri.tryParse(savedUrl)?.host.toLowerCase();
        if (savedHost == null) continue;
        if (!hosts.any((h) => _hostMatches(savedHost, h))) continue;

        final list = entry.value;
        if (list is! List) continue;
        for (final item in list) {
          if (item is! Map) continue;
          final name = item['name']?.toString();
          final value = item['value']?.toString();
          if (name == null || value == null || name.isEmpty) continue;
          final path = item['path']?.toString() ?? '/';
          final rawDomain = item['domain']?.toString() ?? savedHost;
          try {
            await cookieManager.setCookie(
              WebViewCookie(
                name: name,
                value: value,
                domain: _setCookieDomain(rawDomain, savedUrl),
                path: path.isEmpty ? '/' : path,
              ),
            );
          } catch (e) {
            debugPrint('[WebSession] skip cookie $name: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('[WebSession] restoreCookies failed: $e');
    }
  }

  /// Snapshot cookies for the current page (and auth hosts) into local storage.
  static Future<void> persistCookies(String pageUrl) async {
    try {
      final uri = Uri.tryParse(pageUrl);
      if (uri == null || !uri.hasScheme) return;

      final cookieManager = WebViewCookieManager();
      final prefs = await SharedPreferences.getInstance();
      final existingRaw = prefs.getString(_prefsKey);
      final Map<String, dynamic> store = existingRaw == null || existingRaw.isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(
              jsonDecode(existingRaw) as Map<String, dynamic>,
            );

      final urlsToCapture = <String>{
        pageUrl,
        ..._relatedUrls(pageUrl),
      };

      for (final url in urlsToCapture) {
        final parsed = Uri.tryParse(url);
        if (parsed == null) continue;
        List<WebViewCookie> cookies;
        try {
          cookies = await cookieManager.getCookies(domain: parsed);
        } catch (_) {
          continue;
        }
        if (cookies.isEmpty) continue;
        store[_cookieBucketKey(parsed)] = cookies
            .map(
              (c) => <String, String>{
                'name': c.name,
                'value': c.value,
                'domain': c.domain.isNotEmpty ? c.domain : parsed.host,
                'path': c.path.isNotEmpty ? c.path : '/',
              },
            )
            .toList();
      }

      await prefs.setString(_prefsKey, jsonEncode(store));
    } catch (e) {
      debugPrint('[WebSession] persistCookies failed: $e');
    }
  }

  static String _cookieBucketKey(Uri uri) =>
      '${uri.scheme}://${uri.host}/';

  /// Android CookieManager.setCookie expects a URL; iOS expects a host domain.
  static String _setCookieDomain(String rawDomain, String fallbackUrl) {
    final isAndroid = WebViewPlatform.instance is AndroidWebViewPlatform;
    if (isAndroid) {
      if (rawDomain.startsWith('http://') || rawDomain.startsWith('https://')) {
        return rawDomain;
      }
      final host = rawDomain.startsWith('.') ? rawDomain.substring(1) : rawDomain;
      return 'https://$host/';
    }

    if (rawDomain.startsWith('http://') || rawDomain.startsWith('https://')) {
      return Uri.tryParse(rawDomain)?.host ??
          Uri.tryParse(fallbackUrl)?.host ??
          rawDomain;
    }
    return rawDomain;
  }

  static bool _hostMatches(String host, String target) {
    return host == target || host.endsWith('.$target');
  }

  static List<String> _relatedHosts(String pageUrl) {
    final host = Uri.tryParse(pageUrl)?.host.toLowerCase() ?? '';
    if (host.contains('youtube') || host.contains('google')) {
      return const [
        'youtube.com',
        'google.com',
        'googleapis.com',
        'gstatic.com',
        'ytimg.com',
      ];
    }
    if (host.contains('facebook') || host.contains('fbcdn') || host.contains('fb.com')) {
      return const [
        'facebook.com',
        'fb.com',
        'fbcdn.net',
        'accountkit.com',
      ];
    }
    if (host.contains('instagram') || host.contains('cdninstagram')) {
      return const [
        'instagram.com',
        'cdninstagram.com',
        'facebook.com',
      ];
    }
    if (host.contains('whatsapp')) {
      return const [
        'whatsapp.com',
        'whatsapp.net',
      ];
    }
    return host.isEmpty ? const <String>[] : [host];
  }

  static List<String> _relatedUrls(String pageUrl) {
    final host = Uri.tryParse(pageUrl)?.host.toLowerCase() ?? '';
    if (host.contains('youtube') || host.contains('google')) {
      return const [
        'https://www.youtube.com/',
        'https://m.youtube.com/',
        'https://accounts.google.com/',
        'https://www.google.com/',
      ];
    }
    if (host.contains('facebook') || host.contains('fb.com')) {
      return const [
        'https://www.facebook.com/',
        'https://m.facebook.com/',
        'https://facebook.com/',
      ];
    }
    if (host.contains('instagram')) {
      return const [
        'https://www.instagram.com/',
        'https://instagram.com/',
        'https://www.facebook.com/',
      ];
    }
    if (host.contains('whatsapp')) {
      return const [
        'https://web.whatsapp.com/',
        'https://www.whatsapp.com/',
      ];
    }
    final uri = Uri.tryParse(pageUrl);
    if (uri == null) return const [];
    return ['${uri.scheme}://${uri.host}/'];
  }
}
