import 'package:dio/dio.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/network/interceptors/auth_interceptor.dart';
import 'package:zuno/core/network/interceptors/envelope_unwrap_interceptor.dart';
import 'package:zuno/core/network/interceptors/logging_interceptor.dart';
import 'package:zuno/core/network/interceptors/retry_interceptor.dart';

Dio buildDioClient({required AuthInterceptor authInterceptor}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      contentType: 'application/json',
    ),
  );

  dio.interceptors.add(EnvelopeUnwrapInterceptor());
  dio.interceptors.add(authInterceptor);
  dio.interceptors.add(buildRetryInterceptor(dio));

  final loggingInterceptor = buildLoggingInterceptor();
  if (loggingInterceptor != null) {
    dio.interceptors.add(loggingInterceptor);
  }

  return dio;
}
