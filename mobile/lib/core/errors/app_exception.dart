/// Base application exception for shared error handling.
class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'AppException: $message';
}

/// Network-related failure (connectivity, timeouts, HTTP transport).
class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause});
}

/// Unexpected server or client failure without a domain-specific mapping yet.
class UnexpectedException extends AppException {
  const UnexpectedException(super.message, {super.cause});
}
