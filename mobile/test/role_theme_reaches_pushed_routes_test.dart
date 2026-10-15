import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/theme/app_theme.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/role_theme.dart';

/// A role's colour has to reach everything that role opens, not only its tabs.
///
/// Each dashboard wraps itself in a [RoleTheme], which covers the tabs inside it and nothing else.
/// A pushed route, a dialog and a snackbar are children of the Navigator `MaterialApp` owns, *above*
/// that wrapper — so a worker who opened their profile, a route pushed from the dashboard, got a
/// business-indigo screen and business-indigo messages on a green app.
///
/// The fix was to set the theme on `MaterialApp` from the signed-in role. These tests describe the
/// shape of the problem, so the wrapper alone is never mistaken for a solution again.
void main() {
  Color primaryOf(ZunoRole role) =>
      AppTheme.forRole(role, Brightness.light).colorScheme.primary;

  testWidgets('a RoleTheme wrapper does not reach a route pushed from under it', (
    tester,
  ) async {
    late BuildContext pushed;

    await tester.pumpWidget(
      MaterialApp(
        // Standing in for the app default, which is what a pushed route falls back to.
        theme: AppTheme.forRole(ZunoRole.business, Brightness.light),
        home: RoleTheme(
          role: ZunoRole.worker,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (routeContext) {
                      pushed = routeContext;
                      return const Scaffold(body: SizedBox.shrink());
                    },
                  ),
                ),
                child: const Text('Open profile'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open profile'));
    await tester.pumpAndSettle();

    // The bug, stated plainly: the pushed screen is business-coloured on a worker app.
    expect(
      Theme.of(pushed).colorScheme.primary,
      primaryOf(ZunoRole.business),
      reason: 'a wrapper inside the app cannot colour a route pushed above it',
    );
  });

  testWidgets('setting the theme on MaterialApp does reach it, messages included', (
    tester,
  ) async {
    late BuildContext pushed;

    await tester.pumpWidget(
      MaterialApp(
        // What main.dart now does once the signed-in role is known.
        theme: AppTheme.forRole(ZunoRole.worker, Brightness.light),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (routeContext) {
                    pushed = routeContext;
                    return const Scaffold(body: SizedBox.shrink());
                  },
                ),
              ),
              child: const Text('Open profile'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open profile'));
    await tester.pumpAndSettle();

    expect(Theme.of(pushed).colorScheme.primary, primaryOf(ZunoRole.worker));

    // And the message sent from that pushed screen carries the same colour, which is the thing
    // that was actually noticed: a blue popup on a green app.
    AppMessenger.of(pushed).showSuccess('Photo updated.');
    await tester.pump();

    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
      primaryOf(ZunoRole.worker),
    );
  });

  group('the role behind an account name', () {
    test('is resolved for every role the server issues', () {
      expect(AppColors.roleFromName('Customer'), ZunoRole.customer);
      expect(AppColors.roleFromName('BusinessOwner'), ZunoRole.business);
      expect(AppColors.roleFromName('Worker'), ZunoRole.worker);
      expect(AppColors.roleFromName('SuperAdmin'), ZunoRole.admin);
    });

    test('is nothing for anyone not signed in', () {
      // Which is what keeps the login and register screens on the neutral brand colours.
      expect(AppColors.roleFromName(null), isNull);
      expect(AppColors.roleFromName(''), isNull);
      expect(AppColors.roleFromName('Nonsense'), isNull);
    });
  });
}
