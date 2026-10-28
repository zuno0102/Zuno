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
    expect(find.text('Shortlisted (1)'), findsOneWidget);
    expect(find.text('Kumar P'), findsOneWidget);
    expect(find.textContaining('Shop helper'), findsOneWidget);
    expect(repo.askedForVacancy, contains(null));
  });

  testWidgets('four lists with their counts, New first', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('New (1)'), findsOneWidget);
    expect(find.text('Waiting (0)'), findsOneWidget);
    expect(find.text('Shortlisted (1)'), findsOneWidget);
    expect(find.text('Hired (0)'), findsOneWidget);
    expect(find.text('Ravi K'), findsOneWidget);
    expect(
      find.text('Meena S'),
      findsNothing,
      reason: 'she is on another list',
    );
  });

  testWidgets('opening an applicant marks them viewed', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ravi K'));
    await tester.pumpAndSettle();

    expect(repo.opened, ['a-1']);
    expect(
      find.text('Waiting'),
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
    await tester.tap(find.text('Shortlisted (1)'));
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
