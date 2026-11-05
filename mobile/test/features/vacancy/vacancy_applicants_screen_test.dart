import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/vacancy/data/models/vacancy_model.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_payment.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_application.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_summary.dart';
import 'package:zuno/features/vacancy/presentation/providers/vacancy_providers.dart';
import 'package:zuno/features/vacancy/presentation/screens/vacancy_applicants_screen.dart';

import 'vacancy_fixtures.dart';

/// The business works through applicants in four lists. Opening one moves it from New to Waiting;
/// rejecting asks first, because it deletes what the worker sent.
void main() {
  late FakeVacancyRepository repo;
  late Vacancy job;

  setUp(() {
    repo = FakeVacancyRepository();
    job = VacancyModel.fromJson(
      vacancyJson(applicantCount: 2)
        ..['newCount'] = 1
        ..['shortlistedCount'] = 1,
    ).toEntity();
    repo.myVacancies = () async => VacancyPage(items: [job]);
    repo.applicants = {
      VacancyApplicationStatus.applied: [applicant()],
      VacancyApplicationStatus.shortlisted: [
        applicant(id: 'a-2', status: 'Shortlisted', name: 'Meena S'),
      ],
    };
  });

  /// The tab of one list, and the count it shows.
  Finder tab(String status) => find.byKey(ValueKey('applicants-tab-$status'));
  String tabCount(WidgetTester tester, String status) => tester
      .widgetList<Text>(
        find.descendant(of: tab(status), matching: find.byType(Text)),
      )
      .first
      .data!;

  Widget host() => ProviderScope(
    overrides: [vacancyRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(home: VacancyApplicantsScreen(vacancy: job)),
  );

  testWidgets('with no vacancy it lists every job, naming each one', (
    tester,
  ) async {
    repo.summary = const VacancySummary(
      activePosts: 1,
      newCount: 0,
      waitingCount: 0,
      shortlistedCount: 1,
      hiredCount: 0,
    );
    repo.applicants = {
      VacancyApplicationStatus.shortlisted: [
        VacancyApplication(
          id: 'a-9',
          vacancyId: 'v-2',
          vacancyTitle: 'Shop helper',
          workerName: 'Kumar P',
          status: 'Shortlisted',
          appliedAt: DateTime(2026, 10, 27),
          answers: const [],
        ),
      ],
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [vacancyRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: VacancyApplicantsScreen(
            initialStatus: VacancyApplicationStatus.shortlisted,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('All applicants'), findsOneWidget);
    expect(tabCount(tester, VacancyApplicationStatus.shortlisted), '1');
    expect(find.text('Kumar P'), findsOneWidget);
    expect(find.textContaining('Shop helper'), findsOneWidget);
    expect(repo.askedForVacancy, contains(null));
  });

  testWidgets('four lists with their counts, New first', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    for (final (status, label, count) in [
      (VacancyApplicationStatus.applied, 'New', '1'),
      (VacancyApplicationStatus.viewed, 'Waiting', '0'),
      (VacancyApplicationStatus.shortlisted, 'Shortlisted', '1'),
      (VacancyApplicationStatus.hired, 'Hired', '0'),
    ]) {
      expect(tabCount(tester, status), count, reason: label);
      expect(
        find.descendant(of: tab(status), matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(find.text('Ravi K'), findsOneWidget);
    expect(
      find.text('Meena S'),
      findsNothing,
      reason: 'she is on another list',
    );
  });

  // On a phone, "Shortlisted (1)" on one line was wider than its quarter of the bar and the count
  // was cut off. Every count and name now sits wholly inside its own tab.
  for (final (width, textScale) in [(360.0, 1.0), (320.0, 1.0), (360.0, 1.3)]) {
    testWidgets(
      'every count is fully shown at ${width.toInt()} wide, text x$textScale',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(host());
        await tester.pumpAndSettle();

        for (final status in VacancyApplicationStatus.businessLists) {
          final box = tester.getRect(tab(status));
          final texts = find.descendant(
            of: tab(status),
            matching: find.byType(Text),
          );
          for (var i = 0; i < texts.evaluate().length; i++) {
            final rect = tester.getRect(texts.at(i));
            expect(
              rect.left >= box.left - 0.5 && rect.right <= box.right + 0.5,
              isTrue,
              reason: '$status: text $i spills out of its tab',
            );
          }
        }
        expect(tabCount(tester, VacancyApplicationStatus.shortlisted), '1');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('opening an applicant marks them viewed', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ravi K'));
    await tester.pumpAndSettle();

    expect(repo.opened, ['a-1']);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Waiting'),
      ),
      findsOneWidget,
      reason: 'the sheet shows the new stage',
    );
    expect(find.text('Do you know Tally?\nYes'), findsOneWidget);
  });

  testWidgets('opening an already decided applicant does not mark it again', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(tab(VacancyApplicationStatus.shortlisted));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Meena S'));
    await tester.pumpAndSettle();

    expect(repo.opened, isEmpty);
  });

  testWidgets('reject asks first, then rejects', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ravi K'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Reject'));
    await tester.pumpAndSettle();
    expect(find.textContaining('documents are deleted'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pumpAndSettle();

    expect(repo.decisions, [('a-1', VacancyApplicationStatus.rejected)]);
  });

  testWidgets('cancelling the reject question changes nothing', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ravi K'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Reject'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repo.decisions, isEmpty);
  });

  // Saving used to dispose the dialog's text box while it was still closing, which crashed the app
  // with "_dependents.isEmpty".
  testWidgets('saving a private note does not crash', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ravi K'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add a private note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Call Monday');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(repo.decisions, [('a-1', null)]);
    expect(find.text('Note: Call Monday'), findsOneWidget);
  });

  testWidgets('shortlisting from the sheet', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ravi K'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Shortlist'));
    await tester.pumpAndSettle();

    expect(repo.decisions, [('a-1', VacancyApplicationStatus.shortlisted)]);
  });
}
