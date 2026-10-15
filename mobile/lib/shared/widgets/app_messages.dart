import 'package:flutter/material.dart';

/// How the app tells somebody that something worked, or did not.
///
/// Every message used to be a bare `SnackBar`, which Material renders as a black slab edge to edge
/// at the bottom of the screen — the same black slab whether a photo was saved or a payment failed.
/// It carries no sign of which of the two just happened, and it belongs to no app in particular.
///
/// These give the message a shape instead: a floating rounded bar in the colour of the screen it was
/// sent from, with an icon that says at a glance whether to carry on or to look again. The rest of
/// the app's surfaces are rounded and inset, so a square full-bleed bar was also the one control
/// that looked borrowed.
///
/// One colour throughout, not one per outcome — the icon and the words carry what happened.
///
/// ## Why this is a class and not an extension on `ScaffoldMessengerState`
///
/// It was that extension, and it quietly showed every message in the wrong colour. Each dashboard
/// wraps itself in a [RoleTheme] so a worker screen is green and a customer screen blue, but
/// `ScaffoldMessenger` is created by `MaterialApp`, **above** those wrappers. Reading the theme from
/// the messenger's own context therefore skipped every role theme in the app and returned the
/// neutral one, so a worker who updated their profile got a business-indigo bar.
///
/// So the colours are resolved from the caller's context, where the role theme is in scope, and
/// carried alongside the messenger. Taking both in one step also keeps the habit these replaced:
/// nearly every message follows an await, and a messenger read off a context afterwards throws.
class AppMessenger {
  const AppMessenger._(this._messenger, this._background, this._foreground);

  /// Captures the messenger and the colours of the screen [context] belongs to.
  ///
  /// Call it *before* any await, as you would `ScaffoldMessenger.of`.
  factory AppMessenger.of(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppMessenger._(
      ScaffoldMessenger.of(context),
      scheme.primary,
      scheme.onPrimary,
    );
  }

  final ScaffoldMessengerState _messenger;
  final Color _background;
  final Color _foreground;

  /// Something worked.
  void showSuccess(String message) =>
      _show(message: message, icon: Icons.check_circle_rounded);

  /// Something did not. Carries the reason, so it stays long enough to read.
  void showFailure(String message) => _show(
    message: message,
    icon: Icons.error_outline_rounded,
    duration: const Duration(seconds: 4),
  );

  /// Neither — a plain statement of what changed, like a filter being cleared.
  void showInfo(String message) =>
      _show(message: message, icon: Icons.info_outline_rounded);

  void _show({
    required String message,
    required IconData icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Only one at a time. Two actions in quick succession — saving a photo, then a name — otherwise
    // queue up and the second message arrives after the person has moved on from both.
    _messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, size: 20, color: _foreground),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    color: _foreground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: _background,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 4,
          duration: duration,
        ),
      );
  }
}

/// The same messages, for the places that have a context and no await before the call.
extension AppMessagesOnContext on BuildContext {
  void showSuccessMessage(String message) =>
      AppMessenger.of(this).showSuccess(message);

  void showFailureMessage(String message) =>
      AppMessenger.of(this).showFailure(message);

  void showInfoMessage(String message) =>
      AppMessenger.of(this).showInfo(message);
}
