import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zuno/features/vacancy/data/models/vacancy_model.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_payment.dart';
import 'package:zuno/features/vacancy/presentation/providers/vacancy_providers.dart';
import 'package:zuno/features/vacancy/presentation/screens/business_vacancies_tab.dart';
import 'package:zuno/features/vacancy/presentation/screens/vacancy_applicants_screen.dart';
import 'package:zuno/features/vacancy/presentation/screens/worker_vacancies_tab.dart';
import 'package:zuno/features/vacancy/presentation/screens/worker_vacancy_detail_screen.dart';

import 'vacancy_fixtures.dart';

void main() {
  late FakeVacancyRepository repo;

  setUp(() => repo = FakeVacancyRepository());

  Widget host(Widget child) => ProviderScope(
    overrides: [vacancyRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(home: Scaffold(body: child)),
  );

  group('business: full-time jobs tab', () {
    testWidgets('loading shows a spinner', (tester) async {
      final pending = Completer<VacancyPage<Vacancy>>();
      repo.myVacancies = () => pending.future;

      await tester.pumpWidget(host(const BusinessVacanciesTab()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete(const VacancyPage(items: []));
    });

    testWidgets('empty invites the first job', (tester) async {
      repo.myVacancies = () async => const VacancyPage(items: []);

      await tester.pumpWidget(host(const BusinessVacanciesTab()));
      await tester.pumpAndSettle();

      expect(find.text('No full-time jobs yet'), findsOneWidget);
      expect(find.text('Post a job'), findsWidgets);
    });

    testWidgets('an unpaid job offers to pay; a live one to stop', (
      tester,
    ) async {
      repo.myVacancies = () async => VacancyPage(
        items: [
          vacancy(
            id: 'unpaid',
            status: VacancyStatus.awaitingPayment,
            isLive: false,
            needsPayment: true,
          ),
          vacancy(id: 'live', applicantCount: 3),
        ],
      );

      await tester.pumpWidget(host(const BusinessVacanciesTab()));
      await tester.pumpAndSettle();

      expect(find.text('Pay & post'), findsOneWidget);
      expect(find.text('Not posted yet'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
      expect(find.text('Stop hiring'), findsOneWidget);
      expect(find.text('Applicants (3)'), findsOneWidget);
    });

    testWidgets('a stopped job says how to start again', (tester) async {
      repo.myVacancies = () async => VacancyPage(
        items: [
          vacancy(
            status: VacancyStatus.stopped,
            isLive: false,
            canResume: true,
          ),
        ],
      );

      await tester.pumpWidget(host(const BusinessVacanciesTab()));
      await tester.pumpAndSettle();

      expect(find.text('Hiring stopped'), findsOneWidget);
      expect(
        find.textContaining('Your applicants and hires are kept'),
        findsOneWidget,
      );
      expect(find.text('Stop hiring'), findsNothing);

      // One tap, no edit form.
      await tester.tap(find.text('Start hiring again'));
      await tester.pumpAndSettle();

      expect(repo.hiringChanges, [true]);
      expect(find.text('Live'), findsOneWidget);
      expect(find.text('Start hiring again'), findsNothing);
      expect(find.text('Stop hiring'), findsOneWidget);
    });

    testWidgets('an error is shown, not a blank screen', (tester) async {
      repo.myVacancies = () async => throw Exception('Network down');

      await tester.pumpWidget(host(const BusinessVacanciesTab()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Network down'), findsOneWidget);
    });
  });

  group('worker: My jobs › My applications', () {
    testWidgets('empty says where applications will appear', (tester) async {
      await tester.pumpWidget(host(const MyVacancyApplicationsList()));
      await tester.pumpAndSettle();

      expect(find.text('No applications yet'), findsOneWidget);
    });

    testWidgets('each application shows the poster'
        's answer', (tester) async {
      repo.myApplications = [
        vacancy(myApplicationId: 'a-1', myApplicationStatus: 'Shortlisted'),
      ];

      await tester.pumpWidget(host(const MyVacancyApplicationsList()));
      await tester.pumpAndSettle();

      expect(find.text('Office receptionist'), findsOneWidget);
      expect(find.text('Shortlisted'), findsOneWidget);
    });
  });

  group('worker: job details', () {
    // Tall enough for the whole form, so nothing sits below a lazily built fold.
    setUp(() {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(800, 2400);
      view.devicePixelRatio = 1;
    });
    tearDown(() {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    testWidgets('a live job shows the form with what the business asked for', (
      tester,
    ) async {
      repo.forWorker = (_) async => vacancy();

      await tester.pumpWidget(
        host(const WorkerVacancyDetailScreen(vacancyId: 'v-1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Office receptionist'), findsOneWidget);
      // Each custom field shows as its own kind of input.
      expect(find.text('Aadhaar'), findsOneWidget);
      expect(find.text('Choose a photo or PDF'), findsOneWidget);
      expect(find.text('Do you know Tally?'), findsOneWidget);
      expect(find.text('Do you have a two-wheeler?'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Yes'), findsOneWidget);
      expect(find.text('Years of experience (optional)'), findsOneWidget);
      expect(find.text('SEND APPLICATION'), findsOneWidget);
    });

    testWidgets('sending without a required file or Yes/No is stopped here', (
      tester,
    ) async {
      repo.forWorker = (_) async => vacancy();

      await tester.pumpWidget(
        host(const WorkerVacancyDetailScreen(vacancyId: 'v-1')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Do you know Tally?'),
        'Yes',
      );
      await tester.tap(find.text('SEND APPLICATION'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Please complete: Aadhaar, Do you have a two-wheeler?',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'after applying it shows where it stands, and offers withdrawal',
      (tester) async {
        repo.forWorker = (_) async =>
            vacancy(myApplicationId: 'a-1', myApplicationStatus: 'Shortlisted');

        await tester.pumpWidget(
          host(const WorkerVacancyDetailScreen(vacancyId: 'v-1')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Shortlisted'), findsOneWidget);
        expect(find.text('Withdraw application'), findsOneWidget);
        expect(find.text('SEND APPLICATION'), findsNothing);
      },
    );

    testWidgets('a hired worker is not offered withdrawal', (tester) async {
      repo.forWorker = (_) async =>
          vacancy(myApplicationId: 'a-1', myApplicationStatus: 'Hired');

      await tester.pumpWidget(
        host(const WorkerVacancyDetailScreen(vacancyId: 'v-1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hired'), findsOneWidget);
      expect(find.text('Withdraw application'), findsNothing);
    });

    testWidgets('a closed job takes no applications', (tester) async {
      repo.forWorker = (_) async =>
          vacancy(status: VacancyStatus.stopped, isLive: false);

      await tester.pumpWidget(
        host(const WorkerVacancyDetailScreen(vacancyId: 'v-1')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('This job is no longer taking applications.'),
        findsOneWidget,
      );
    });

    // The details screen does not watch the job list. Sending used to go through that list, which
    // was disposed mid-call and failed with "Cannot use the Ref after it has been disposed".
    testWidgets(
      'sending an application reaches the server without a disposed-ref error',
      (tester) async {
        final textOnly = VacancyModel.fromJson(
          vacancyJson()
            ..['requirements'] = [
              {
                'id': 'r-2',
                'kind': 'Text',
                'prompt': 'Your area',
                'isRequired': true,
                'sortOrder': 0,
              },
            ],
        ).toEntity();
        repo.forWorker = (_) async => textOnly;

        await tester.pumpWidget(
          host(const WorkerVacancyDetailScreen(vacancyId: 'v-1')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Your area'),
          'Nagercoil',
        );
        await tester.tap(find.text('SEND APPLICATION'));
        await tester.pumpAndSettle();

        expect(repo.applied.single.single.text, 'Nagercoil');
        expect(find.textContaining('disposed'), findsNothing);
        expect(find.text('Application sent.'), findsOneWidget);
      },
    );

    testWidgets('withdrawing reaches the server', (tester) async {
      repo.forWorker = (_) async =>
          vacancy(myApplicationId: 'a-1', myApplicationStatus: 'Applied');

      await tester.pumpWidget(
        host(const WorkerVacancyDetailScreen(vacancyId: 'v-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Withdraw application'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Withdraw'));
      await tester.pumpAndSettle();

      expect(repo.withdrawn, ['a-1']);
      expect(find.text('Application withdrawn.'), findsOneWidget);
    });
  });

  group('the phone back button', () {
    testWidgets('closes Applicants and returns to the jobs list', (
      tester,
    ) async {
      repo.myVacancies = () async =>
          VacancyPage(items: [vacancy(id: 'live', applicantCount: 2)]);
      // The same /screen route the app uses, so pushes are seen by the router as they are there.
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: BusinessVacanciesTab()),
          ),
          GoRoute(
            path: '/screen',
            builder: (_, state) => state.extra! as Widget,
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [vacancyRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Applicants (2)'));
      await tester.pumpAndSettle();
      expect(find.byType(VacancyApplicantsScreen), findsOneWidget);
      // The router must know the page is open. A push it never saw leaves it on '/', and on the
      // phone back then closed the app instead of the page.
      expect(router.state.matchedLocation, '/screen');

      // What Android sends on back.
      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(router.state.matchedLocation, '/');
      expect(find.byType(VacancyApplicantsScreen), findsNothing);
      expect(find.text('Applicants (2)'), findsOneWidget);
    });
  });
}
