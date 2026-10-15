import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/presentation/providers/worker_jobs_notifier.dart';
import 'package:zuno/features/worker/presentation/screens/worker_jobs_tab.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/presentation/providers/worker_post_jobs_notifier.dart';

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

Future<void> pump(
  WidgetTester tester,
  List<Booking> jobs, {
  List<HiringPost> postJobs = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workerJobsProvider.overrideWith(() => _FakeJobs(jobs)),
        workerPostJobsProvider.overrideWith((ref) async => postJobs),
      ],
      child: const MaterialApp(home: Scaffold(body: WorkerJobsTab())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a worker with no jobs at all sees one message, not two tabs', (
    tester,
  ) async {
    await pump(tester, []);

    expect(find.text('No jobs yet'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
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

      final answer = tester
          .getTopLeft(find.text('Waiting for your answer'))
          .dy;
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
