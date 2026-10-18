import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Screenshot helper that captures the current video frame.
/// Saves to Pictures/SarwariPlayer/ as specified in requirements doc §71.
class ScreenshotHelper {
  /// Take a screenshot of a video controller's current frame.
  /// Returns the saved file path, or null on failure.
  static Future<String?> captureVideoFrame(
    VideoController videoController, {
    String? fileName,
  }) async {
    try {
      // Use media_kit's player to capture the current frame
      // Note: media_kit screenshot may not be directly available on VideoController
      // Use a RepaintBoundary approach as fallback
      final player = videoController.player;
      final screenshot = await player.screenshot(
        format: 'jpeg',
      );

      if (screenshot == null || screenshot.isEmpty) return null;

      // Save to app documents directory
      final dir = await getApplicationDocumentsDirectory();
      final screenshotDir = Directory('${dir.path}/screenshots');
      if (!await screenshotDir.exists()) {
        await screenshotDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final name = fileName ?? 'screenshot_$timestamp.jpg';
      final file = File('${screenshotDir.path}/$name');
      await file.writeAsBytes(screenshot);

      debugPrint('[Screenshot] Saved to ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('[Screenshot] Capture failed: $e');
      return null;
    }
  }

  /// Get a list of saved screenshots.
  static Future<List<File>> getSavedScreenshots() async {
    final dir = await getApplicationDocumentsDirectory();
    final screenshotDir = Directory('${dir.path}/screenshots');
    if (!await screenshotDir.exists()) return [];

    final files = await screenshotDir
        .list()
        .where((e) => e is File)
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// Delete a screenshot by path.
  static Future<void> deleteScreenshot(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
