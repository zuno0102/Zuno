import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/presentation/providers/worker_jobs_notifier.dart';
import 'package:zuno/features/worker/presentation/screens/worker_jobs_tab.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/presentation/providers/worker_post_jobs_notifier.dart';
import 'package:zuno/features/hiring_post/presentation/providers/worker_job_offers_notifier.dart';
import 'package:zuno/features/worker/domain/entities/worker_invitation.dart';
import 'package:zuno/features/worker/presentation/providers/worker_invitations_notifier.dart';

/// My jobs, split into work still to do and work behind them.
///
/// Sections fixed the order of this screen; the split fixes its length. History only grows, so on a
/// worker with a few months behind them the live work — the part they can still act on — sat at the
/// top of a very long scroll with nothing stopping them scrolling past it into last March.
Booking _job({
  required String service,
  required String status,
  DateTime? on,
  bool awaitingMyAnswer = false,
}) => Booking(
  id: 'bk-$service',
  businessOwnerProfileId: '',
  businessName: 'Test Owner',
  customerProfileId: '',
  customerName: 'Zuno Customer',
  businessServiceId: '',
  serviceName: service,
  serviceCategoryName: '',
  status: status,
  scheduledDate: on ?? DateTime.now().add(const Duration(days: 3)),
  priceQuoted: 900,
  requiredWorkerCount: 1,
  myAssignmentStatus: awaitingMyAnswer ? 'Assigned' : 'Accepted',
);

class _FakeJobs extends WorkerJobsNotifier {
  _FakeJobs(this._rows);
  final List<Booking> _rows;

  @override
  Future<List<Booking>> build() async => _rows;
}

/// Work taken through a hiring post, which arrives from a different endpoint entirely.
HiringPost _postJob({
  required String title,
  bool finished = false,
  bool started = false,
}) => HiringPost(
  id: 'p-$title',
  businessOwnerProfileId: 'b1',
  businessName: 'Boss T',
  title: title,
  eventDate: DateTime.now().add(const Duration(days: 5)),
  location: 'Nila nagar',
  workersNeeded: 3,
  salaryAmount: 700,
  salaryUnit: 'PerEvent',
  status: 'Open',
  confirmedCount: 1,
  filledCount: 1,
  createdDate: DateTime.now().subtract(const Duration(days: 4)),
  myApplicationStatus: 'Accepted',
  workStartedAt: started || finished ? DateTime.now() : null,
  workCompletedAt: finished ? DateTime.now() : null,
);

/// A business asking for this worker by name, on one of its posts.
HiringPost _offer(String title) => HiringPost(
  id: 'o-$title',
  businessOwnerProfileId: 'b1',
  businessName: 'Boss T',
  title: title,
  eventDate: DateTime.now().add(const Duration(days: 9)),
  workersNeeded: 3,
  salaryAmount: 900,
  salaryUnit: 'PerEvent',
  status: 'Open',
  confirmedCount: 0,
  filledCount: 0,
  createdDate: DateTime.now().subtract(const Duration(days: 1)),
  myApplicationStatus: 'Confirmed',
  myApplicationId: 'app-$title',
);

WorkerInvitation _team(String business, {String status = 'Invited'}) =>
    WorkerInvitation(
      id: 'bw-$business',
      businessOwnerProfileId: 'b-$business',
      businessName: business,
      status: status,
      invitedAt: DateTime.now().subtract(const Duration(days: 1)),
      respondedAt: status == 'Invited' ? null : DateTime.now(),
    );

class _FakeOffers extends WorkerJobOffersNotifier {
  _FakeOffers(this._rows);
  final List<HiringPost> _rows;

  @override
  Future<List<HiringPost>> build() async => _rows;
}

class _FakeTeams extends WorkerInvitationsNotifier {
  _FakeTeams(this._rows);
  final List<WorkerInvitation> _rows;

  @override
  Future<List<WorkerInvitation>> build() async => _rows;
}

Future<void> pump(
  WidgetTester tester,
  List<Booking> jobs, {
  List<HiringPost> postJobs = const [],
  List<HiringPost> offers = const [],
  List<WorkerInvitation> teams = const [],
  int initialTab = WorkerJobsTab.currentTab,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workerJobsProvider.overrideWith(() => _FakeJobs(jobs)),
        workerPostJobsProvider.overrideWith((ref) async => postJobs),
        workerJobOffersProvider.overrideWith(() => _FakeOffers(offers)),
        workerInvitationsProvider.overrideWith(() => _FakeTeams(teams)),
      ],
      child: MaterialApp(
        home: Scaffold(body: WorkerJobsTab(initialTab: initialTab)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a worker with no jobs yet still reaches their invitations', (
    tester,
  ) async {
    // A new worker is exactly the one most likely to have an invitation, so an empty job list
    // must never take the tabs away.
    await pump(tester, [], offers: [_offer('Varkala cliff catering')]);

    expect(find.text('No jobs yet'), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('Invitations (1)'), findsOneWidget);

    await tester.tap(find.text('Invitations (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Varkala cliff catering'), findsOneWidget);
  });

  testWidgets('Invitations counts only what is waiting on an answer', (
    tester,
  ) async {
    await pump(
      tester,
      [_job(service: 'Coming up job', status: 'Confirmed')],
      offers: [_offer('Wedding crew'), _offer('Temple festival')],
      teams: [
        _team('Shajil Caterers'),
        _team('Nila Events', status: 'Active'),
      ],
    );

    // Two job offers and one team asking — the team already joined is not waiting on anything.
    expect(find.text('Invitations (3)'), findsOneWidget);
  });

  testWidgets('a notification about an invitation opens straight on that tab', (
    tester,
  ) async {
    await pump(
      tester,
      [_job(service: 'Coming up job', status: 'Confirmed')],
      offers: [_offer('Wedding crew')],
      initialTab: WorkerJobsTab.invitationsTab,
    );

    expect(find.text('Wedding crew'), findsOneWidget);
    expect(find.text('Coming up job'), findsNothing);
  });

  testWidgets('both tabs are offered, each counting its own', (tester) async {
    await pump(tester, [
      _job(service: 'Coming up job', status: 'Confirmed'),
      _job(service: 'Running job', status: 'InProgress'),
      _job(service: 'Done job', status: 'Completed'),
      _job(service: 'Called off job', status: 'Cancelled'),
    ]);

    expect(find.text('Current (2)'), findsOneWidget);
    expect(find.text('History (2)'), findsOneWidget);
  });

  group('Current', () {
    testWidgets('holds the work still to do, and nothing finished', (
      tester,
    ) async {
      await pump(tester, [
        _job(service: 'Coming up job', status: 'Confirmed'),
        _job(service: 'Running job', status: 'InProgress'),
        _job(service: 'Done job', status: 'Completed'),
      ]);

      expect(find.text('Coming up'), findsOneWidget);
      expect(find.text('On the job'), findsOneWidget);
      expect(find.text('Coming up job'), findsOneWidget);
      expect(find.text('Running job'), findsOneWidget);
      // History lives in the other tab now.
      expect(find.text('Done job'), findsNothing);
    });

    testWidgets('keeps an unanswered offer at the top, where it was', (
      tester,
    ) async {
      await pump(tester, [
        _job(service: 'Coming up job', status: 'Confirmed'),
        _job(
          service: 'Needs answering',
          status: 'Confirmed',
          awaitingMyAnswer: true,
        ),
      ]);

      final answer = tester.getTopLeft(find.text('Waiting for your answer')).dy;
      final coming = tester.getTopLeft(find.text('Coming up')).dy;
      expect(answer, lessThan(coming));
    });

    testWidgets('says so when there is nothing live, without hiding History', (
      tester,
    ) async {
      await pump(tester, [_job(service: 'Done job', status: 'Completed')]);

      expect(find.text('Nothing on just now'), findsOneWidget);
      expect(find.text('History (1)'), findsOneWidget);
    });
  });

  group('work taken through a hiring post', () {
    /// The bug this group exists for. A worker reaches paid work by two routes, and My jobs was fed
    /// by the bookings endpoint alone — so the home page could say "1 coming up" and My jobs open
    /// empty, because that job came through a post.
    testWidgets('shows under Current, where the home page said it was', (
      tester,
    ) async {
      await pump(
        tester,
        [],
        postJobs: [_postJob(title: 'Marriage catering (5 crew)')],
      );

      expect(find.text('Current (1)'), findsOneWidget);
      expect(find.text('Jobs you took'), findsOneWidget);
      expect(find.text('Marriage catering (5 crew)'), findsOneWidget);
      expect(find.text('Boss T'), findsOneWidget);
    });

    testWidgets('counts alongside booking work rather than replacing it', (
      tester,
    ) async {
      await pump(
        tester,
        [_job(service: 'Coming up job', status: 'Confirmed')],
        postJobs: [_postJob(title: 'Marriage catering (5 crew)')],
      );

      expect(find.text('Current (2)'), findsOneWidget);
      expect(find.text('Coming up job'), findsOneWidget);
      expect(find.text('Marriage catering (5 crew)'), findsOneWidget);
    });

    testWidgets('says where it stands, started or merely booked', (
      tester,
    ) async {
      await pump(
        tester,
        [],
        postJobs: [_postJob(title: 'Running job', started: true)],
      );

      expect(find.text('Work started'), findsOneWidget);
    });

    testWidgets('moves to History once the work is finished', (tester) async {
      await pump(
        tester,
        [],
        postJobs: [_postJob(title: 'Done job', finished: true)],
      );

      expect(find.text('Current (0)'), findsOneWidget);
      expect(find.text('History (1)'), findsOneWidget);
      expect(find.text('Nothing on just now'), findsOneWidget);

      await tester.tap(find.text('History (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Done job'), findsOneWidget);
    });
  });

  group('History', () {
    testWidgets('holds finished and called-off work together', (tester) async {
      await pump(tester, [
        _job(service: 'Coming up job', status: 'Confirmed'),
        _job(service: 'Done job', status: 'Completed'),
        _job(service: 'Called off job', status: 'Cancelled'),
      ]);

      await tester.tap(find.text('History (2)'));
      await tester.pumpAndSettle();

      // One list, no headings: history is looked things up in, not worked through, and splitting
      // "done" from "called off" would make somebody check two places for a half-remembered job.
      expect(find.text('Done job'), findsOneWidget);
      expect(find.text('Called off job'), findsOneWidget);
      expect(find.text('Coming up job'), findsNothing);
    });

    testWidgets('says so when nothing is finished yet', (tester) async {
      await pump(tester, [_job(service: 'Coming up job', status: 'Confirmed')]);

      await tester.tap(find.text('History (0)'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing finished yet'), findsOneWidget);
    });
  });
}
