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

/// Raise salary on a crew row: five workers posted at ₹1,000 owe ₹5,000; giving one of them ₹300
/// extra for extra work makes the job owe ₹5,300, split ₹1,300 + 4 × ₹1,000. Offered on the
/// Hiring tab's crew and on the Status management cards, and only before payment.
class _FakePosts extends BusinessHiringPostsNotifier {
  _FakePosts(this._posts);

  final List<HiringPost> _posts;
  final raises = <(String, double, String?)>[];
  final crewRaises = <(String, double)>[];

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

  @override
  Future<void> raiseCrewSalary(
    String postId, {
    required double increase,
    String? reason,
  }) async {
    crewRaises.add((postId, increase));
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

  // ---- Status management crew row: where raises are made ----------------------------------
  //
  // Changed: raises used to be offered on the Hire post tab too. They are now only in Status
  // management, where the job is run; the dialog checks below moved here unchanged.

  Future<_FakePosts> pumpStatusCrew(
    WidgetTester tester,
    List<HiringPostApplication> crew,
  ) async {
    phoneSize(tester);
    final data = post(crew);
    final fake = _FakePosts([data]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [businessHiringPostsProvider.overrideWith(() => fake)],
        child: MaterialApp(
          home: Scaffold(body: PostCrewWageList(post: data)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crew'));
    await tester.pumpAndSettle();
    return fake;
  }

  testWidgets('Hire post tab: no Raise salary there', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessHiringPostsProvider.overrideWith(
            () => _FakePosts([
              post([hire('1')]),
            ]),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: BusinessHiringPostsTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (find.text('Worker 1').evaluate().isEmpty) {
      await tester.tap(find.text('Crew'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Worker 1'), findsOneWidget);
    expect(find.byTooltip(_raiseTooltip), findsNothing);

    // Nor behind the worker's name.
    await tester.tap(find.text('Worker 1'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Raise salary'), findsNothing);
  });

  testWidgets('Status management: each unpaid crew member has Raise salary', (
    tester,
  ) async {
    await pumpStatusCrew(tester, [for (var i = 1; i <= 5; i++) hire('$i')]);

    expect(tester.takeException(), isNull);
    expect(find.byTooltip(_raiseTooltip), findsNWidgets(5));
    expect(find.byTooltip('Call worker'), findsNWidgets(5));
  });

  testWidgets('Status management: no Raise salary once a worker is paid', (
    tester,
  ) async {
    await pumpStatusCrew(tester, [
      hire('1', paymentStatus: 'Paid'),
      hire('2', paymentStatus: 'Processing'),
      hire('3'),
    ]);

    expect(find.byTooltip(_raiseTooltip), findsOneWidget);
  });

  testWidgets(
    '₹300 extra on one of five ₹1,000 workers shows ₹1,300 and ₹5,300',
    (tester) async {
      final fake = await pumpStatusCrew(tester, [
        for (var i = 1; i <= 5; i++) hire('$i'),
      ]);

      await tester.tap(find.byTooltip(_raiseTooltip).first);
      await tester.pumpAndSettle();
      expect(find.text('Pay crew: ₹5,000'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Extra pay'),
        '300',
      );
      await tester.pump();
      expect(find.text('₹1,000 + ₹300 = ₹1,300'), findsOneWidget);
      expect(find.text('Pay crew: ₹5,000 → ₹5,300'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Reason (optional)'),
        '3 extra hours',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Raise'));
      await tester.pumpAndSettle();

      expect(fake.raises, [('1', 1300.0, '3 extra hours')]);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('the dialog refuses no extra pay', (tester) async {
    final fake = await pumpStatusCrew(tester, [hire('1')]);

    await tester.tap(find.byTooltip(_raiseTooltip));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Extra pay'),
      '0',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Raise'));
    await tester.pumpAndSettle();

    expect(find.text('Enter the extra pay, more than ₹0.'), findsOneWidget);
    expect(find.text('Pay crew: ₹1,000'), findsOneWidget);
    expect(fake.raises, isEmpty);
  });

  testWidgets(
    'typing 200 as extra pay: ₹1,000 becomes ₹1,200, no shortcut buttons',
    (tester) async {
      final fake = await pumpStatusCrew(tester, [hire('1')]);

      await tester.tap(find.byTooltip(_raiseTooltip));
      await tester.pumpAndSettle();
      // Typed by hand only: the +₹200 / +₹500 shortcuts were taken out.
      expect(find.text('+₹200'), findsNothing);
      expect(find.text('+₹500'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Extra pay'),
        '200',
      );
      await tester.pump();
      expect(find.text('₹1,000 + ₹200 = ₹1,200'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Raise'));
      await tester.pumpAndSettle();

      expect(fake.raises, [('1', 1200.0, null)]);
    },
  );

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

  // ---- Tap a name, workers added directly, Raise all -------------------------------------

  Future<void> pumpDirectOrderCrew(
    WidgetTester tester,
    List<BookingWorkerAssignment> crew, {
    void Function(BookingWorkerAssignment, HiringPostApplication?)? onTap,
    VoidCallback? onRaiseAll,
  }) async {
    phoneSize(tester);
    final booking = Booking(
      id: 'bk-2',
      businessOwnerProfileId: '',
      businessName: '',
      customerProfileId: '',
      customerName: '',
      businessServiceId: '',
      serviceName: '',
      serviceCategoryName: '',
      status: 'Completed',
      scheduledDate: DateTime(2026, 10, 20),
      priceQuoted: 0,
      requiredWorkerCount: crew.length,
      assignedWorkers: crew,
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BookingCrewList(
                booking: booking,
                initiallyExpanded: true,
                raiseAssignmentAction: (w) => IconButton(
                  icon: const Icon(Icons.trending_up_rounded),
                  tooltip: _raiseTooltip,
                  onPressed: () {},
                ),
                onWorkerTap: onTap,
                onRaiseAll: onRaiseAll,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The screenshot's case: "grape grape", added to the order directly at ₹1,400 a day.
  BookingWorkerAssignment direct(
    String name, {
    String paymentStatus = 'Unpaid',
    double? original,
  }) => BookingWorkerAssignment(
    workerProfileId: 'w-$name',
    workerName: name,
    status: 'Completed',
    displayStatus: 'Completed',
    agreedSalaryAmount: 1400,
    agreedSalaryUnit: 'PerDay',
    originalSalaryAmount: original,
    paymentStatus: paymentStatus,
  );

  testWidgets(
    'order crew: a worker added directly can be raised before payment',
    (tester) async {
      await pumpDirectOrderCrew(tester, [
        direct('grape grape'),
        direct('paid worker', paymentStatus: 'Paid'),
      ]);

      expect(tester.takeException(), isNull);
      expect(find.byTooltip(_raiseTooltip), findsOneWidget);
    },
  );

  testWidgets('order crew: a raised direct wage says so', (tester) async {
    await pumpDirectOrderCrew(tester, [direct('grape grape', original: 1200)]);

    expect(find.textContaining('₹1,400 per day (raised)'), findsOneWidget);
  });

  testWidgets('order crew: tapping a name opens that worker', (tester) async {
    BookingWorkerAssignment? tapped;
    await pumpDirectOrderCrew(tester, [
      direct('grape grape'),
    ], onTap: (worker, hire) => tapped = worker);

    await tester.tap(find.text('grape grape'));
    expect(tapped?.workerName, 'grape grape');
  });

  testWidgets('order crew: Raise all only where the screen offers it', (
    tester,
  ) async {
    var raisedAll = false;
    await pumpDirectOrderCrew(tester, [
      direct('grape grape'),
    ], onRaiseAll: () => raisedAll = true);

    await tester.tap(find.text('Raise all'));
    expect(raisedAll, isTrue);

    await pumpDirectOrderCrew(tester, [direct('grape grape')]);
    expect(find.text('Raise all'), findsNothing);
  });

  Future<_FakePosts> pumpEventCrewWithFake(
    WidgetTester tester,
    List<HiringPostApplication> crew,
  ) async {
    phoneSize(tester);
    final fake = _FakePosts([post(crew)]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [businessHiringPostsProvider.overrideWith(() => fake)],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostCrewWageList(post: post(crew)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crew'));
    await tester.pumpAndSettle();
    return fake;
  }

  testWidgets('own event crew: tapping a name offers Raise salary', (
    tester,
  ) async {
    final fake = await pumpEventCrewWithFake(tester, [hire('1'), hire('2')]);

    await tester.tap(find.text('Worker 1'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Raise salary'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Raise salary'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Extra pay'),
      '500',
    );
    await tester.pump();
    expect(find.text('₹1,000 + ₹500 = ₹1,500'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Raise'));
    await tester.pumpAndSettle();
    expect(fake.raises, [('1', 1500.0, null)]);
  });

  testWidgets(
    'own event crew: a paid worker is offered no raise from the name',
    (tester) async {
      await pumpEventCrewWithFake(tester, [hire('1', paymentStatus: 'Paid')]);

      await tester.tap(find.text('Worker 1'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Raise salary'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Message'), findsOneWidget);
    },
  );

  testWidgets(
    'own event crew: Raise all adds ₹200 to each of five, ₹5,000 → ₹6,000',
    (tester) async {
      final fake = await pumpEventCrewWithFake(tester, [
        for (var i = 1; i <= 5; i++) hire('$i'),
      ]);

      await tester.tap(find.text('Raise all'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Extra pay for each'),
        '200',
      );
      await tester.pump();
      expect(find.text('Pay crew: ₹5,000 → ₹6,000'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Raise'));
      await tester.pumpAndSettle();
      expect(fake.crewRaises, [('p-1', 200.0)]);
    },
  );

  testWidgets('own event crew: no Raise all once everyone is paid', (
    tester,
  ) async {
    await pumpEventCrewWithFake(tester, [hire('1', paymentStatus: 'Paid')]);

    expect(find.text('Raise all'), findsNothing);
  });
}
