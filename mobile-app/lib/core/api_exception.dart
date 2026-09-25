/// Typed HTTP error surfaced to providers/screens.
///
/// Backend conventions (backend/src/middleware/* + controllers):
/// - 400 validation, 401 missing/invalid/expired token, 403 role or
///   unassigned-staff denial, 404 missing OR cross-owner (IDOR guard),
///   409 godown delete blocked by inventory refs / duplicate email.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isNetworkError => statusCode == -1;

  /// User-facing message; never exposes tokens or internals.
  String get displayMessage {
    if (isNetworkError) {
      return 'Cannot reach the server. Check your connection and API_BASE_URL.';
    }
    if (isUnauthorized) return 'Session expired. Please log in again.';
    if (isForbidden) return 'Permission denied for this action.';
    if (isNotFound) return 'Not found or not accessible.';
    return message;
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
