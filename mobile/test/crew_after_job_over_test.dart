import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/domain/entities/booking_worker_assignment.dart';
import 'package:zuno/features/booking/presentation/widgets/booking_crew_list.dart';
import 'package:zuno/features/business_owner/presentation/widgets/post_crew_wage_list.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post_application.dart';
import 'package:zuno/features/hiring_post/presentation/providers/business_hiring_posts_notifier.dart';

/// A crew row once the job is over: Raise salary stays until the worker is paid, and the role,
/// chat and call options go, because there is no job left to run or arrange.
class _Posts extends BusinessHiringPostsNotifier {
  _Posts(this._posts);
  final List<HiringPost> _posts;
  @override
  Future<List<HiringPost>> build() async => _posts;
}

const _raise = 'Raise salary';
const _message = 'Message worker';
const _call = 'Call worker';

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(720, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

void main() {
  // ---- Own event, Status management --------------------------------------------------------

  HiringPostApplication hire({String payment = 'Unpaid', String? role}) =>
      HiringPostApplication(
        id: 'a-1',
        workerProfileId: 'w-1',
        workerName: 'apple one',
        workerPhone: '9000000001',
        status: 'Accepted',
        appliedAt: DateTime(2026, 10, 1),
        agreedSalaryAmount: 700,
        agreedSalaryUnit: 'PerEvent',
        paymentStatus: payment,
        role: role,
      );

  HiringPost ownEvent({required bool finished, String payment = 'Unpaid'}) {
    final started = DateTime.now().subtract(const Duration(hours: 3));
    return HiringPost(
      id: 'p-1',
      businessOwnerProfileId: 'b-1',
      businessName: 'apples business',
      title: 'apples - Wedding catering',
      eventDate: started,
      durationMinutes: 240,
      workStartedAt: started,
      workCompletedAt: finished ? DateTime.now() : null,
      workersNeeded: 1,
      salaryAmount: 700,
      confirmedCount: 1,
      filledCount: 1,
      status: 'Closed',
      createdDate: DateTime(2026, 10, 1),
      outstandingAmount: payment == 'Paid' ? 0 : 700,
      applications: [hire(payment: payment, role: 'Lead')],
    );
  }

  Future<void> pumpOwnEvent(WidgetTester tester, HiringPost post) async {
    phone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessHiringPostsProvider.overrideWith(() => _Posts([post])),
        ],
        child: MaterialApp(
          home: Scaffold(body: PostCrewWageList(post: post)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crew'));
    await tester.pumpAndSettle();
  }

  group('Own event crew', () {
    testWidgets('while the job runs: role, raise, chat and call', (
      tester,
    ) async {
      await pumpOwnEvent(tester, ownEvent(finished: false));

      expect(find.byTooltip('Change role (Lead)'), findsOneWidget);
      expect(find.byTooltip(_raise), findsOneWidget);
      expect(find.byTooltip(_message), findsOneWidget);
      expect(find.byTooltip(_call), findsOneWidget);
    });

    testWidgets('work completed, not yet paid: only Raise salary', (
      tester,
    ) async {
      await pumpOwnEvent(tester, ownEvent(finished: true));

      expect(find.byTooltip(_raise), findsOneWidget);
      expect(find.byTooltip('Change role (Lead)'), findsNothing);
      expect(find.byTooltip(_message), findsNothing);
      expect(find.byTooltip(_call), findsNothing);
      // The role is still shown, as a record of the job.
      expect(find.textContaining('Lead · '), findsOneWidget);
    });

    testWidgets('tapping the name offers only the raise', (tester) async {
      await pumpOwnEvent(tester, ownEvent(finished: true));

      await tester.tap(find.text('apple one'));
      await tester.pumpAndSettle();

      expect(
        find.text('Add extra pay before the crew is paid'),
        findsOneWidget,
      );
      expect(find.text('Message'), findsNothing);
      expect(find.text('Call'), findsNothing);
    });

    testWidgets('work completed and paid: no options left', (tester) async {
      await pumpOwnEvent(tester, ownEvent(finished: true, payment: 'Paid'));

      expect(find.byTooltip(_raise), findsNothing);
      expect(find.byTooltip(_message), findsNothing);
      expect(find.byTooltip(_call), findsNothing);
    });
  });

  // ---- Customer order, Status management ---------------------------------------------------

  BookingWorkerAssignment crew({String payment = 'Unpaid'}) =>
      BookingWorkerAssignment(
        workerProfileId: 'w-1',
        workerName: 'apple one',
        workerPhone: '9000000001',
        role: 'Lead',
        status: 'Completed',
        displayStatus: 'Completed',
        agreedSalaryAmount: 700,
        agreedSalaryUnit: 'PerEvent',
        paymentStatus: payment,
        hasPayoutDetails: true,
      );

  Booking order({required String status, String payment = 'Unpaid'}) => Booking(
    id: 'bk-1',
    businessOwnerProfileId: 'b-1',
    businessName: 'shajil shajil',
    customerProfileId: 'c-1',
    customerName: 'apple customer',
    businessServiceId: 's-1',
    serviceName: 'ieiw',
    serviceCategoryName: 'Carpentry',
    status: status,
    scheduledDate: DateTime(2026, 10, 30, 10),
    priceQuoted: 0,
    requiredWorkerCount: 1,
    assignedWorkers: [crew(payment: payment)],
  );

  Future<void> pumpOrder(WidgetTester tester, Booking booking) async {
    phone(tester);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BookingCrewList(
                booking: booking,
                canSetRoles: true,
                initiallyExpanded: true,
                raiseAssignmentAction: (w) => IconButton(
                  onPressed: () {},
                  tooltip: _raise,
                  icon: const Icon(Icons.trending_up_rounded),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Order crew', () {
    testWidgets('while the order runs: role, raise, chat and call', (
      tester,
    ) async {
      await pumpOrder(tester, order(status: 'InProgress'));

      expect(find.byTooltip('Change role (Lead)'), findsOneWidget);
      expect(find.byTooltip(_raise), findsOneWidget);
      expect(find.byTooltip(_message), findsOneWidget);
      expect(find.byTooltip(_call), findsOneWidget);
    });

    testWidgets('order completed, not yet paid: only Raise salary', (
      tester,
    ) async {
      await pumpOrder(tester, order(status: 'Completed'));

      expect(find.byTooltip(_raise), findsOneWidget);
      expect(find.byTooltip('Change role (Lead)'), findsNothing);
      expect(find.byTooltip(_message), findsNothing);
      expect(find.byTooltip(_call), findsNothing);
    });

    testWidgets('order completed and paid: no options left', (tester) async {
      await pumpOrder(tester, order(status: 'Completed', payment: 'Paid'));

      expect(find.byTooltip(_raise), findsNothing);
      expect(find.byTooltip(_message), findsNothing);
      expect(find.byTooltip(_call), findsNothing);
    });

    testWidgets('order cancelled: no role, chat or call', (tester) async {
      await pumpOrder(tester, order(status: 'Cancelled'));

      expect(find.byTooltip('Change role (Lead)'), findsNothing);
      expect(find.byTooltip(_message), findsNothing);
      expect(find.byTooltip(_call), findsNothing);
    });
  });

  // ---- Why Raise salary is missing: the payment state on the crew row ----------------------
  //
  // Reported from a phone: an order "not paid yet" with no Raise salary. The worker's payout had
  // been tried and failed, which locks the wage — but nothing on the row said so.

  group('Order crew shows where each wage stands', () {
    for (final (status, label) in [
      ('Failed', 'Payment failed'),
      ('Processing', 'Sending'),
      ('AwaitingWorkerConfirmation', 'Awaiting confirmation'),
      ('Disputed', 'Disputed'),
      ('Paid', 'Paid'),
    ]) {
      testWidgets('$status reads "$label", with no Raise salary', (
        tester,
      ) async {
        await pumpOrder(tester, order(status: 'Completed', payment: status));

        expect(find.textContaining('· $label'), findsOneWidget);
        expect(find.byTooltip(_raise), findsNothing);
      });
    }

    testWidgets('Unpaid says nothing, and Raise salary is offered', (
      tester,
    ) async {
      await pumpOrder(tester, order(status: 'Completed'));

      expect(find.textContaining('Payment failed'), findsNothing);
      expect(find.textContaining('· Paid'), findsNothing);
      expect(find.byTooltip(_raise), findsOneWidget);
    });

    testWidgets("a post hire shows the post's payment state", (tester) async {
      // The order's own row for a post hire carries no wage; the wage and its state are on the
      // post — as on #4C828BC0, where the payout to grape grape failed.
      phone(tester);
      final mirror = BookingWorkerAssignment(
        workerProfileId: 'w-1',
        workerName: 'grape grape',
        role: 'Lead',
        status: 'Completed',
        displayStatus: 'Completed',
        paymentStatus: 'Unpaid',
      );
      final booking = Booking(
        id: 'bk-1',
        businessOwnerProfileId: 'b-1',
        businessName: 'shajil shajil',
        customerProfileId: 'c-1',
        customerName: 'orange orange',
        businessServiceId: 's-1',
        serviceName: 'House cleaning',
        serviceCategoryName: 'Cleaning',
        status: 'Completed',
        scheduledDate: DateTime(2026, 10, 23, 10),
        priceQuoted: 0,
        requiredWorkerCount: 1,
        assignedWorkers: [mirror],
      );
      final failedHire = HiringPostApplication(
        id: 'a-1',
        workerProfileId: 'w-1',
        workerName: 'grape grape',
        status: 'Accepted',
        appliedAt: DateTime(2026, 10, 1),
        agreedSalaryAmount: 700,
        agreedSalaryUnit: 'PerEvent',
        paymentStatus: 'Failed',
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: BookingCrewList(
                  booking: booking,
                  canSetRoles: true,
                  initiallyExpanded: true,
                  postHires: {'w-1': failedHire},
                  raiseSalaryAction: (h) => IconButton(
                    onPressed: () {},
                    tooltip: _raise,
                    icon: const Icon(Icons.trending_up_rounded),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Lead · Completed · ₹700 per event · Payment failed'),
        findsOneWidget,
      );
      expect(find.byTooltip(_raise), findsNothing);
    });
  });
}
