import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/network/dio_client.dart';
import 'package:zuno/core/network/interceptors/auth_interceptor.dart';
import 'package:zuno/core/network/interceptors/envelope_unwrap_interceptor.dart';
import 'package:zuno/core/storage/secure_storage_service.dart';
import 'package:zuno/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:zuno/features/auth/data/models/auth_response_model.dart';
import 'package:zuno/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:zuno/features/auth/domain/repositories/auth_repository.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';

part 'auth_providers.g.dart';

@Riverpod(keepAlive: true)
SecureStorageService secureStorageService(Ref ref) => SecureStorageService();

/// A Dio instance used only to call the refresh-token endpoint from within
/// [AuthInterceptor] — it deliberately omits the auth interceptor, or a 401 during
/// refresh would recurse back into the refresh logic. It still needs the envelope
/// unwrapper, since the refresh response is wrapped like every other API response.
@Riverpod(keepAlive: true)
Dio refreshOnlyDioClient(Ref ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      contentType: 'application/json',
    ),
  );
  dio.interceptors.add(EnvelopeUnwrapInterceptor());
  return dio;
}

@Riverpod(keepAlive: true)
AuthInterceptor authInterceptor(Ref ref) {
  final secureStorage = ref.watch(secureStorageServiceProvider);
  final refreshDio = ref.watch(refreshOnlyDioClientProvider);

  return AuthInterceptor(
    secureStorage: secureStorage,
    refreshAccessToken: (refreshToken) async {
      try {
        final response = await refreshDio.post<Map<String, dynamic>>(
          ApiConstants.refreshTokenPath,
          data: {'refreshToken': refreshToken},
        );
        final authResponse = AuthResponseModel.fromJson(response.data!);
        await secureStorage.saveTokens(
          accessToken: authResponse.accessToken,
          refreshToken: authResponse.refreshToken,
        );
        return authResponse.accessToken;
      } catch (_) {
        // Any failure here — transport or decoding — must return null so the caller
        // clears the stored tokens. Leaving a already-rotated refresh token behind
        // would trip the server's reuse detection and revoke every session.
        return null;
      }
    },
    onSessionExpired: () =>
        ref.read(authProvider.notifier).handleSessionExpired(),
    onAccountSwitched: () =>
        ref.read(authProvider.notifier).handleAccountSwitchedElsewhere(),
  );
}

@Riverpod(keepAlive: true)
Dio dioClient(Ref ref) =>
    buildDioClient(authInterceptor: ref.watch(authInterceptorProvider));

@Riverpod(keepAlive: true)
AuthRemoteDataSource authRemoteDataSource(Ref ref) =>
    AuthRemoteDataSource(ref.watch(dioClientProvider));

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) => AuthRepositoryImpl(
  remoteDataSource: ref.watch(authRemoteDataSourceProvider),
  secureStorage: ref.watch(secureStorageServiceProvider),
);
