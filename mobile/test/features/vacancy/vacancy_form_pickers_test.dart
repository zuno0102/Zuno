import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_options.dart';
import 'package:zuno/features/vacancy/presentation/providers/vacancy_providers.dart';
import 'package:zuno/features/vacancy/presentation/widgets/vacancy_form_sheet.dart';
import 'package:zuno/shared/widgets/select_field.dart';

import 'vacancy_fixtures.dart';

/// Business › Full-time jobs › Post a job. Its drop-downs opened menus that spread across the whole
/// screen over the form; each is now a field that opens its own bottom sheet.
void main() {
  Future<void> openForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vacancyRepositoryProvider.overrideWithValue(FakeVacancyRepository()),
          vacancyOptionsProvider(asWorker: false).overrideWith(
            (ref) async => const VacancyOptions(
              jobTypes: [
                VacancyJobType(
                  id: 'ft',
                  name: 'Full-time',
                  hasFixedLength: false,
                ),
                VacancyJobType(
                  id: 'pt',
                  name: 'Part-time',
                  hasFixedLength: false,
                ),
                VacancyJobType(
                  id: 'ct',
                  name: 'Contract',
                  hasFixedLength: true,
                ),
                VacancyJobType(
                  id: 'in',
                  name: 'Internship',
                  hasFixedLength: true,
                ),
              ],
              feePlans: [],
              allowedFileExtensions: ['pdf'],
              maxFileSizeBytes: 1,
            ),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showVacancyFormSheet(context),
                  child: const Text('Post a job'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Post a job'));
    await tester.pumpAndSettle();
  }

  testWidgets('the form has no drop-down menus left', (tester) async {
    await openForm(tester);

    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(find.byType(DropdownButton<int>), findsNothing);
    expect(find.byKey(const ValueKey('vacancy-job-type')), findsOneWidget);
    expect(find.byKey(const ValueKey('vacancy-pay-period')), findsOneWidget);
    expect(find.byKey(const ValueKey('vacancy-days')), findsOneWidget);
  });

  testWidgets('job type opens a sheet of its own and takes the pick', (
    tester,
  ) async {
    await openForm(tester);
    await tester.tap(find.byKey(const ValueKey('vacancy-job-type')));
    await tester.pumpAndSettle();

    // A second sheet over the form, holding the four types — not a menu across the form.
    expect(find.byType(BottomSheet), findsNWidgets(2));
    for (final name in ['Full-time', 'Part-time', 'Contract', 'Internship']) {
      expect(
        find.descendant(
          of: find.byType(BottomSheet).last,
          matching: find.text(name),
        ),
        findsOneWidget,
      );
    }

    await tester.tap(find.text('Contract'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('vacancy-job-type')),
        matching: find.text('Contract'),
      ),
      findsOneWidget,
    );
    // A contract asks how long it runs.
    expect(find.text('How many months?'), findsOneWidget);
  });

  testWidgets('salary period and days a week pick the same way', (
    tester,
  ) async {
    await openForm(tester);

    final period = find.byKey(const ValueKey('vacancy-pay-period'));
    await tester.ensureVisible(period);
    await tester.pumpAndSettle();
    final before = tester.widget<SelectField<String>>(period).initialValue;
    await tester.tap(period);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNWidgets(2));
    final other = tester
        .widgetList<ListTile>(
          find.descendant(
            of: find.byType(BottomSheet).last,
            matching: find.byType(ListTile),
          ),
        )
        .firstWhere((t) => t.selected == false);
    await tester.tap(find.byWidget(other));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(before, isNotNull);

    final days = find.byKey(const ValueKey('vacancy-days'));
    await tester.ensureVisible(days);
    await tester.pumpAndSettle();
    await tester.tap(days);
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 days'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: days, matching: find.text('5 days')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
