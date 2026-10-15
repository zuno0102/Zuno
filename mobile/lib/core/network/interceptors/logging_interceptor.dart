import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

/// Request/response logging — only added in debug builds, since logging could otherwise
/// leak tokens or PII into release-build device logs.
Interceptor? buildLoggingInterceptor() {
  if (!kDebugMode) {
    return null;
  }

  return PrettyDioLogger(requestHeader: false, compact: true);
}
