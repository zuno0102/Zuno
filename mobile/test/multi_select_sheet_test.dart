import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/shared/widgets/multi_select_sheet.dart';

/// The shared tick-list sheet, and the way out of a filter set in it.
///
/// Clearing a location used to mean unticking every state and district by hand — and a customer who
/// had picked four had to remember which four. The sheet now offers to empty the selection outright,
/// for the callers that want it.
void main() {
  final options = [
    const MultiSelectOption(id: 'a', label: 'Kerala'),
    const MultiSelectOption(id: 'b', label: 'Tamil Nadu'),
    const MultiSelectOption(id: 'c', label: 'Karnataka'),
  ];

  Future<Set<String>?> open(
    WidgetTester tester, {
    required Set<String> initial,
    String? clearLabel,
  }) async {
    Set<String>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  result = await showMultiSelectSheet(
                    context: context,
                    title: 'States',
                    options: options,
                    initialSelectedIds: initial,
                    clearLabel: clearLabel,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('offers no clear button when the caller did not ask for one', (
    tester,
  ) async {
    await open(tester, initial: {'a'});

    expect(find.text('Clear location'), findsNothing);
  });

  testWidgets('offers one once something is selected', (tester) async {
    await open(tester, initial: {'a'}, clearLabel: 'Clear location');

    expect(find.text('Clear location'), findsOneWidget);
  });

  testWidgets('hides it when nothing is selected', (tester) async {
    // Nothing to clear, so the button could never do anything.
    await open(tester, initial: {}, clearLabel: 'Clear location');

    expect(find.text('Clear location'), findsNothing);
  });

  testWidgets('appears as soon as the first tick goes in', (tester) async {
    await open(tester, initial: {}, clearLabel: 'Clear location');
    expect(find.text('Clear location'), findsNothing);

    await tester.tap(find.text('Kerala'));
    await tester.pumpAndSettle();

    expect(find.text('Clear location'), findsOneWidget);
  });

  testWidgets('tapping it closes with nothing selected', (tester) async {
    // An empty set, which is how a caller tells "cleared" apart from "dismissed" — dismissing
    // returns null and changes nothing.
    Set<String>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  result = await showMultiSelectSheet(
                    context: context,
                    title: 'States',
                    options: options,
                    initialSelectedIds: {'a', 'b'},
                    clearLabel: 'Clear location',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear location'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result, isEmpty);
  });

  testWidgets('Done still returns what was ticked', (tester) async {
    // The clear button must not have changed the ordinary path.
    Set<String>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  result = await showMultiSelectSheet(
                    context: context,
                    title: 'States',
                    options: options,
                    initialSelectedIds: {'a'},
                    clearLabel: 'Clear location',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Karnataka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(result, {'a', 'c'});
  });
}
