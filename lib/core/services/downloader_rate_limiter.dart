/// Sliding-window rate limiter used to protect the downloader endpoints
/// from excessive requests (prompt §14).
///
/// Pure Dart with an injectable clock so it can be unit tested without
/// waiting on real time.
class SlidingWindowRateLimiter {
  SlidingWindowRateLimiter({
    required this.limit,
    this.window = const Duration(minutes: 1),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Maximum number of permitted operations per [window].
  final int limit;

  /// Length of the sliding window.
  final Duration window;

  final DateTime Function() _now;
  final List<DateTime> _events = [];

  /// Number of operations still available in the current window.
  int get remaining {
    _prune();
    return (limit - _events.length).clamp(0, limit);
  }

  /// How long the caller must wait before the next operation is allowed.
  Duration get retryAfter {
    _prune();
    if (_events.length < limit) return Duration.zero;
    final oldest = _events.first;
    final ready = oldest.add(window);
    final diff = ready.difference(_now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Attempts to consume one slot. Returns `false` when the caller has
  /// exceeded [limit] within [window].
  bool allow() {
    _prune();
    if (_events.length >= limit) return false;
    _events.add(_now());
    return true;
  }

  void reset() => _events.clear();

  void _prune() {
    final cutoff = _now().subtract(window);
    _events.removeWhere((t) => t.isBefore(cutoff));
  }
}
