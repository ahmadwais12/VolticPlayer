import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Wraps permission_handler so the rest of the app never touches the
/// platform plugin directly. This is the only place that asks for permits.
class PermissionService {
  const PermissionService();

  /// Request all media-related permissions required to scan device storage.
  /// Returns true if at least video or audio permission is granted.
  Future<bool> requestMediaPermissions() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      return _requestAndroidPermissions();
    } else if (Platform.isIOS) {
      return _requestIOSPermissions();
    }
    return false;
  }

  /// Android 13+ (API 33) splits media permissions into granular types.
  Future<bool> _requestAndroidPermissions() async {
    // Android 13+ (API 33+) — granular media permissions
    final audioStatus = await Permission.audio.request();
    final videoStatus = await Permission.videos.request();

    // If granular permissions are available and at least audio OR video granted
    if (audioStatus.isGranted || videoStatus.isGranted) return true;

    // Pre-Android 13 fallback — legacy read permission (declared with
    // maxSdkVersion="32" in the manifest). MANAGE_EXTERNAL_STORAGE is
    // intentionally NOT declared (restricted Play policy), so it is never
    // requested — that request was always auto-denied.
    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  Future<bool> _requestIOSPermissions() async {
    // iOS requires photos permission to access media library
    final status = await Permission.photos.request();
    return status.isGranted || status.isLimited;
  }

  /// Legacy shared-storage access (only needed when writing outside the
  /// app's own directories). App-private storage — where downloads are
  /// saved — never requires any permission.
  Future<bool> requestStorage() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      return status.isGranted;
    }
    return true;
  }

  /// Android 13+ runtime permission for notifications. Needed so playback
  /// controls (media notification / foreground service) are visible.
  Future<bool> requestNotifications() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.notification.request();
    return status.isGranted || status.isProvisional;
  }

  Future<bool> requestPhotos() async {
    final status = await Permission.photos.request();
    return status.isGranted || status.isLimited;
  }

  /// True once the user picked "Don't ask again" (or denied twice), so a
  /// runtime request will no longer show a dialog. Recovery is via Settings.
  /// Only meaningful when [hasMediaAccess] is already false.
  Future<bool> isMediaPermanentlyDenied() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      if ((await Permission.audio.status).isPermanentlyDenied) return true;
      if ((await Permission.videos.status).isPermanentlyDenied) return true;
      return false;
    }
    if (Platform.isIOS) {
      final status = await Permission.photos.status;
      return status.isPermanentlyDenied || status.isRestricted;
    }
    return false;
  }

  Future<bool> hasStorage() async => await Permission.storage.isGranted;

  /// Check if we have media access permissions
  Future<bool> hasMediaAccess() async {
    if (Platform.isAndroid) {
      if (await Permission.audio.isGranted) return true;
      if (await Permission.videos.isGranted) return true;
      if (await Permission.storage.isGranted) return true;
      return false;
    }
    if (Platform.isIOS) {
      final status = await Permission.photos.status;
      return status.isGranted || status.isLimited;
    }
    return false;
  }

  Future<void> openSettings() => openAppSettings();
}
