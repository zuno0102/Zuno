import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/auth/domain/entities/auth_tokens.dart';
import 'package:zuno/features/auth/domain/entities/user.dart';
import 'package:zuno/features/auth/domain/repositories/auth_repository.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/auth/presentation/providers/auth_providers.dart';
import 'package:zuno/features/auth/presentation/providers/auth_state.dart';

/// Re-reading the signed-in account after it was changed somewhere else.
///
/// A worker edits their name through the worker profile endpoint, so this notifier — which every
/// screen reads the signed-in person from — never heard about it. The worker saw their new name on
/// the profile page and their old one in the header above it until the app restarted.
User _user({required String firstName}) => User(
  id: 'u1',
  email: 'worker@zuno.local',
  phoneNumber: '9100007530',
  firstName: firstName,
  lastName: 'Worker',
  profileImageUrl: null,
  role: 'Worker',
  emailConfirmed: false,
  phoneNumberConfirmed: false,
);

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._restored);

  final User? _restored;

  /// What the server would hand back now, which the test moves under the notifier's feet.
  User current = _user(firstName: 'Test');

  int getCurrentUserCalls = 0;

  @override
  Future<User?> restoreSession() async => _restored;

  @override
  Future<User> getCurrentUser() async {
    getCurrentUserCalls++;
    return current;
  }

  @override
  Future<AuthTokens> login({
    required String emailOrPhone,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AuthTokens> register({
    String? email,
    String? phoneNumber,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
  }) => throw UnimplementedError();

  @override
  Future<void> logout() => throw UnimplementedError();

  @override
  Future<void> forgotPassword({required String email}) =>
      throw UnimplementedError();

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) => throw UnimplementedError();

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => throw UnimplementedError();

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

ProviderContainer _container(_FakeAuthRepository repository) {
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('brings back a name changed elsewhere', () async {
    final repository = _FakeAuthRepository(_user(firstName: 'Test'));
    final container = _container(repository);

    await container.read(authProvider.future);
    expect(
      (container.read(authProvider).value! as AuthAuthenticated).user.firstName,
      'Test',
    );

    // The worker profile endpoint renames the account behind this notifier's back.
    repository.current = _user(firstName: 'Ravi');
    await container.read(authProvider.notifier).refreshUser();

    expect(
      (container.read(authProvider).value! as AuthAuthenticated).user.firstName,
      'Ravi',
    );
  });

  test('does not sign anybody in who is signed out', () async {
    final repository = _FakeAuthRepository(null);
    final container = _container(repository);

    await container.read(authProvider.future);
    expect(container.read(authProvider).value, isA<AuthUnauthenticated>());

    await container.read(authProvider.notifier).refreshUser();

    // A reload landing as a session expires must not put the app back into a signed-in state.
    expect(container.read(authProvider).value, isA<AuthUnauthenticated>());
  });
}
