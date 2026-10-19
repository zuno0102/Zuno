import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/network/interceptors/auth_interceptor.dart';
import 'package:zuno/core/storage/secure_storage_service.dart';

/// On the web every tab shares one saved login. Signing in as the business in one tab replaced the
/// customer's login in another, and that tab went on sending chat messages as the business — so
/// both sides' messages showed as "mine". A tab now notices the swap and stops instead.

/// A token whose only interesting part is who it belongs to.
String tokenFor(String userId) {
  String part(Map<String, Object> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'sub': userId})}.signature';
}

/// Saved login held in memory, standing in for the browser storage all tabs share.
class _SharedStorage extends SecureStorageService {
  String? token;

  @override
  Future<String?> getAccessToken() async => token;

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    adoptOwner(SecureStorageService.userIdOf(accessToken));
    token = accessToken;
  }
}

class _OkAdapter implements HttpClientAdapter {
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    return ResponseBody.fromString('{}', 200, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _SharedStorage storage;
  late _OkAdapter adapter;
  late Dio dio;
  var switched = 0;

  setUp(() {
    storage = _SharedStorage();
    adapter = _OkAdapter();
    switched = 0;
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        AuthInterceptor(
          secureStorage: storage,
          refreshAccessToken: (_) async => null,
          onSessionExpired: () {},
          onAccountSwitched: () => switched++,
        ),
      );
  });

  test('reads the account id out of a token', () {
    expect(SecureStorageService.userIdOf(tokenFor('customer-1')), 'customer-1');
    expect(SecureStorageService.userIdOf('not-a-token'), isNull);
    expect(SecureStorageService.userIdOf(null), isNull);
  });

  test('a tab signed in as the customer sends as the customer', () async {
    await storage.saveTokens(accessToken: tokenFor('customer-1'), refreshToken: 'r');

    await dio.get<dynamic>('/bookings/b-1/messages');

    expect(adapter.last!.headers['Authorization'], 'Bearer ${tokenFor('customer-1')}');
    expect(switched, 0);
  });

  test('when another tab signs in as the business, this tab stops instead of sending as them', () async {
    await storage.saveTokens(accessToken: tokenFor('customer-1'), refreshToken: 'r');

    // The other tab's login lands in the shared storage; this tab still believes it is the customer.
    storage.token = tokenFor('business-9');

    await expectLater(
      dio.post<dynamic>('/bookings/b-1/messages', data: {'body': 'Hello'}),
      throwsA(
        isA<DioException>().having(
          (e) => e.message,
          'message',
          AuthInterceptor.accountSwitchedMessage,
        ),
      ),
    );
    expect(switched, 1);
    expect(adapter.last, isNull, reason: 'nothing was sent as the wrong person');
  });

  test('a page reload simply becomes whoever the saved login belongs to', () async {
    // Fresh tab: no owner yet, a login already saved.
    storage.token = tokenFor('business-9');

    await dio.get<dynamic>('/auth/me');

    expect(storage.ownerUserId, 'business-9');
    expect(switched, 0);
  });
}
