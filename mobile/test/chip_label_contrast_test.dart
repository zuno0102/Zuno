import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/theme/app_theme.dart';

/// Chip labels have to be readable on the chip.
///
/// They were not. The shared `chipTheme` set a `labelStyle` carrying a size and a weight but **no
/// colour**, and a `TextStyle` with a null colour does not mean "use the sensible default" here —
/// it replaces the default style the chip would otherwise have resolved, colour and all. The role
/// chips on the crew sheet came out as white text on a white chip: five blank lozenges.
///
/// Measured as contrast rather than by comparing to a specific colour, so this keeps holding if the
/// palette moves again — which it has, more than once.
double _relativeLuminance(Color c) {
  double channel(double v) {
    final s = v;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG contrast ratio, 1 (identical) to 21 (black on white).
double _contrast(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  /// 3:1 is the floor for large or bold text. A chip label is small and bold, so this is lenient —
  /// the bug being guarded against produced roughly 1.0, which is text you cannot see at all.
  const minimumContrast = 3.0;

  Future<void> checkChips(WidgetTester tester, ThemeData theme, String label) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          // The case that broke: chips sitting on the plain surface a bottom sheet uses.
          backgroundColor: theme.colorScheme.surface,
          body: Center(
            child: Wrap(
              children: [
                ChoiceChip(
                  label: const Text('Supervisor'),
                  selected: false,
                  onSelected: (_) {},
                ),
                ChoiceChip(
                  label: const Text('Lead'),
                  selected: true,
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final text in ['Supervisor', 'Lead']) {
      final style = tester.widget<Text>(find.text(text)).style
          // The chip supplies the colour through the surrounding default style when the Text
          // itself carries none, which is how it is written in the sheet.
          ?? DefaultTextStyle.of(tester.element(find.text(text))).style;

      final colour = style.color ??
          DefaultTextStyle.of(tester.element(find.text(text))).style.color;

      expect(
        colour,
        isNotNull,
        reason: '$label: "$text" has no resolved label colour at all',
      );

      // Against the lightest thing it could be sitting on: the sheet's own surface.
      final contrast = _contrast(colour!, theme.colorScheme.surface);

      expect(
        contrast,
        greaterThan(minimumContrast),
        reason:
            '$label: "$text" is $colour on ${theme.colorScheme.surface} — '
            'contrast ${contrast.toStringAsFixed(2)}, which is unreadable',
      );
    }
  }

  group('chip labels can be read', () {
    for (final role in ZunoRole.values) {
      testWidgets('in the ${role.name} theme, light', (tester) async {
        await checkChips(
          tester,
          AppTheme.forRole(role, Brightness.light),
          '${role.name} light',
        );
      });

      testWidgets('in the ${role.name} theme, dark', (tester) async {
        await checkChips(
          tester,
          AppTheme.forRole(role, Brightness.dark),
          '${role.name} dark',
        );
      });
    }

    testWidgets('and on the signed-out theme', (tester) async {
      await checkChips(tester, AppTheme.light, 'signed out');
    });
  });
}
