import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/domain/entities/booking_worker_assignment.dart';
import 'package:zuno/features/booking/presentation/providers/business_bookings_notifier.dart';
import 'package:zuno/features/booking/presentation/widgets/booking_crew_list.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_hiring_posts_tab.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post_application.dart';
import 'package:zuno/features/hiring_post/presentation/providers/business_hiring_posts_notifier.dart';

/// The role icon on a crew row.
///
/// Setting a role was only possible by holding the row, and nobody found it. Each crew member the
/// business can give a role to now has a badge icon: outlined to assign one, filled once set.
void main() {
  BookingWorkerAssignment worker({
    String name = 'Ravi',
    String status = 'Accepted',
    String displayStatus = 'Active',
    String? role,
    double? salary = 800,
  }) => BookingWorkerAssignment(
    workerProfileId: 'w-$name',
    workerName: name,
    workerPhone: '9000000000',
    role: role,
    status: status,
    displayStatus: displayStatus,
    agreedSalaryAmount: salary,
    agreedSalaryUnit: salary == null ? null : 'PerEvent',
    paymentStatus: 'Unpaid',
    hasPayoutDetails: true,
  );

  Booking order(
    List<BookingWorkerAssignment> crew, {
    String status = 'Confirmed',
  }) => Booking(
    id: 'bk-1',
    businessOwnerProfileId: 'b-1',
    businessName: 'Demo',
    customerProfileId: 'c-1',
    customerName: 'Asha',
    businessServiceId: 's-1',
    serviceName: 'Catering',
    serviceCategoryName: 'Events',
    status: status,
    scheduledDate: DateTime(2026, 11, 1),
    priceQuoted: 0,
    requiredWorkerCount: crew.length,
    assignedWorkers: crew,
  );

  Future<void> pump(
    WidgetTester tester,
    Booking booking, {
    bool canSetRoles = true,
    bool withRaise = false,
    double width = 720,
  }) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              // The card's inset on Status management, so the row gets the width it gets there.
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: BookingCrewList(
                  booking: booking,
                  canSetRoles: canSetRoles,
                  initiallyExpanded: true,
                  raiseAssignmentAction: withRaise
                      ? (w) => IconButton(
                          onPressed: () {},
                          tooltip: 'Raise salary',
                          icon: const Icon(Icons.trending_up_rounded),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a crew member with no role shows Assign role', (tester) async {
    await pump(tester, order([worker()]));

    expect(find.byTooltip('Assign role'), findsOneWidget);
    expect(find.byIcon(Icons.badge_outlined), findsOneWidget);
  });

  testWidgets('a crew member with a role shows it is set', (tester) async {
    await pump(tester, order([worker(role: 'Lead')]));

    expect(find.byTooltip('Change role (Lead)'), findsOneWidget);
    expect(find.byIcon(Icons.badge), findsOneWidget);
    expect(find.byIcon(Icons.badge_outlined), findsNothing);
  });

  testWidgets('tapping the icon opens the role sheet', (tester) async {
    await pump(tester, order([worker()]));

    await tester.tap(find.byTooltip('Assign role'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('holding the row still opens the role sheet', (tester) async {
    await pump(tester, order([worker()]));

    await tester.longPress(find.text('Ravi'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('only crew who have said yes get the icon', (tester) async {
    await pump(
      tester,
      order([
        worker(name: 'Ravi'),
        worker(name: 'Done', status: 'Completed', displayStatus: 'Completed'),
        worker(name: 'Waiting', status: 'Assigned', displayStatus: 'Awaiting'),
        worker(name: 'Nope', status: 'Rejected', displayStatus: 'Declined'),
      ]),
    );

    // Ravi and the worker who finished their part; not the unanswered or the declined.
    expect(find.byTooltip('Assign role'), findsNWidgets(2));
  });

  testWidgets('not offered where the viewer cannot set roles', (tester) async {
    await pump(tester, order([worker()]), canSetRoles: false);

    expect(find.byTooltip('Assign role'), findsNothing);
  });

  for (final status in ['Pending', 'Completed', 'Cancelled']) {
    testWidgets('not offered on a $status order', (tester) async {
      await pump(tester, order([worker()], status: status));

      expect(find.byTooltip('Assign role'), findsNothing);
    });
  }

  testWidgets('a long name with every action still fits a narrow phone', (
    tester,
  ) async {
    // 360dp wide: role, raise, message and call beside a long name.
    await pump(
      tester,
      order([worker(name: 'Krishnankutty Ramachandran')]),
      withRaise: true,
    );

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Assign role'), findsOneWidget);
    expect(find.byTooltip('Raise salary'), findsOneWidget);
    expect(find.byTooltip('Message worker'), findsOneWidget);
    expect(find.byTooltip('Call worker'), findsOneWidget);
  });

  // ---- Hire post crew -------------------------------------------------------------------------
  //
  // A post raised for an order shares its crew with the order, so the role is the same one
  // Status management shows, set from here too. The business's own events have no order, so no
  // role to set.

  group('Hire post crew', () {
    HiringPostApplication hire(String name, {String status = 'Accepted'}) =>
        HiringPostApplication(
          id: 'a-$name',
          workerProfileId: 'w-$name',
          workerName: name,
          workerPhone: '9000000000',
          status: status,
          appliedAt: DateTime(2026, 10, 1),
          agreedSalaryAmount: 700,
          agreedSalaryUnit: 'PerEvent',
        );

    HiringPost post(List<HiringPostApplication> crew, {String? bookingId}) =>
        HiringPost(
          id: 'p-1',
          businessOwnerProfileId: 'b-1',
          bookingId: bookingId,
          bookingStatus: bookingId == null ? null : 'Confirmed',
          businessName: 'Demo',
          title: 'House cleaning',
          eventDate: DateTime.now().add(const Duration(days: 3)),
          workersNeeded: 3,
          salaryAmount: 700,
          confirmedCount: crew.where((a) => a.isAccepted).length,
          filledCount: crew.where((a) => a.isAccepted).length,
          status: 'Open',
          createdDate: DateTime(2026, 10, 1),
          applications: crew,
        );

    Future<void> pumpHire(
      WidgetTester tester,
      HiringPost data, {
      List<Booking> orders = const [],
    }) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessHiringPostsProvider.overrideWith(() => _Posts([data])),
            businessBookingsProvider.overrideWith(() => _Bookings(orders)),
          ],
          child: const MaterialApp(
            home: Scaffold(body: BusinessHiringPostsTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (find.text(data.applications.first.workerName).evaluate().isEmpty) {
        await tester.tap(find.text('Crew'));
        await tester.pumpAndSettle();
      }
    }

    testWidgets('a post for an order offers the role icon', (tester) async {
      await pumpHire(
        tester,
        post([hire('Ravi'), hire('Anita')], bookingId: 'bk-1'),
        orders: [
          order([worker(name: 'Ravi', role: 'Lead'), worker(name: 'Anita')]),
        ],
      );

      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Change role (Lead)'), findsOneWidget);
      expect(find.byTooltip('Assign role'), findsOneWidget);
    });

    testWidgets('tapping it opens the role sheet for that worker', (
      tester,
    ) async {
      await pumpHire(
        tester,
        post([hire('Anita')], bookingId: 'bk-1'),
        orders: [
          order([worker(name: 'Anita')]),
        ],
      );

      await tester.tap(find.byTooltip('Assign role'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Anita'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('own events have no order, so no role icon', (tester) async {
      await pumpHire(tester, post([hire('Ravi')]));

      expect(find.byTooltip('Assign role'), findsNothing);
    });

    testWidgets('applicants and pending offers get no role icon', (
      tester,
    ) async {
      await pumpHire(
        tester,
        post([
          hire('Ravi', status: 'Applied'),
          hire('Anita', status: 'Confirmed'),
        ], bookingId: 'bk-1'),
        orders: [
          order([worker(name: 'Ravi'), worker(name: 'Anita')]),
        ],
      );

      expect(find.byTooltip('Assign role'), findsNothing);
    });

    testWidgets('no role icon once the order is finished', (tester) async {
      await pumpHire(
        tester,
        post([hire('Ravi')], bookingId: 'bk-1'),
        orders: [
          order([worker(name: 'Ravi')], status: 'Completed'),
        ],
      );

      expect(find.byTooltip('Assign role'), findsNothing);
    });

    testWidgets('no role icon while orders are still loading', (tester) async {
      await pumpHire(
        tester,
        post([hire('Ravi')], bookingId: 'bk-1'),
        orders: const [],
      );

      expect(find.byTooltip('Assign role'), findsNothing);
    });
  });
}

class _Posts extends BusinessHiringPostsNotifier {
  _Posts(this._posts);
  final List<HiringPost> _posts;
  @override
  Future<List<HiringPost>> build() async => _posts;
}

class _Bookings extends BusinessBookingsNotifier {
  _Bookings(this._orders);
  final List<Booking> _orders;
  @override
  Future<List<Booking>> build() async => _orders;
}
