/// In-app review service for VolticPlayer.
///
/// Requests a store rating after genuine positive experiences only.
/// Policy-safe: no spam, no first-launch prompts, no post-error prompts.
library;

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewService {
  ReviewService._();

  static const _kLastPromptKey = 'review_last_prompt_ms';
  static const _kPositiveActionsKey = 'review_positive_actions';
  static const _kMinPositiveActions = 3;
  static const _kMinDaysBetweenPrompts = 30;

  /// Call after a clearly positive action (finished video, completed download,
  /// playlist created, bookmark saved).
  static Future<void> recordPositiveAction() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = (prefs.getInt(_kPositiveActionsKey) ?? 0) + 1;
      await prefs.setInt(_kPositiveActionsKey, count);

      if (count >= _kMinPositiveActions) {
        await _maybeRequestReview(prefs);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ReviewService] recordPositiveAction error: $e');
      }
    }
  }

  static Future<void> _maybeRequestReview(SharedPreferences prefs) async {
    final lastMs = prefs.getInt(_kLastPromptKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final daysSinceLast = (now - lastMs) / (1000 * 60 * 60 * 24);

    if (lastMs != 0 && daysSinceLast < _kMinDaysBetweenPrompts) {
      if (kDebugMode) {
        debugPrint(
          '[ReviewService] Skipping — ${daysSinceLast.toStringAsFixed(1)} days since last prompt',
        );
      }
      return;
    }

    final inAppReview = InAppReview.instance;
    if (await inAppReview.isAvailable()) {
      await inAppReview.requestReview();
      await prefs.setInt(_kLastPromptKey, now);
      await prefs.setInt(_kPositiveActionsKey, 0);
    }
  }

  /// Opens the public store listing (Settings “Rate” action).
  static Future<void> openStoreListing() async {
    final inAppReview = InAppReview.instance;
    await inAppReview.openStoreListing(appStoreId: '000000000');
  }
}
