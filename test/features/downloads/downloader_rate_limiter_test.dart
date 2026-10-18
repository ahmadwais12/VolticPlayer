import 'package:flutter_test/flutter_test.dart';
import 'package:voltic_player/core/services/downloader_rate_limiter.dart';

void main() {
  group('SlidingWindowRateLimiter', () {
    test('allows up to the limit inside the window', () {
      var now = DateTime(2026, 1, 1, 10);
      final limiter = SlidingWindowRateLimiter(
        limit: 10,
        now: () => now,
      );

      for (var i = 0; i < 10; i++) {
        expect(limiter.allow(), isTrue, reason: 'request ${i + 1} allowed');
      }
      expect(limiter.allow(), isFalse, reason: '11th request rejected');
      expect(limiter.remaining, 0);
    });

    test('rejects beyond the limit and reports a retry delay', () {
      var now = DateTime(2026, 1, 1, 10);
      final limiter = SlidingWindowRateLimiter(limit: 5, now: () => now);
      for (var i = 0; i < 5; i++) {
        limiter.allow();
      }
      expect(limiter.allow(), isFalse);
      expect(limiter.retryAfter, greaterThan(Duration.zero));
      expect(limiter.retryAfter, lessThanOrEqualTo(const Duration(minutes: 1)));
    });

    test('frees slots as the window slides', () {
      var now = DateTime(2026, 1, 1, 10);
      final limiter = SlidingWindowRateLimiter(limit: 2, now: () => now);
      expect(limiter.allow(), isTrue);
      expect(limiter.allow(), isTrue);
      expect(limiter.allow(), isFalse);

      // Move past the first event: one slot frees up.
      now = now.add(const Duration(seconds: 1));
      expect(limiter.allow(), isFalse); // both still inside the window
      now = now.add(const Duration(seconds: 60)); // now t0 + 61s
      expect(limiter.allow(), isTrue); // first event expired
      expect(limiter.remaining, 1);
    });

    test('reset clears the window', () {
      final now = DateTime(2026, 1, 1, 10);
      final limiter = SlidingWindowRateLimiter(limit: 1, now: () => now);
      expect(limiter.allow(), isTrue);
      expect(limiter.allow(), isFalse);
      limiter.reset();
      expect(limiter.allow(), isTrue);
      expect(limiter.remaining, 0);
    });
  });
}
