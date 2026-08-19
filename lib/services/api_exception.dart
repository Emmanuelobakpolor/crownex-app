/// Raised for any failed API call, carrying a user-displayable [message]
/// plus the backend's machine-readable [code] when available.
class ApiException implements Exception {
  ApiException(this.message, {this.code, this.statusCode, this.fieldErrors});

  final String message;
  final String? code;
  final int? statusCode;
  final Map<String, List<String>>? fieldErrors;

  /// True when [SessionGuard] has already taken over — the user is being
  /// redirected to sign in, so callers should swallow this instead of also
  /// showing their own error UI.
  bool get isSessionExpired => code == 'session_expired';

  @override
  String toString() => message;
}
