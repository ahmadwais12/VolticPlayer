import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_env.dart';

/// A Google profile snapshot that is safe to keep on the device.
/// Tokens and passwords are never stored.
class SignedInProfile {
  const SignedInProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.photoUrl,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;

  factory SignedInProfile.fromAccount(GoogleSignInAccount account) =>
      SignedInProfile(
        id: account.id,
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
      );

  static SignedInProfile? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['id'];
    final email = value['email'];
    if (id is! String || email is! String) return null;
    return SignedInProfile(
      id: id,
      email: email,
      displayName: value['display_name'] as String?,
      photoUrl: value['photo_url'] as String?,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'email': email,
    'display_name': displayName,
    'photo_url': photoUrl,
  };
}

/// Minimal Google account identity access for the Profile screen.
/// The app receives profile fields from Google's OAuth flow; it never asks for
/// or stores the user's Google password.
class GoogleProfileService {
  GoogleProfileService._();

  static final GoogleProfileService instance = GoogleProfileService._();
  static Future<void>? _initializeFuture;

  /// Shared with the downloader so private-folder access stays in sync.
  static const signedInFlagKey = 'downloads_youtube_signed_in_v1';
  static const _profileKey = 'profile_signed_in_account_v1';

  SignedInProfile? _cachedProfile;

  String get _serverClientId => AppEnv.googleServerClientId;

  /// iOS authenticates against its own OAuth client; Android matches the app
  /// by package name + signing SHA-1 and must not be given a `clientId`.
  String? get _platformClientId {
    if (defaultTargetPlatform != TargetPlatform.iOS) return null;
    final id = AppEnv.googleIosClientId;
    return id.isEmpty ? null : id;
  }

  bool get isConfigured =>
      _serverClientId.isNotEmpty &&
      (defaultTargetPlatform != TargetPlatform.iOS ||
          _platformClientId != null);

  Future<void> initialize() {
    if (!isConfigured) return Future<void>.value();
    return _initializeFuture ??= GoogleSignIn.instance.initialize(
      clientId: _platformClientId,
      serverClientId: _serverClientId,
    );
  }

  /// The signed-in profile, or `null` when the user is signed out.
  ///
  /// The plugin's lightweight restore only succeeds while Play Services still
  /// hands back a cached credential, so the last known profile is persisted as
  /// well. Without that, every screen that is rebuilt after a successful
  /// sign-in would fall back to the signed-out state.
  Future<SignedInProfile?> currentProfile() async {
    if (_cachedProfile != null) return _cachedProfile;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw != null) {
      try {
        final stored = SignedInProfile.fromJson(jsonDecode(raw));
        if (stored != null) return _cachedProfile = stored;
      } catch (_) {
        await prefs.remove(_profileKey);
      }
    }

    if (!isConfigured) return null;
    try {
      final account = await restoreAccount();
      if (account == null) return null;
      return await _persist(prefs, SignedInProfile.fromAccount(account));
    } catch (_) {
      return null;
    }
  }

  Future<GoogleSignInAccount?> restoreAccount() async {
    await initialize();
    if (!isConfigured) return null;
    final attempt = GoogleSignIn.instance.attemptLightweightAuthentication();
    if (attempt == null) return null;
    return attempt;
  }

  Future<GoogleSignInAccount> signIn() async {
    await initialize();
    if (!isConfigured) {
      throw StateError('Google sign-in is not configured for this app.');
    }
    final account = await GoogleSignIn.instance.authenticate();
    await _persist(
      await SharedPreferences.getInstance(),
      SignedInProfile.fromAccount(account),
    );
    return account;
  }

  Future<void> signOut() async {
    _cachedProfile = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
    await prefs.setBool(signedInFlagKey, false);

    if (!isConfigured) return;
    await initialize();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // The local session is already cleared, so a plugin-side failure here is
      // not worth surfacing to the user.
    }
  }

  Future<SignedInProfile> _persist(
    SharedPreferences prefs,
    SignedInProfile profile,
  ) async {
    _cachedProfile = profile;
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
    await prefs.setBool(signedInFlagKey, true);
    return profile;
  }
}
