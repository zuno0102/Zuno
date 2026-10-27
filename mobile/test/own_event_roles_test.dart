import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/presentation/providers/business_bookings_notifier.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_hiring_posts_tab.dart';
import 'package:zuno/features/business_owner/presentation/widgets/post_crew_wage_list.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post_application.dart';
import 'package:zuno/features/hiring_post/domain/repositories/hiring_post_repository.dart';
import 'package:zuno/features/hiring_post/presentation/providers/business_hiring_posts_notifier.dart';
import 'package:zuno/features/hiring_post/presentation/providers/hiring_post_providers.dart';
import 'package:zuno/features/worker/presentation/widgets/job_details_sheet.dart';

/// Roles on the business's own events, as on an order: the owner gives an accepted worker
/// Supervisor, Lead or Support, and the Lead can start and finish the work from the worker app.
class _Posts extends BusinessHiringPostsNotifier {
  _Posts(this._posts);
  final List<HiringPost> _posts;
  final roles = <(String, String?)>[];

  @override
  Future<List<HiringPost>> build() async => _posts;

  @override
  Future<void> setApplicationRole({
    required String applicationId,
    required String? role,
  }) async {
    roles.add((applicationId, role));
  }
}

class _NoOrders extends BusinessBookingsNotifier {
  @override
  Future<List<Booking>> build() async => const [];
}

class _LeadRepository extends Fake implements HiringPostRepository {
  final calls = <String>[];

  @override
  Future<HiringPost> leadStartWork(String id) async {
    calls.add('start $id');
    return _post(id: id);
  }

  @override
  Future<HiringPost> leadCompleteWork(String id) async {
    calls.add('complete $id');
    return _post(id: id);
  }

  @override
  Future<List<HiringPost>> getMyPostJobs() async => const [];
}

HiringPostApplication _hire(
  String name, {
  String status = 'Accepted',
  String? role,
}) => HiringPostApplication(
  id: 'a-$name',
  workerProfileId: 'w-$name',
  workerName: name,
  status: status,
  appliedAt: DateTime(2026, 10, 1),
  agreedSalaryAmount: 700,
  agreedSalaryUnit: 'PerEvent',
  role: role,
);

HiringPost _post({
  String id = 'p-1',
  String? bookingId,
  List<HiringPostApplication> crew = const [],
  DateTime? eventDate,
  DateTime? startedAt,
  DateTime? completedAt,
  String? myStatus,
  String? myRole,
}) => HiringPost(
  id: id,
  businessOwnerProfileId: 'b-1',
  bookingId: bookingId,
  bookingStatus: bookingId == null ? null : 'Confirmed',
  businessName: 'apples business',
  title: 'apples - Wedding catering',
  eventDate: eventDate ?? DateTime.now().add(const Duration(days: 3)),
  durationMinutes: 240,
  workStartedAt: startedAt,
  workCompletedAt: completedAt,
  workersNeeded: 3,
  salaryAmount: 700,
  confirmedCount: crew.where((a) => a.isAccepted).length,
  filledCount: crew.where((a) => a.isAccepted).length,
  status: 'Open',
  createdDate: DateTime(2026, 10, 1),
  applications: crew,
  myApplicationStatus: myStatus,
  myRole: myRole,
);

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(720, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

void main() {
  // ---- The rule ---------------------------------------------------------------------------

  group('HiringPost roles', () {
    test('own events hold roles; posts for an order do not', () {
      expect(_post().holdsOwnRoles, isTrue);
      expect(_post(bookingId: 'bk-1').holdsOwnRoles, isFalse);
    });

    test('roles can be set until the work is finished', () {
      expect(_post().canHoldCrewRoles, isTrue);
      expect(_post(startedAt: DateTime.now()).canHoldCrewRoles, isTrue);
      expect(
        _post(
          startedAt: DateTime.now(),
          completedAt: DateTime.now(),
        ).canHoldCrewRoles,
        isFalse,
      );
      expect(_post(bookingId: 'bk-1').canHoldCrewRoles, isFalse);
    });

    for (final (status, role, lead) in [
      ('Accepted', 'Lead', true),
      ('Accepted', 'lead', true),
      ('Accepted', 'Supervisor', false),
      ('Accepted', null, false),
      ('Confirmed', 'Lead', false),
    ]) {
      test(
        'a worker $status with role $role is ${lead ? '' : 'not '}the Lead',
        () {
          expect(_post(myStatus: status, myRole: role).iAmLead, lead);
        },
      );
    }

    test('a Lead role on a post for an order grants nothing here', () {
      expect(
        _post(bookingId: 'bk-1', myStatus: 'Accepted', myRole: 'Lead').iAmLead,
        isFalse,
      );
    });
  });

  // ---- Business: Hire post crew -----------------------------------------------------------

  Future<_Posts> pumpHire(WidgetTester tester, HiringPost post) async {
    phone(tester);
    final fake = _Posts([post]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessHiringPostsProvider.overrideWith(() => fake),
          businessBookingsProvider.overrideWith(_NoOrders.new),
        ],
        child: const MaterialApp(
          home: Scaffold(body: BusinessHiringPostsTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (find.text(post.applications.first.workerName).evaluate().isEmpty) {
      await tester.tap(find.text('Crew'));
      await tester.pumpAndSettle();
    }
    return fake;
  }

  // Changed: roles used to be set from Hire post too. They are now set only in Status
  // management, where the job is run, so Hire post shows no role icon.
  testWidgets('Hire post shows no role icon on an own event', (tester) async {
    await pumpHire(
      tester,
      _post(
        crew: [
          _hire('apple one', role: 'Lead'),
          _hire('apple two'),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('apple one'), findsOneWidget);
    expect(find.byTooltip('Change role (Lead)'), findsNothing);
    expect(find.byTooltip('Assign role'), findsNothing);
  });

  // ---- Business: Status management own-event crew -----------------------------------------

  Future<_Posts> pumpStatusCrew(WidgetTester tester, HiringPost post) async {
    phone(tester);
    final fake = _Posts([post]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [businessHiringPostsProvider.overrideWith(() => fake)],
        child: MaterialApp(
          home: Scaffold(body: PostCrewWageList(post: post)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crew'));
    await tester.pumpAndSettle();
    return fake;
  }

  group('Status management own-event crew', () {
    testWidgets('choosing Lead saves it on the post', (tester) async {
      final fake = await pumpStatusCrew(
        tester,
        _post(crew: [_hire('apple two')]),
      );

      await tester.tap(find.byTooltip('Assign role'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lead'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(fake.roles, [('a-apple two', 'Lead')]);
      expect(find.text('apple two is now Lead on this job'), findsOneWidget);
    });

    testWidgets('Remove role takes it away', (tester) async {
      final fake = await pumpStatusCrew(
        tester,
        _post(crew: [_hire('apple one', role: 'Support')]),
      );

      await tester.tap(find.byTooltip('Change role (Support)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove role'));
      await tester.pumpAndSettle();

      expect(fake.roles, [('a-apple one', null)]);
    });

    testWidgets('shows the role and the role icon', (tester) async {
      await pumpStatusCrew(
        tester,
        _post(
          crew: [
            _hire('apple one', role: 'Lead'),
            _hire('apple two'),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Lead · ₹700 per event'), findsOneWidget);
      expect(find.byTooltip('Change role (Lead)'), findsOneWidget);
      expect(find.byTooltip('Assign role'), findsOneWidget);
    });

    testWidgets('no role icon once the work is finished', (tester) async {
      await pumpStatusCrew(
        tester,
        _post(
          startedAt: DateTime.now().subtract(const Duration(hours: 2)),
          completedAt: DateTime.now(),
          crew: [_hire('apple one', role: 'Lead')],
        ),
      );

      expect(find.byTooltip('Change role (Lead)'), findsNothing);
      // The role is still shown, as a record.
      expect(find.textContaining('Lead · '), findsOneWidget);
    });
  });

  // ---- Worker: the job sheet --------------------------------------------------------------

  Future<_LeadRepository> openJob(WidgetTester tester, HiringPost job) async {
    phone(tester);
    final repository = _LeadRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [hiringPostRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showJobDetailsSheet(context, job: job),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return repository;
  }

  final today = DateTime.now().subtract(const Duration(hours: 1));

  group('Worker job sheet', () {
    testWidgets('the Lead on the day can start the job', (tester) async {
      final repository = await openJob(
        tester,
        _post(
          eventDate: today,
          crew: [_hire('apple one')],
          myStatus: 'Accepted',
          myRole: 'Lead',
        ),
      );

      expect(
        find.text("You're the Lead on this job — you can start and finish it."),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Start this job'));
      await tester.tap(find.text('Start this job'));
      await tester.pumpAndSettle();

      expect(repository.calls, ['start p-1']);
      expect(find.text('Work started.'), findsOneWidget);
    });

    testWidgets('once started, the Lead can finish it', (tester) async {
      final repository = await openJob(
        tester,
        _post(
          eventDate: today,
          startedAt: today,
          crew: [_hire('apple one')],
          myStatus: 'Accepted',
          myRole: 'Lead',
        ),
      );

      await tester.ensureVisible(find.text('Finish this job'));
      await tester.tap(find.text('Finish this job'));
      await tester.pumpAndSettle();

      expect(repository.calls, ['complete p-1']);
    });

    testWidgets('the Lead sees no button before the day', (tester) async {
      await openJob(
        tester,
        _post(crew: [_hire('apple one')], myStatus: 'Accepted', myRole: 'Lead'),
      );

      expect(find.textContaining("You're the Lead"), findsOneWidget);
      expect(find.text('Start this job'), findsNothing);
    });

    testWidgets('a Supervisor is told their role but gets no buttons', (
      tester,
    ) async {
      await openJob(
        tester,
        _post(
          eventDate: today,
          crew: [_hire('apple two')],
          myStatus: 'Accepted',
          myRole: 'Supervisor',
        ),
      );

      expect(find.text("You're the Supervisor on this job."), findsOneWidget);
      expect(find.text('Start this job'), findsNothing);
    });

    testWidgets('after the work is done the role is a record', (tester) async {
      await openJob(
        tester,
        _post(
          eventDate: today,
          startedAt: today,
          completedAt: DateTime.now(),
          crew: [_hire('apple one')],
          myStatus: 'Accepted',
          myRole: 'Lead',
        ),
      );

      expect(find.text('You were the Lead on this job.'), findsOneWidget);
      expect(find.text('Finish this job'), findsNothing);
    });

    testWidgets('no role, no banner', (tester) async {
      await openJob(
        tester,
        _post(
          eventDate: today,
          crew: [_hire('apple three')],
          myStatus: 'Accepted',
        ),
      );

      expect(find.textContaining('on this job'), findsNothing);
      expect(find.text('Start this job'), findsNothing);
    });
  });
}
