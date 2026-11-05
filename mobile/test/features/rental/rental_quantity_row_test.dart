import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/theme/app_theme.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_order_form_sheet.dart';

/// The − / + row under "How many" — the offline order, extra pieces and the customer's booking.
/// At 1 the − is switched off, and on phones it used to be an empty grey circle with no − drawn.
void main() {
  Future<List<int>> pump(
    WidgetTester tester,
    ThemeData theme,
    String text,
  ) async {
    final controller = TextEditingController(text: text);
    addTearDown(controller.dispose);
    final steps = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: RentalQuantityRow(
            controller: controller,
            onStep: steps.add,
            onChanged: () {},
          ),
        ),
      ),
    );
    return steps;
  }

  /// The colour the − icon is drawn in, and the circle behind it.
  (Color, Color) colours(WidgetTester tester) {
    final button = find.byKey(const ValueKey('order-quantity-less'));
    final icon = tester.widget<RichText>(
      find.descendant(of: button, matching: find.byType(RichText)),
    );
    final material = tester.widget<Material>(
      find.descendant(of: button, matching: find.byType(Material)).first,
    );
    return (icon.text.style!.color!, material.color!);
  }

  /// WCAG contrast of two colours laid over [ground].
  double contrast(Color a, Color b, Color ground) {
    Color over(Color c) => Color.alphaBlend(c, ground);
    final la = over(a).computeLuminance(), lb = over(b).computeLuminance();
    return (la > lb ? la + 0.05 : lb + 0.05) /
        (la > lb ? lb + 0.05 : la + 0.05);
  }

  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    testWidgets('at 1 the − is off but still shows its sign ($name)', (
      tester,
    ) async {
      final steps = await pump(tester, theme, '1');

      final less = find.byKey(const ValueKey('order-quantity-less'));
      expect(
        find.descendant(of: less, matching: find.byIcon(Icons.remove)),
        findsOneWidget,
      );
      expect(tester.widget<IconButton>(less).onPressed, isNull);

      final (icon, circle) = colours(tester);
      expect(
        contrast(icon, circle, theme.colorScheme.surface),
        greaterThanOrEqualTo(2.0),
        reason: 'the − must be seen against its circle',
      );

      await tester.tap(less);
      expect(steps, isEmpty);
    });
  }

  testWidgets('above 1 both − and + step', (tester) async {
    final steps = await pump(tester, AppTheme.light, '5');

    await tester.tap(find.byKey(const ValueKey('order-quantity-less')));
    await tester.tap(find.byKey(const ValueKey('order-quantity-more')));
    expect(steps, [-1, 1]);
  });
}
