import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/theme/app_theme.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/role_theme.dart';

/// How the app says something worked, or did not.
///
/// Every message used to be a bare `SnackBar` — Material's black slab, edge to edge, belonging to no
/// app in particular. These pin what replaced it: the colour of the screen that sent it, an icon
/// that says which outcome it is, and a floating bar clear of the bottom of the screen.
///
/// One colour for all three outcomes. Colouring by outcome put a green, a red and a charcoal bar on
/// screens whose identity is a single hue, and the hue is what makes a Zuno screen placeable.
void main() {
  /// Pumps a screen under [role]'s theme and hands back a messenger taken from inside it.
  Future<AppMessenger> pump(WidgetTester tester, {ZunoRole? role}) async {
    late AppMessenger messenger;

    Widget body() => Scaffold(
      body: Builder(
        builder: (context) {
          messenger = AppMessenger.of(context);
          return const SizedBox.shrink();
        },
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: role == null ? body() : RoleTheme(role: role, child: body()),
      ),
    );
    return messenger;
  }

  SnackBar shown(WidgetTester tester) =>
      tester.widget<SnackBar>(find.byType(SnackBar));

  testWidgets('a message wears the app colour, not Material black', (
    tester,
  ) async {
    final messenger = await pump(tester);

    messenger.showSuccess('Photo updated.');
    await tester.pump();

    expect(find.text('Photo updated.'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    final bar = shown(tester);
    expect(bar.behavior, SnackBarBehavior.floating);
    expect(bar.backgroundColor, AppTheme.light.colorScheme.primary);
  });

  group('the colour comes from the screen that sent it', () {
    /// The bug this group exists for.
    ///
    /// Each dashboard wraps itself in a [RoleTheme], but `ScaffoldMessenger` is created by
    /// `MaterialApp` **above** those wrappers. Reading the theme from the messenger's own context
    /// skipped every role theme in the app and returned the neutral one — so a worker who updated
    /// their profile got a business-indigo bar on a green screen.
    for (final role in ZunoRole.values) {
      testWidgets('${role.name} screens send ${role.name}-coloured messages', (
        tester,
      ) async {
        final expected = AppTheme.forRole(
          role,
          Brightness.light,
        ).colorScheme.primary;
        final messenger = await pump(tester, role: role);

        messenger.showSuccess('Saved.');
        await tester.pump();

        expect(shown(tester).backgroundColor, expected);
      });
    }

    testWidgets('and the roles really are different colours', (tester) async {
      final colours = {
        for (final role in ZunoRole.values)
          AppTheme.forRole(role, Brightness.light).colorScheme.primary,
      };
      // Otherwise the test above would pass on a single shared hue and prove nothing.
      expect(colours.length, ZunoRole.values.length);
    });
  });

  testWidgets('every outcome is the same colour', (tester) async {
    final messenger = await pump(tester, role: ZunoRole.worker);

    messenger.showSuccess('Saved.');
    await tester.pump();
    final success = shown(tester).backgroundColor;

    messenger.showFailure('Not saved.');
    await tester.pump();
    final failure = shown(tester).backgroundColor;

    messenger.showInfo('Location cleared.');
    await tester.pump();
    final info = shown(tester).backgroundColor;

    expect(success, failure);
    expect(failure, info);
  });

  testWidgets('the icon is what separates them', (tester) async {
    final messenger = await pump(tester);

    messenger.showFailure('Image must be 5MB or smaller.');
    await tester.pump();
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

    messenger.showInfo('Location cleared.');
    await tester.pump();
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
  });

  testWidgets('a failure stays on screen longer than a confirmation', (
    tester,
  ) async {
    final messenger = await pump(tester);

    messenger.showSuccess('Saved.');
    await tester.pump();
    expect(shown(tester).duration, const Duration(seconds: 3));

    messenger.showFailure('Not saved.');
    await tester.pump();
    // A reason somebody has to act on needs longer than a confirmation.
    expect(shown(tester).duration, const Duration(seconds: 4));
  });

  testWidgets('the writing stays readable on that colour', (tester) async {
    final messenger = await pump(tester, role: ZunoRole.worker);

    messenger.showSuccess('Saved.');
    await tester.pump();

    final text = tester.widget<Text>(find.text('Saved.'));
    expect(
      text.style!.color,
      AppTheme.forRole(ZunoRole.worker, Brightness.light).colorScheme.onPrimary,
    );
  });

  testWidgets('a second message replaces the first rather than queueing', (
    tester,
  ) async {
    final messenger = await pump(tester);

    messenger.showSuccess('Your details are saved.');
    await tester.pump();
    messenger.showSuccess('Photo updated.');
    await tester.pump(const Duration(milliseconds: 500));

    // Two saves in quick succession would otherwise queue, and the second would arrive after the
    // person had moved on from both.
    expect(find.text('Your details are saved.'), findsNothing);
    expect(find.text('Photo updated.'), findsOneWidget);
  });
}
