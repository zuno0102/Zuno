import 'dart:typed_data';

import 'package:zuno/features/auth/domain/entities/auth_tokens.dart';
import 'package:zuno/features/auth/domain/entities/user.dart';

abstract interface class AuthRepository {
  Future<AuthTokens> register({
    String? email,
    String? phoneNumber,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
  });

  Future<AuthTokens> login({
    required String emailOrPhone,
    required String password,
  });

  Future<void> logout();

  Future<void> forgotPassword({required String email});

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  });

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Uploads or replaces the signed-in account's own picture.
  ///
  /// Bytes rather than a path: a path only exists on a device, and the web build has none.
  Future<User> updateMyPhoto({required Uint8List bytes});

  /// Corrects the signed-in account's own name and phone number.
  Future<User> updateMyAccount({
    required String firstName,
    required String lastName,
    String? phoneNumber,
  });

  Future<User> getCurrentUser();

  /// Restores a session from tokens already in secure storage, if any (used on app start).
  Future<User?> restoreSession();
}
