import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';

/// Retries only on transient failures (timeouts, connection errors, 5xx, 408/429) with
/// capped exponential backoff — never retries genuine 4xx client errors (400/401/403/404),
/// so a bad request or expired session fails fast instead of being retried uselessly.
///
/// And never sends a change twice: a POST or PATCH that may have reached the server — a slow
/// reply, a 5xx — is not retried, or a post, an order or a payment could be made twice. Only a
/// request that never left (no connection) is sent again; reads and PUT/DELETE, which give the
/// same result however often they run, are retried as before.
Interceptor buildRetryInterceptor(Dio dio) {
  return RetryInterceptor(
    dio: dio,
    retries: 3,
    retryDelays: const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ],
    retryEvaluator: retryEvaluator,
  );
}

const _repeatableMethods = {'GET', 'HEAD', 'OPTIONS', 'PUT', 'DELETE'};

/// The failures where the request is known not to have reached the server.
const _neverSent = {
  DioExceptionType.connectionTimeout,
  DioExceptionType.connectionError,
};

/// Whether [error] is worth another try. Public for its tests.
FutureOr<bool> retryEvaluator(DioException error, int attempt) {
  final method = error.requestOptions.method.toUpperCase();
  if (!_repeatableMethods.contains(method) &&
      !_neverSent.contains(error.type)) {
    return false;
  }
  return RetryInterceptor.defaultRetryEvaluator(error, attempt);
}
