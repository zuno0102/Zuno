import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/business_owner/presentation/widgets/business_service_form_sheet.dart';
import 'package:zuno/features/catalog/domain/entities/service_category.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';

/// The add-service sheet must actually open.
///
/// This exists because it twice did not. The price-type options are laid out as a 2×2 grid of
/// tiles inside a scrolling column, and a Row asking to stretch into that unbounded height throws
/// "BoxConstraints forces an infinite height" — which fails the whole sheet's layout, not just
/// the one row. The page comes up blank and nothing says why.
///
/// The same mistake had already taken the business home screen down once. One assertion catches
/// it: that opening the sheet threw nothing at all.
void main() {
  Future<void> pumpSheet(WidgetTester tester) async {
    // A narrow phone, which is where a four-across row would have been squeezed in the first
    // place and where the grid has least room.
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serviceCategoriesProvider.overrideWith(
            (ref) async => const <ServiceCategory>[],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showBusinessServiceFormSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// Taps something that may be below the fold of the scrolling sheet.
  ///
  /// A plain `tap` on a widget outside the viewport does nothing and reports no error, which
  /// reads as the button being broken rather than simply off-screen.
  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('opens without a layout failure', (tester) async {
    await pumpSheet(tester);

    // The assertion the whole file is for. An unbounded-height throw shows up here and nowhere
    // else — the screen simply renders nothing.
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers all four ways of charging, each labelled', (tester) async {
    await pumpSheet(tester);

    expect(find.text('How do you charge?'), findsOneWidget);

    for (final label in ['Fixed price', 'Per hour', 'Per day', 'Per person']) {
      expect(find.text(label), findsOneWidget, reason: '$label is missing');
    }
  });

  testWidgets('choosing per person replaces the crew-size box', (tester) async {
    await pumpSheet(tester);

    // A fixed crew size is the normal case and has a field of its own.
    expect(find.text('Workers required per order'), findsOneWidget);
    expect(find.text('Workers agreed per order'), findsNothing);

    await scrollTo(tester, find.text('Per person'));

    // Priced by the head, the crew size is what gets negotiated — so the box goes away and says
    // so, rather than inviting a number the order then contradicts.
    expect(find.text('Workers required per order'), findsNothing);
    expect(find.text('Workers agreed per order'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the questions section starts empty and adds a row on demand', (tester) async {
    await pumpSheet(tester);

    expect(find.text('What should the customer tell you?'), findsOneWidget);
    expect(find.text('Question 1'), findsNothing);

    await scrollTo(tester, find.text('Add'));

    expect(find.text('Question 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
