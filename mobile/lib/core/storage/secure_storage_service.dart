import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
    : _storage =
          storage ?? const FlutterSecureStorage(aOptions: AndroidOptions());

  static const _accessTokenKey = 'zuno_access_token';
  static const _refreshTokenKey = 'zuno_refresh_token';

  final FlutterSecureStorage _storage;

  /// Which account THIS copy of the app signed in as, held in memory only.
  ///
  /// On the web the saved login is shared by every tab of the site. Signing in as the business in
  /// one tab replaces the customer's login in another, and that tab then quietly sends and reads
  /// as the business — which is how one person's chat messages ended up on the wrong side. Keeping
  /// the owner here, per tab, lets the request interceptor notice the swap and stop.
  String? _ownerUserId;

  String? get ownerUserId => _ownerUserId;

  /// Takes on the saved login's account, for a tab that did not sign in itself (a page reload
  /// restoring the session).
  void adoptOwner(String? userId) => _ownerUserId = userId;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _ownerUserId = userIdOf(accessToken);
    // One after the other, never together. On the web the plugin encrypts with a key it creates on
    // the first write; two writes at once in a fresh browser each created their own key, the second
    // replaced the first, and one token could no longer be read back. That was a first sign-in that
    // got 401 on every request and was signed out by the next reload.
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> clearTokens() async {
    _ownerUserId = null;
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }

  /// The account id inside an access token (its `sub` claim), or null if it cannot be read.
  ///
  /// Read without checking the signature — the server does that. Here it only answers "is this
  /// still the same person", which a forged token could not make worse.
  static String? userIdOf(String? token) {
    if (token == null) return null;
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final claims = jsonDecode(payload);
      if (claims is! Map<String, dynamic>) return null;
      return (claims['sub'] ??
              claims['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'])
          ?.toString();
    } on FormatException {
      return null;
    }
  }
}
