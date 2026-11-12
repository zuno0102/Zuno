import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/network/interceptors/retry_interceptor.dart';
import 'package:zuno/core/network/server_warm_up.dart';

DioException _error(String method, DioExceptionType type, {int? status}) =>
    DioException(
      requestOptions: RequestOptions(path: '/x', method: method),
      type: type,
      response: status == null
          ? null
          : Response<void>(
              requestOptions: RequestOptions(path: '/x'),
              statusCode: status,
            ),
    );

/// Records the requests it is asked for and answers each one at once.
class _Recorder extends Interceptor {
  final paths = <String>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    paths.add(options.uri.toString());
    if (options.uri.host == 'down.test') {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );
      return;
    }
    handler.resolve(Response<void>(requestOptions: options, statusCode: 401));
  }
}

void main() {
  group('retry', () {
    test('a read is retried after a timeout or a 5xx', () async {
      expect(
        await retryEvaluator(_error('GET', DioExceptionType.receiveTimeout), 1),
        isTrue,
      );
      expect(
        await retryEvaluator(
          _error('GET', DioExceptionType.badResponse, status: 503),
          1,
        ),
        isTrue,
      );
    });

    test(
      'a change that may have reached the server is never sent twice',
      () async {
        for (final method in ['POST', 'PATCH']) {
          expect(
            await retryEvaluator(
              _error(method, DioExceptionType.receiveTimeout),
              1,
            ),
            isFalse,
            reason: '$method after a slow reply',
          );
          expect(
            await retryEvaluator(
              _error(method, DioExceptionType.badResponse, status: 500),
              1,
            ),
            isFalse,
            reason: '$method after a 500',
          );
        }
      },
    );

    test('a change that never left is sent again', () async {
      expect(
        await retryEvaluator(
          _error('POST', DioExceptionType.connectionError),
          1,
        ),
        isTrue,
      );
      expect(
        await retryEvaluator(
          _error('POST', DioExceptionType.connectionTimeout),
          1,
        ),
        isTrue,
      );
    });

    test('a client error is never retried', () async {
      expect(
        await retryEvaluator(
          _error('GET', DioExceptionType.badResponse, status: 401),
          1,
        ),
        isFalse,
      );
    });
  });

  test('warming up knocks once on each server and ignores failures', () async {
    final recorder = _Recorder();
    final dio = Dio()..interceptors.add(recorder);

    await warmUpServers([
      'https://a.test',
      'https://down.test',
      'https://a.test',
    ], client: dio);

    expect(recorder.paths, [
      'https://a.test/health',
      'https://down.test/health',
    ]);
  });
}
