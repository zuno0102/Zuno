import 'dart:typed_data';

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/core/notifications/system_notifications.dart';
import 'package:zuno/features/auth/presentation/providers/auth_providers.dart';
import 'package:zuno/features/auth/presentation/providers/auth_state.dart';

part 'auth_notifier.g.dart';

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  @override
  Future<AuthState> build() async {
    final repository = ref.watch(authRepositoryProvider);
    final user = await repository.restoreSession();
    return user == null
        ? const AuthState.unauthenticated()
        : AuthState.authenticated(user);
  }

  Future<void> register({
    String? email,
    String? phoneNumber,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      final tokens = await repository.register(
        email: email,
        phoneNumber: phoneNumber,
        password: password,
        firstName: firstName,
        lastName: lastName,
        role: role,
      );
      return AuthState.authenticated(tokens.user);
    });
  }

  Future<void> login({
    required String emailOrPhone,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      final tokens = await repository.login(
        emailOrPhone: emailOrPhone,
        password: password,
      );
      return AuthState.authenticated(tokens.user);
    });
  }

  /// Re-reads the signed-in account from the server.
  ///
  /// For changes made somewhere other than here. A worker edits their name through the worker
  /// profile endpoint, so this notifier — which every screen reads the signed-in person from —
  /// never heard about it, and the name across the top of their home page stayed as it was until
  /// the app was restarted.
  Future<void> refreshUser() async {
    final user = await ref.read(authRepositoryProvider).getCurrentUser();

    // Only while they are still signed in. A reload that lands as the session expires must not put
    // the app back into an authenticated state.
    if (state.value is AuthAuthenticated) {
      state = AsyncData(AuthState.authenticated(user));
    }
  }

  /// Saves a new profile picture and puts it straight into state.
  Future<void> updateMyPhoto({required Uint8List bytes}) async {
    final updated = await ref
        .read(authRepositoryProvider)
        .updateMyPhoto(bytes: bytes);

    if (state.value is AuthAuthenticated) {
      state = AsyncData(AuthState.authenticated(updated));
    }
  }

  /// Saves a correction to the signed-in account's own name or phone number.
  ///
  /// The new user replaces the one in state rather than triggering a reload: this notifier is what
  /// every screen reads the signed-in person from, so anything short of that leaves the old name on
  /// the header until the app restarts.
  Future<void> updateMyAccount({
    required String firstName,
    required String lastName,
    String? phoneNumber,
  }) async {
    final updated = await ref
        .read(authRepositoryProvider)
        .updateMyAccount(
          firstName: firstName,
          lastName: lastName,
          phoneNumber: phoneNumber,
        );

    // Only when they are still signed in. A save that lands as the session expires must not put the
    // app back into an authenticated state.
    if (state.value is AuthAuthenticated) {
      state = AsyncData(AuthState.authenticated(updated));
    }
  }

  Future<void> logout() async {
    final repository = ref.read(authRepositoryProvider);
    await repository.logout();

    // The shade outlives the session. Leaving somebody's wages and bookings sitting there for
    // whoever picks the phone up next would leak more than the screen they just signed out of.
    await _clearTheShade();

    state = const AsyncData(AuthState.unauthenticated());
  }

  /// Invoked by [AuthInterceptor] when a token refresh ultimately fails — tokens are
  /// already cleared by that point, so this only needs to flip presentation state so
  /// GoRouter's redirect sends the user back to `/login`.
  void handleSessionExpired() {
    // Same reasoning as logout: an expired session is still a session that has ended, and the
    // notifications it drew are no longer anybody's business.
    unawaited(_clearTheShade());

    state = const AsyncData(AuthState.unauthenticated());
  }

  /// Another tab of the web app signed in as a different account, replacing this tab's login.
  ///
  /// This tab is signed out on screen — without touching the saved login, which now belongs to the
  /// other tab and is perfectly valid there — and the login screen says why. Carrying on would have
  /// shown and sent things as the wrong person.
  void handleAccountSwitchedElsewhere() {
    if (state.value is! AuthAuthenticated) return;
    unawaited(_clearTheShade());
    state = const AsyncData(
      AuthState.unauthenticated(
        notice: 'You signed in as another account in another tab. Sign in again here.',
      ),
    );
  }

  /// Never allowed to fail the sign-out it is part of.
  Future<void> _clearTheShade() async {
    try {
      await SystemNotifications.instance.clearAll();
    } catch (_) {
      // Being unable to clear a notification must not leave somebody signed in.
    }
  }
}
