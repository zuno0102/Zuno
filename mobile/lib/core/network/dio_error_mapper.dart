import 'package:dio/dio.dart';
import 'package:zuno/core/error/app_exceptions.dart';

/// Translates a [DioException] into an [AppException] so repositories/data sources never
/// leak Dio or HTTP-status details into the domain/presentation layers.
AppException mapDioExceptionToAppException(DioException error) {
  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.connectionError) {
    return const NetworkAppException(
      'Unable to reach the server. Check your connection and try again.',
    );
  }

  final statusCode = error.response?.statusCode;
  final data = error.response?.data;

  if (statusCode == 400 &&
      data is Map<String, dynamic> &&
      data['errors'] is Map) {
    final rawErrors = data['errors'] as Map;
    final fieldErrors = rawErrors.map(
      (key, value) => MapEntry(
        key.toString(),
        (value as List).map((e) => e.toString()).toList(),
      ),
    );
    final message = data['message']?.toString() ?? 'Validation failed.';
    return ValidationAppException(message, fieldErrors);
  }

  final message =
      _extractMessage(data) ?? error.message ?? 'Something went wrong.';
  final resolvedStatusCode = statusCode ?? 0;

  return switch (resolvedStatusCode) {
    401 => UnauthorizedAppException(message),
    404 => NotFoundAppException(message),
    429 => const RateLimitedAppException(
      'Too many attempts. Please wait a moment and try again.',
    ),
    >= 500 => const ServerAppException(
      'The server encountered an error. Please try again later.',
    ),
    _ => UnknownAppException(message),
  };
}

String? _extractMessage(dynamic data) {
  if (data is Map<String, dynamic>) {
    return data['message']?.toString() ?? data['title']?.toString();
  }
  return null;
}
