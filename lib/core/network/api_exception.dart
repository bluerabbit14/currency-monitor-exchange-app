/// The backend returned an error envelope or a non-2xx status.
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.fieldErrors = const {},
  });

  final int statusCode;
  final String message;

  /// Backend error code, e.g. `GOOGLE_ACCOUNT_CONFLICT`, when present.
  final String? code;

  /// Field name -> validation message, for 400 validation failures.
  final Map<String, String> fieldErrors;

  @override
  String toString() => 'ApiException($statusCode, $code, $message)';
}

/// No usable response: offline, DNS failure, timeout, TLS error, etc.
class NetworkException implements Exception {
  const NetworkException([this.message = 'Network error']);

  final String message;

  @override
  String toString() => 'NetworkException($message)';
}
