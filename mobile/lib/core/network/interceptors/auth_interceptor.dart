import 'dart:async';

import 'package:dio/dio.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/storage/secure_storage_service.dart';

/// Attaches the access token to outgoing requests and, on a 401, performs a single
/// in-flight token refresh shared across concurrent requests (via [_refreshCompleter])
/// so simultaneous 401s don't trigger N parallel refresh calls. If refresh itself fails,
/// stored tokens are cleared and [onSessionExpired] is invoked so the app can redirect to login.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required SecureStorageService secureStorage,
    required Future<String?> Function(String refreshToken) refreshAccessToken,
    required void Function() onSessionExpired,
    void Function()? onAccountSwitched,
  }) : _secureStorage = secureStorage,
       _refreshAccessToken = refreshAccessToken,
       _onSessionExpired = onSessionExpired,
       _onAccountSwitched = onAccountSwitched;

  final SecureStorageService _secureStorage;
  final Future<String?> Function(String refreshToken) _refreshAccessToken;
  final void Function() _onSessionExpired;

  /// Another tab signed in as a different account and replaced the saved login.
  final void Function()? _onAccountSwitched;

  /// What a request stopped for that reason fails with — shown on whatever screen made it.
  static const accountSwitchedMessage =
      'You signed in as another account in another tab. Sign in again here.';

  Completer<String?>? _refreshCompleter;

  static const _noAuthPaths = [
    ApiConstants.registerPath,
    ApiConstants.loginPath,
    ApiConstants.refreshTokenPath,
    ApiConstants.forgotPasswordPath,
    ApiConstants.resetPasswordPath,
  ];

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_noAuthPaths.contains(options.path)) {
      final accessToken = await _secureStorage.getAccessToken();
      if (accessToken != null) {
        final tokenUser = SecureStorageService.userIdOf(accessToken);
        final owner = _secureStorage.ownerUserId;

        if (owner == null) {
          // A reload restoring the saved session: this tab is whoever that login belongs to.
          _secureStorage.adoptOwner(tokenUser);
        } else if (tokenUser != null && tokenUser != owner) {
          // The saved login is now somebody else's — another tab signed in over it. Going on would
          // send this screen's messages, bookings and changes as that other person.
          _onAccountSwitched?.call();
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.cancel,
              message: accountSwitchedMessage,
            ),
          );
          return;
        }

        options.headers['Authorization'] = 'Bearer $accessToken';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried =
        err.requestOptions.extra['retriedAfterRefresh'] == true;

    if (!isUnauthorized ||
        alreadyRetried ||
        _noAuthPaths.contains(err.requestOptions.path)) {
      handler.next(err);
      return;
    }

    final newAccessToken = await _refreshAccessTokenSingleFlight();

    if (newAccessToken == null) {
      _onSessionExpired();
      handler.next(err);
      return;
    }

    try {
      final retryOptions = err.requestOptions
        ..headers['Authorization'] = 'Bearer $newAccessToken'
        ..extra['retriedAfterRefresh'] = true;

      final response = await Dio().fetch<dynamic>(retryOptions);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  Future<String?> _refreshAccessTokenSingleFlight() {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<String?>();
    _refreshCompleter = completer;

    _performRefresh()
        .then(completer.complete)
        .catchError((Object _) {
          completer.complete(null);
        })
        .whenComplete(() {
          _refreshCompleter = null;
        });

    return completer.future;
  }

  Future<String?> _performRefresh() async {
    final refreshToken = await _secureStorage.getRefreshToken();
    if (refreshToken == null) {
      return null;
    }

    final newAccessToken = await _refreshAccessToken(refreshToken);
    if (newAccessToken == null) {
      await _secureStorage.clearTokens();
    }
    return newAccessToken;
  }
}
