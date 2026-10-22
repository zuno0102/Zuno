import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/domain/entities/booking_worker_assignment.dart';
import 'package:zuno/features/booking/presentation/widgets/booking_crew_list.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_hiring_posts_tab.dart';
import 'package:zuno/features/business_owner/presentation/widgets/post_crew_wage_list.dart';
import 'package:zuno/features/business_owner/presentation/widgets/raise_salary_dialog.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post_application.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post_salary_adjustment.dart';
import 'package:zuno/features/hiring_post/presentation/providers/business_hiring_posts_notifier.dart';

/// Raise salary on a crew row: five workers posted at ₹1,000 owe ₹5,000; raising one of them to
/// ₹1,300 for extra work makes the job owe ₹5,300, split ₹1,300 + 4 × ₹1,000. Offered on the
/// Hiring tab's crew and on the Status management cards, and only before payment.
class _FakePosts extends BusinessHiringPostsNotifier {
  _FakePosts(this._posts);

  final List<HiringPost> _posts;
  final raises = <(String, double, String?)>[];

  @override
  Future<List<HiringPost>> build() async => _posts;

  @override
  Future<void> raiseAgreedSalary({
    required String applicationId,
    required double newAmount,
    String? reason,
  }) async {
    raises.add((applicationId, newAmount, reason));
  }
}

const _raiseTooltip = 'Raise salary';

void main() {
  final createdOn = DateTime(2026, 9, 1, 10);

  HiringPostApplication hire(
    String id, {
    String status = 'Accepted',
    String paymentStatus = 'Unpaid',
    double? salary = 1000,
    bool raised = false,
  }) => HiringPostApplication(
    id: id,
    workerProfileId: 'w-$id',
    workerName: 'Worker $id',
    workerPhone: '9000000000',
    status: status,
    appliedAt: createdOn,
    agreedSalaryAmount: salary,
    agreedSalaryUnit: salary == null ? null : 'PerEvent',
    paymentStatus: paymentStatus,
    salaryAdjustments: raised
        ? [
            HiringPostSalaryAdjustment(
              id: 'adj-$id',
              previousAmount: 1000,
              newAmount: salary!,
              adjustedAt: createdOn,
            ),
          ]
        : const [],
  );

  HiringPost post(List<HiringPostApplication> crew, {String? bookingId}) =>
      HiringPost(
        id: 'p-1',
        businessOwnerProfileId: 'b-1',
        bookingId: bookingId,
        businessName: 'Test Owner',
        title: 'Wedding catering',
        eventDate: DateTime.now().add(const Duration(days: 7)),
        workersNeeded: crew.length,
        salaryAmount: 1000,
        confirmedCount: crew.length,
        filledCount: crew.length,
        status: 'Open',
        createdDate: createdOn,
        outstandingAmount: crew
            .where((a) => a.isAccepted && !a.isPaid)
            .fold(0, (sum, a) => sum + (a.agreedSalaryAmount ?? 0)),
        applications: crew,
      );

  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  // ---- The rule ---------------------------------------------------------------------------

  group('canRaiseSalary', () {
    test('an accepted, unpaid worker can be raised', () {
      expect(hire('1').canRaiseSalary, isTrue);
    });

    test('a worker still holding an offer can be raised', () {
      expect(hire('1', status: 'Confirmed').canRaiseSalary, isTrue);
    });

    for (final status in ['Applied', 'Rejected', 'Declined']) {
      test('a worker who is $status cannot be raised', () {
        expect(hire('1', status: status).canRaiseSalary, isFalse);
      });
    }

    test('a worker with no agreed salary cannot be raised', () {
      expect(hire('1', salary: null).canRaiseSalary, isFalse);
    });

    for (final payment in [
      'Processing',
      'Paid',
      'Failed',
      'Disputed',
      'AwaitingWorkerConfirmation',
    ]) {
      test('once payment is $payment the salary is locked', () {
        expect(hire('1', paymentStatus: payment).canRaiseSalary, isFalse);
      });
    }
  });

  // ---- Hiring tab crew row ----------------------------------------------------------------

  Future<_FakePosts> pumpHiringTab(
    WidgetTester tester,
    List<HiringPostApplication> crew,
  ) async {
    phoneSize(tester);
    final fake = _FakePosts([post(crew)]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [businessHiringPostsProvider.overrideWith(() => fake)],
        child: const MaterialApp(
          home: Scaffold(body: BusinessHiringPostsTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (find.text(crew.first.workerName).evaluate().isEmpty) {
      await tester.tap(find.text('Crew'));
      await tester.pumpAndSettle();
    }
    return fake;
  }

  testWidgets('Hiring tab: each unpaid crew member has Raise salary', (
    tester,
  ) async {
    await pumpHiringTab(tester, [for (var i = 1; i <= 5; i++) hire('$i')]);

    expect(tester.takeException(), isNull);
    expect(find.byTooltip(_raiseTooltip), findsNWidgets(5));
    expect(find.byTooltip('Call worker'), findsNWidgets(5));
  });

  testWidgets('Hiring tab: no Raise salary once a worker is paid', (
    tester,
  ) async {
    await pumpHiringTab(tester, [
      hire('1', paymentStatus: 'Paid'),
      hire('2', paymentStatus: 'Processing'),
      hire('3'),
    ]);

    expect(find.byTooltip(_raiseTooltip), findsOneWidget);
  });

  testWidgets('raising one of five ₹1,000 workers to ₹1,300 shows ₹5,300', (
    tester,
  ) async {
    final fake = await pumpHiringTab(tester, [
      for (var i = 1; i <= 5; i++) hire('$i'),
    ]);

    await tester.tap(find.byTooltip(_raiseTooltip).first);
    await tester.pumpAndSettle();
    expect(find.text('Crew total: ₹5,000'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'New amount'),
      '1300',
    );
    await tester.pump();
    expect(find.text('Crew total: ₹5,000 → ₹5,300'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Reason (optional)'),
      '3 extra hours',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Raise'));
    await tester.pumpAndSettle();

    expect(fake.raises, [('1', 1300.0, '3 extra hours')]);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('the dialog refuses an amount that is not a raise', (
    tester,
  ) async {
    final fake = await pumpHiringTab(tester, [hire('1')]);

    await tester.tap(find.byTooltip(_raiseTooltip));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New amount'),
      '1000',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Raise'));
    await tester.pumpAndSettle();

    expect(find.text('Must be more than the agreed ₹1,000.'), findsOneWidget);
    expect(find.text('Crew total: ₹1,000'), findsOneWidget);
    expect(fake.raises, isEmpty);
  });

  // ---- Status management: order card crew -------------------------------------------------

  BookingWorkerAssignment onOrder(HiringPostApplication hire) =>
      BookingWorkerAssignment(
        workerProfileId: hire.workerProfileId,
        workerName: hire.workerName,
        workerPhone: hire.workerPhone,
        status: 'Accepted',
        displayStatus: 'Active',
        paymentStatus: 'Unpaid',
      );

  Future<void> pumpOrderCrew(
    WidgetTester tester,
    List<HiringPostApplication> hires, {
    bool withRaise = true,
  }) async {
    phoneSize(tester);
    final booking = Booking(
      id: 'bk-1',
      businessOwnerProfileId: '',
      businessName: '',
      customerProfileId: '',
      customerName: '',
      businessServiceId: '',
      serviceName: '',
      serviceCategoryName: '',
      status: 'Confirmed',
      scheduledDate: DateTime(2026, 1, 1),
      priceQuoted: 0,
      requiredWorkerCount: hires.length,
      assignedWorkers: [for (final h in hires) onOrder(h)],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BookingCrewList(
                booking: booking,
                initiallyExpanded: true,
                postHires: {for (final h in hires) h.workerProfileId: h},
                raiseSalaryAction: withRaise
                    ? (h) => RaiseSalaryButton(application: h, crewTotal: 0)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('order crew: post hires show their wage, raise and owed total', (
    tester,
  ) async {
    await pumpOrderCrew(tester, [
      hire('1', salary: 1300, raised: true),
      for (var i = 2; i <= 5; i++) hire('$i'),
    ]);

    expect(tester.takeException(), isNull);
    // Not "Paid outside Zuno": the wage was agreed on the post.
    expect(find.textContaining('Paid outside Zuno'), findsNothing);
    expect(find.textContaining('₹1,300 per event (raised)'), findsOneWidget);
    expect(find.textContaining('₹1,000 per event'), findsNWidgets(4));
    expect(find.text('₹5,300 owed'), findsOneWidget);
    expect(find.byTooltip(_raiseTooltip), findsNWidgets(5));
  });

  testWidgets('order crew: a paid post hire is not offered a raise', (
    tester,
  ) async {
    await pumpOrderCrew(tester, [hire('1', paymentStatus: 'Paid'), hire('2')]);

    expect(find.byTooltip(_raiseTooltip), findsOneWidget);
    expect(find.text('₹1,000 owed'), findsOneWidget);
  });

  testWidgets('order crew: no raise action where the screen gives none', (
    tester,
  ) async {
    await pumpOrderCrew(tester, [hire('1')], withRaise: false);

    expect(find.byTooltip(_raiseTooltip), findsNothing);
    expect(find.textContaining('₹1,000 per event'), findsOneWidget);
  });

  // ---- Status management: own-event card crew ---------------------------------------------

  Future<void> pumpEventCrew(
    WidgetTester tester,
    List<HiringPostApplication> crew,
  ) async {
    phoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: PostCrewWageList(post: post(crew))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crew'));
    await tester.pumpAndSettle();
  }

  testWidgets('own event crew: wages, owed total and raise before payment', (
    tester,
  ) async {
    await pumpEventCrew(tester, [
      hire('1', salary: 1300, raised: true),
      for (var i = 2; i <= 5; i++) hire('$i'),
      hire('6', status: 'Applied'),
    ]);

    expect(tester.takeException(), isNull);
    // Applicants are not crew.
    expect(find.text('Worker 6'), findsNothing);
    expect(find.text('₹5,300 owed'), findsOneWidget);
    expect(find.textContaining('₹1,300 per event (raised)'), findsOneWidget);
    expect(find.byTooltip(_raiseTooltip), findsNWidgets(5));
  });

  testWidgets('own event crew: nothing to raise once everyone is paid', (
    tester,
  ) async {
    await pumpEventCrew(tester, [hire('1', paymentStatus: 'Paid')]);

    expect(find.byTooltip(_raiseTooltip), findsNothing);
    expect(find.textContaining('Paid'), findsOneWidget);
  });

  testWidgets('own event crew: hidden while nobody is hired', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCrewWageList(post: post([hire('1', status: 'Applied')])),
        ),
      ),
    );

    expect(find.text('Crew'), findsNothing);
  });
}
