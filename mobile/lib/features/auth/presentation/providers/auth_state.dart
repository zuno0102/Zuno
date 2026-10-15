import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zuno/features/auth/domain/entities/user.dart';

part 'auth_state.freezed.dart';

/// Wrapped in `AsyncValue` by [AuthNotifier] (`AsyncNotifier<AuthState>`), so
/// in-flight/error states during login/register/refresh are represented by
/// `AsyncValue.loading()`/`AsyncValue.error()` rather than duplicated here.
@freezed
sealed class AuthState with _$AuthState {
  const factory AuthState.unauthenticated() = AuthUnauthenticated;

  const factory AuthState.authenticated(User user) = AuthAuthenticated;
}
