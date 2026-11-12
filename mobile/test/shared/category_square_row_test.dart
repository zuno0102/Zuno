import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/shared/widgets/category_square_row.dart';

/// The category squares on top of a list: four to a row, all one size, whatever the count.
void main() {
  Future<void> pump(
    WidgetTester tester,
    int count, {
    String? selected,
    ValueChanged<String?>? onChanged,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategorySquareRow<String>(
            squares: [
              for (var i = 0; i < count; i++)
                CategorySquare(value: 'c$i', label: 'Cat $i', count: i),
            ],
            selected: selected,
            onChanged: onChanged ?? (_) {},
          ),
        ),
      ),
    );
  }

  Rect rectOf(WidgetTester tester, String value) =>
      tester.getRect(find.byKey(ValueKey('category-square-$value')));

  testWidgets('four fit one row on a 360 dp phone', (tester) async {
    await pump(tester, 4);

    final first = rectOf(tester, 'c0');
    final last = rectOf(tester, 'c3');
    expect(last.top, first.top);
    expect(last.right, lessThanOrEqualTo(360 - 16));
    expect(tester.takeException(), isNull);
  });

  testWidgets('more than four wrap into rows of the same size', (tester) async {
    await pump(tester, 7);

    final first = rectOf(tester, 'c0');
    final fifth = rectOf(tester, 'c4');
    final seventh = rectOf(tester, 'c6');
    expect(fifth.top, greaterThan(first.bottom), reason: 'a second row');
    expect(fifth.left, first.left);
    expect(seventh.size, first.size, reason: 'never shrunk to fit');
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a square picks it; tapping it again clears it', (
    tester,
  ) async {
    String? picked = 'unset';
    await pump(tester, 4, onChanged: (v) => picked = v);
    await tester.tap(find.byKey(const ValueKey('category-square-c2')));
    expect(picked, 'c2');

    await pump(tester, 4, selected: 'c2', onChanged: (v) => picked = v);
    await tester.tap(find.byKey(const ValueKey('category-square-c2')));
    expect(picked, isNull);
  });

  testWidgets('a filter on says so, with a Clear', (tester) async {
    String? picked = 'unset';
    await pump(tester, 4, selected: 'c1', onChanged: (v) => picked = v);

    expect(find.text('Showing: Cat 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('category-square-clear')));
    expect(picked, isNull);
  });

  testWidgets('nothing chosen: no Showing line', (tester) async {
    await pump(tester, 4);

    expect(find.textContaining('Showing:'), findsNothing);
  });

  testWidgets('screen readers hear the name and count once, and can tap', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    String? picked;
    await pump(tester, 4, onChanged: (v) => picked = v);

    expect(find.bySemanticsLabel('Cat 3, 3'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Cat 3, 3'));
    expect(picked, 'c3');
    handle.dispose();
  });
}
