import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zuno/features/auth/domain/entities/user.dart';

part 'auth_state.freezed.dart';

/// Wrapped in `AsyncValue` by [AuthNotifier] (`AsyncNotifier<AuthState>`), so
/// in-flight/error states during login/register/refresh are represented by
/// `AsyncValue.loading()`/`AsyncValue.error()` rather than duplicated here.
@freezed
sealed class AuthState with _$AuthState {
  /// [notice] explains a sign-out the person did not ask for, shown on the login screen.
  const factory AuthState.unauthenticated({String? notice}) = AuthUnauthenticated;

  const factory AuthState.authenticated(User user) = AuthAuthenticated;
}
