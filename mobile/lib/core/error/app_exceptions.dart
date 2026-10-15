/// Thrown by the data layer so presentation code never depends on Dio or HTTP status codes.
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ValidationAppException extends AppException {
  const ValidationAppException(super.message, this.fieldErrors);

  /// Field name to the problems with it, exactly as the server reported them.
  final Map<String, List<String>> fieldErrors;

  /// Says what is actually wrong rather than that something is.
  ///
  /// The server's own summary reads "One or more validation errors occurred", which tells
  /// nobody which field to fix. The detail already arrived in [fieldErrors] — this is what
  /// finally puts it on screen.
  @override
  String toString() {
    final problems = fieldErrors.values.expand((m) => m).toList();
    if (problems.isEmpty) return message;
    if (problems.length == 1) return problems.first;
    return problems.map((p) => '\u2022 $p').join('\n');
  }
}

class UnauthorizedAppException extends AppException {
  const UnauthorizedAppException(super.message);
}

class NotFoundAppException extends AppException {
  const NotFoundAppException(super.message);
}

class NetworkAppException extends AppException {
  const NetworkAppException(super.message);
}

class ServerAppException extends AppException {
  const ServerAppException(super.message);
}

class RateLimitedAppException extends AppException {
  const RateLimitedAppException(super.message);
}

class UnknownAppException extends AppException {
  const UnknownAppException(super.message);
}
