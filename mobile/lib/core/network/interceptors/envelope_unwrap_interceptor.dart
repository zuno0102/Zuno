import 'package:dio/dio.dart';

/// The backend wraps every success response in `{ success, message, data, errors, correlationId,
/// timestamp }`. This interceptor unwraps `data` so data sources can keep parsing the inner
/// payload directly, unaware the envelope exists.
class EnvelopeUnwrapInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final body = response.data;
    if (body is Map<String, dynamic> &&
        body.containsKey('success') &&
        body.containsKey('data')) {
      response.data = body['data'];
    }
    handler.next(response);
  }
}
