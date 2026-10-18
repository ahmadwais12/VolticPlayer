/// Typed failures used across the domain & data layers.
///
/// UI maps these to user-friendly messages (see [FailureMessage]).
abstract class Failure {
  final String message;
  const Failure(this.message);
}

class MediaNotFoundFailure extends Failure {
  MediaNotFoundFailure([super.message = 'Media not found.']);
}

class MediaUnsupportedFailure extends Failure {
  MediaUnsupportedFailure([super.message = 'This format is not supported.']);
}

class DecoderFailure extends Failure {
  DecoderFailure([super.message = 'Could not decode this media.']);
}

class PermissionFailure extends Failure {
  PermissionFailure([super.message = 'Storage permission is required.']);
}

class StorageUnavailableFailure extends Failure {
  StorageUnavailableFailure([super.message = 'Storage is unavailable.']);
}

class NetworkFailure extends Failure {
  NetworkFailure([super.message = 'Network error, check your connection.']);
}

class AuthenticationFailure extends Failure {
  AuthenticationFailure([super.message = 'Authentication failed.']);
}

class DatabaseFailure extends Failure {
  DatabaseFailure([super.message = 'A database error occurred.']);
}

class UnknownFailure extends Failure {
  UnknownFailure([super.message = 'Something went wrong.']);
}

/// Maps a [Failure] to a human-readable message for the UI.
extension FailureMessage on Failure {
  String get userMessage => message;
}

Failure mapException(Object e) {
  final s = e.toString().toLowerCase();
  if (s.contains('permission')) return PermissionFailure();
  if (s.contains('network') || s.contains('socket')) return NetworkFailure();
  if (s.contains('not found')) return MediaNotFoundFailure();
  if (s.contains('unsupported')) return MediaUnsupportedFailure();
  if (s.contains('decode')) return DecoderFailure();
  if (s.contains('database') || s.contains('drift')) return DatabaseFailure();
  return UnknownFailure(e.toString());
}
