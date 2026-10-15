import 'package:zuno/core/error/app_exceptions.dart';
import 'package:zuno/core/storage/secure_storage_service.dart';
import 'package:zuno/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:zuno/features/auth/data/models/login_request_model.dart';
import 'package:zuno/features/auth/data/models/register_request_model.dart';
import 'package:zuno/features/auth/domain/entities/auth_tokens.dart';
import 'package:zuno/features/auth/domain/entities/user.dart';
import 'package:zuno/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required SecureStorageService secureStorage,
  }) : _remoteDataSource = remoteDataSource,
       _secureStorage = secureStorage;

  final AuthRemoteDataSource _remoteDataSource;
  final SecureStorageService _secureStorage;

  @override
  Future<AuthTokens> register({
    String? email,
    String? phoneNumber,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    final response = await _remoteDataSource.register(
      RegisterRequestModel(
        email: email,
        phoneNumber: phoneNumber,
        password: password,
        firstName: firstName,
        lastName: lastName,
        role: role,
      ),
    );
    final tokens = response.toEntity();
    await _persistTokens(tokens);
    return tokens;
  }

  @override
  Future<AuthTokens> login({
    required String emailOrPhone,
    required String password,
  }) async {
    final response = await _remoteDataSource.login(
      LoginRequestModel(emailOrPhone: emailOrPhone, password: password),
    );
    final tokens = response.toEntity();
    await _persistTokens(tokens);
    return tokens;
  }

  @override
  Future<void> logout() async {
    final refreshToken = await _secureStorage.getRefreshToken();
    if (refreshToken != null) {
      try {
        await _remoteDataSource.revokeToken(refreshToken);
      } on AppException {
        // Best-effort revocation — the local session is cleared regardless, so a failed
        // revoke call (e.g. offline) never blocks the user from logging out on-device.
      }
    }
    await _secureStorage.clearTokens();
  }

  @override
  Future<void> forgotPassword({required String email}) =>
      _remoteDataSource.forgotPassword(email);

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) => _remoteDataSource.resetPassword(token: token, newPassword: newPassword);

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _remoteDataSource.changePassword(
    currentPassword: currentPassword,
    newPassword: newPassword,
  );

  @override
  Future<User> updateMyPhoto({
    required String filePath,
    required String contentType,
  }) async {
    final model = await _remoteDataSource.updateMyPhoto(
      filePath: filePath,
      contentType: contentType,
    );
    return model.toEntity();
  }

  @override
  Future<User> updateMyAccount({
    required String firstName,
    required String lastName,
    String? phoneNumber,
  }) async {
    final model = await _remoteDataSource.updateMyAccount(
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
    );
    return model.toEntity();
  }

  @override
  Future<User> getCurrentUser() async {
    final model = await _remoteDataSource.getCurrentUser();
    return model.toEntity();
  }

  @override
  Future<User?> restoreSession() async {
    try {
      final accessToken = await _secureStorage.getAccessToken();
      if (accessToken == null) {
        return null;
      }

      return await getCurrentUser();
    } catch (_) {
      // Covers both AppException (the stored token is rejected by the API) and platform-level
      // storage failures (e.g. flutter_secure_storage's web backend throwing a WebCrypto
      // "OperationError" when it can't decrypt a value written by a stale/incompatible build).
      // Either way the stored session can't be trusted, so start fresh rather than surfacing
      // a raw platform error on the login screen.
      try {
        await _secureStorage.clearTokens();
      } catch (_) {
        // Clearing can itself throw for the same storage-level reasons — nothing more to do.
      }
      return null;
    }
  }

  Future<void> _persistTokens(AuthTokens tokens) => _secureStorage.saveTokens(
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
  );
}
