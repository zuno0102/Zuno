import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy.dart';
import 'package:zuno/features/vacancy/presentation/providers/worker_vacancies_notifier.dart';
import 'package:zuno/features/worker/domain/entities/worker_dashboard.dart';
import 'package:zuno/features/worker/presentation/providers/worker_dashboard_notifier.dart';
import 'package:zuno/features/worker/presentation/screens/worker_dashboard_tab.dart';
import 'package:zuno/shared/widgets/stat_tile.dart';

import 'features/vacancy/vacancy_fixtures.dart';

/// The worker home groups its tiles like the business home: Service jobs, then Full-time jobs,
/// with one full-time tile per stage in the label table.
class _FakeDashboard extends WorkerDashboardNotifier {
  @override
  Future<WorkerDashboard> build() async => const WorkerDashboard();
}

void main() {
  Future<void> pump(WidgetTester tester, List<Vacancy> applications) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workerDashboardProvider.overrideWith(_FakeDashboard.new),
          myVacancyApplicationsProvider.overrideWith((_) async => applications),
        ],
        child: const MaterialApp(home: Scaffold(body: WorkerDashboardTab())),
      ),
    );
    await tester.pumpAndSettle();
  }

  Vacancy applied(String id, String status) =>
      vacancy(id: id, myApplicationId: 'a-$id', myApplicationStatus: status);

  testWidgets('both sections are named, one tile per stage, counted', (
    tester,
  ) async {
    await pump(tester, [
      applied('1', VacancyApplicationStatus.applied),
      applied('2', VacancyApplicationStatus.shortlisted),
      applied('3', VacancyApplicationStatus.shortlisted),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.text('Service jobs'), findsOneWidget);
    expect(find.text('Full-time jobs'), findsOneWidget);

    // Five service tiles and five stage tiles, all the same shared tile.
    expect(find.byType(StatTile), findsNWidgets(10));

    // The table's short names, so they fit three to a row.
    Finder tile(String label) =>
        find.ancestor(of: find.text(label), matching: find.byType(StatTile));
    String count(String label) => tester
        .widget<Text>(
          find.descendant(of: tile(label), matching: find.byType(Text)).first,
        )
        .data!;

    expect(count('Sent'), '1');
    expect(count('Viewed'), '0');
    expect(count('Shortlisted'), '2');
    expect(count('Hired'), '0');
    expect(count('Rejected'), '0');
  });

  testWidgets('a stage tile opens just the applications at that stage', (
    tester,
  ) async {
    await pump(tester, [
      applied('1', VacancyApplicationStatus.shortlisted),
      applied('2', VacancyApplicationStatus.applied),
      applied('3', VacancyApplicationStatus.applied),
    ]);

    await tester.ensureVisible(find.text('Shortlisted'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shortlisted'));
    await tester.pumpAndSettle();

    // The page is named for the stage and lists only its one job, not all three.
    expect(find.widgetWithText(AppBar, 'Shortlisted'), findsOneWidget);
    expect(find.text('Office receptionist'), findsOneWidget);
  });
}
