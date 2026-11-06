import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/theme/app_theme.dart';
import 'package:zuno/shared/widgets/primary_button.dart';

/// A busy button (signing in, saving) keeps its own colour with a spinner that reads on it. It used
/// to turn the disabled grey, which in dark mode sat on a near-black page with a dark spinner on
/// it: button and spinner both vanished.
void main() {
  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    testWidgets('busy: primary colour and a visible spinner ($name)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: PrimaryButton(
              label: 'Sign in',
              onPressed: null,
              isLoading: true,
            ),
          ),
        ),
      );

      final scheme = theme.colorScheme;
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull, reason: 'cannot be tapped twice');
      final background = button.style!.backgroundColor!.resolve({
        WidgetState.disabled,
      });
      expect(background, scheme.primary);

      final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(spinner.color, scheme.onPrimary);
      // The spinner must stand out from the button it is on.
      expect(
        (spinner.color!.computeLuminance() - background!.computeLuminance())
            .abs(),
        greaterThan(0.3),
      );
    });
  }

  testWidgets('a button that is simply off still looks off', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: PrimaryButton(label: 'Sign in', onPressed: null),
        ),
      ),
    );
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    final background = button.style!.backgroundColor?.resolve({
      WidgetState.disabled,
    });
    expect(background, isNot(AppTheme.dark.colorScheme.primary));
  });
}
