import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/auth/domain/entities/auth_tokens.dart';
import 'package:zuno/features/auth/domain/entities/user.dart';
import 'package:zuno/features/auth/domain/repositories/auth_repository.dart';
import 'package:zuno/features/auth/presentation/providers/auth_providers.dart';
import 'package:zuno/main.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<User?> restoreSession() async => null;

  @override
  Future<AuthTokens> login({required String emailOrPhone, required String password}) =>
      throw UnimplementedError();

  @override
  Future<AuthTokens> register({
    String? email,
    String? phoneNumber,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> logout() => throw UnimplementedError();

  @override
  Future<void> forgotPassword({required String email}) => throw UnimplementedError();

  @override
  Future<void> resetPassword({required String token, required String newPassword}) =>
      throw UnimplementedError();

  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) =>
      throw UnimplementedError();

  @override
  Future<User> getCurrentUser() => throw UnimplementedError();

  @override
  Future<User> updateMyAccount({
    required String firstName,
    required String lastName,
    String? phoneNumber,
  }) => throw UnimplementedError();

  @override
  Future<User> updateMyPhoto({
    required String filePath,
    required String contentType,
  }) => throw UnimplementedError();
}

void main() {
  testWidgets('Unauthenticated app boot lands on the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(_FakeAuthRepository())],
        child: const ZunoApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SIGN IN'), findsAtLeastNWidgets(1));
    expect(find.text("Don't have an account? "), findsOneWidget);
  });
}
