import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/shared/widgets/detail_row.dart';

/// The one label-and-value row every detail screen and card now shares.
///
/// It replaced eleven private copies in five shapes, so each shape is checked for the thing a
/// person actually reads off it: the label, the value, and the icon where there is one.
void main() {
  Future<void> pump(WidgetTester tester, Widget row) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Column(children: [row])),
    ),
  );

  testWidgets('label above its value', (tester) async {
    await pump(tester, const DetailRow(label: 'Price', value: '₹1,200'));

    expect(find.text('Price'), findsOneWidget);
    expect(find.text('₹1,200'), findsOneWidget);
    // Stacked, so the label sits above the value rather than beside it.
    expect(
      tester.getTopLeft(find.text('Price')).dy,
      lessThan(tester.getTopLeft(find.text('₹1,200')).dy),
    );
  });

  testWidgets('inline row paints a missing value in the error colour', (
    tester,
  ) async {
    await pump(
      tester,
      const DetailRow.inline(label: 'UPI', value: 'Not added', isMissing: true),
    );

    expect(find.text('UPI'), findsOneWidget);
    final value = tester.widget<Text>(find.text('Not added'));
    final context = tester.element(find.text('Not added'));
    expect(value.style?.color, Theme.of(context).colorScheme.error);
  });

  testWidgets('icon row shows the icon, label, value and detail', (
    tester,
  ) async {
    await pump(
      tester,
      const DetailRow.icon(
        icon: Icons.place_outlined,
        label: 'Where',
        value: 'Kochi',
        detail: 'Approximate location',
      ),
    );

    expect(find.byIcon(Icons.place_outlined), findsOneWidget);
    expect(find.text('Where'), findsOneWidget);
    expect(find.text('Kochi'), findsOneWidget);
    expect(find.text('Approximate location'), findsOneWidget);
  });

  testWidgets('icon row with nothing to say draws nothing', (tester) async {
    await pump(
      tester,
      const DetailRow.icon(
        icon: Icons.place_outlined,
        label: 'Where',
        value: ' ',
      ),
    );

    expect(find.text('Where'), findsNothing);
    expect(find.byIcon(Icons.place_outlined), findsNothing);
  });

  testWidgets('icon-and-text line shows both', (tester) async {
    await pump(
      tester,
      const DetailRow.iconText(
        icon: Icons.groups_outlined,
        text: '3 of 5 hired',
      ),
    );

    expect(find.byIcon(Icons.groups_outlined), findsOneWidget);
    expect(find.text('3 of 5 hired'), findsOneWidget);
  });

  testWidgets('tile shows a trailing widget in place of the value', (
    tester,
  ) async {
    await pump(
      tester,
      const DetailRow.tile(label: 'Availability', trailing: Text('Free')),
    );

    expect(find.text('Availability'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
  });
}
