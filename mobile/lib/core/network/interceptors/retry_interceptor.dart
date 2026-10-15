import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';

/// Retries only on transient failures (timeouts, connection errors, 5xx, 408/429) with
/// capped exponential backoff — never retries genuine 4xx client errors (400/401/403/404),
/// so a bad request or expired session fails fast instead of being retried uselessly.
Interceptor buildRetryInterceptor(Dio dio) {
  return RetryInterceptor(
    dio: dio,
    retries: 3,
    retryDelays: const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ],
  );
}
