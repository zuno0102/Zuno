import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/domain/entities/booking_message.dart';
import 'package:zuno/features/booking/domain/entities/booking_worker_assignment.dart';
import 'package:zuno/features/booking/presentation/providers/booking_message_providers.dart';
import 'package:zuno/features/booking/presentation/providers/business_bookings_notifier.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_orders_tab.dart';
import 'package:zuno/features/catalog/domain/entities/order_stage.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/presentation/providers/business_hiring_posts_notifier.dart';
import 'package:zuno/features/notifications/presentation/providers/notification_providers.dart';

/// The numbers on the business's Orders tabs: "Bookings 1", "Status management 2",
/// "Messages 1".
///
/// They used to be one corner badge on Messages, sitting over the end of the word. Each tab now
/// says how many things in it are waiting on the business, written after its name.
///
/// Scenario rows covered (CODING_STANDARDS 13.1): happy path, boundaries (the day itself, nothing
/// waiting, 99/100), wrong state (pending, cancelled, completed, offer out), missing data (no crew,
/// event raised for an order, lapsed event), and the UI states loading, error, empty and data.

// ---- fakes -------------------------------------------------------------------------------------

class _Bookings extends BusinessBookingsNotifier {
  _Bookings(this._load);
  final Future<List<Booking>> Function() _load;
  @override
  Future<List<Booking>> build() => _load();
}

class _Posts extends BusinessHiringPostsNotifier {
  _Posts(this._posts);
  final List<HiringPost> _posts;
  @override
  Future<List<HiringPost>> build() async => _posts;
}

/// What the business has been told about and not opened yet.
class _Unread extends UnreadNotificationTargets {
  _Unread(this._keys);
  final Set<String> _keys;
  @override
  Future<Set<String>> build() async => _keys;
}

class _Threads extends BookingThreads {
  _Threads(this._threads);
  final List<BookingThread> _threads;
  @override
  Future<List<BookingThread>> build() async => _threads;
}

/// Sample stages, standing in for the server's list.
const _stages = [
  OrderStage(code: 'S1', label: 'Fresh', sortOrder: 1, showOnBookings: true),
  OrderStage(
    code: 'S2',
    label: 'Agreed',
    sortOrder: 2,
    showOnBookings: true,
    showOnWork: true,
  ),
  OrderStage(
    code: 'S3',
    label: 'Running',
    sortOrder: 3,
    showOnBookings: true,
    showOnWork: true,
  ),
  OrderStage(
    code: 'S4',
    label: 'Owed',
    sortOrder: 4,
    showOnBookings: true,
    showOnWork: true,
  ),
  OrderStage(
    code: 'S5',
    label: 'Closed',
    sortOrder: 5,
    showOnBookings: true,
    showOnWork: true,
  ),
  OrderStage(code: 'S6', label: 'Dropped', sortOrder: 6, showOnBookings: true),
];

// ---- builders ----------------------------------------------------------------------------------

Booking _order(
  String id, {
  required DateTime when,
  String status = 'Confirmed',
  String stage = '',
  String agreementStatus = 'NotRequired',
  bool acceptedWorker = false,
}) => Booking(
  id: id,
  businessOwnerProfileId: 'bo-1',
  businessName: 'Demo Painters',
  customerProfileId: 'c-1',
  customerName: 'Asha',
  businessServiceId: 's-1',
  serviceName: 'Home wall painting',
  serviceCategoryName: 'Painting',
  status: status,
  stage: stage,
  scheduledDate: when,
  priceQuoted: 5000,
  agreementStatus: agreementStatus,
  assignedWorkers: [
    if (acceptedWorker)
      const BookingWorkerAssignment(
        workerProfileId: 'w-1',
        workerName: 'Ravi',
        status: 'Accepted',
      ),
  ],
);

HiringPost _event(
  String id, {
  required DateTime when,
  DateTime? startedAt,
  DateTime? completedAt,
  String? bookingId,
  int filled = 1,
  String stage = '',
}) => HiringPost(
  id: id,
  businessOwnerProfileId: 'bo-1',
  bookingId: bookingId,
  businessName: 'Demo Painters',
  title: 'Catering crew',
  eventDate: when,
  workStartedAt: startedAt,
  workCompletedAt: completedAt,
  workersNeeded: 2,
  salaryAmount: 800,
  confirmedCount: filled,
  filledCount: filled,
  status: 'Open',
  stage: stage,
  createdDate: when,
);

BookingThread _thread(int unread, DateTime when) => BookingThread(
  bookingId: 'bk-1',
  title: 'Home wall painting',
  counterpartName: 'Asha',
  scheduledDate: when,
  bookingStatus: 'Confirmed',
  lastMessage: 'Yes boss',
  lastMessageAt: when,
  lastMessageIsMine: false,
  unreadCount: unread,
);

void main() {
  // The rules run on a fixed clock (CODING_STANDARDS 13.2).
  final now = DateTime(2026, 10, 20, 12);
  final earlierToday = now.subtract(const Duration(minutes: 30));
  final nextMonth = now.add(const Duration(days: 30));

  group('newOrdersAwaitingBusiness', () {
    // What the business has been told about and not opened, keyed as the app keys it.
    Set<String> unopened(List<String> ids) => {
      for (final id in ids) UnreadNotificationTargets.keyFor('booking', id),
    };

    test('newOrdersAwaitingBusiness_UnopenedPendingOrders_CountsEach', () {
      expect(
        newOrdersAwaitingBusiness([
          _order('a', when: nextMonth, status: 'Pending'),
          _order(
            'b',
            when: nextMonth,
            status: 'Pending',
            agreementStatus: 'AwaitingBusiness',
          ),
        ], unopened(['a', 'b'])),
        2,
      );
    });

    test('newOrdersAwaitingBusiness_FiveNewOneOpened_CountsFour', () {
      final five = [
        for (var i = 1; i <= 5; i++)
          _order('n$i', when: nextMonth, status: 'Pending'),
      ];
      expect(
        newOrdersAwaitingBusiness(
          five,
          unopened(['n1', 'n2', 'n3', 'n4', 'n5']),
        ),
        5,
      );
      // n3 opened: its notification is no longer unread.
      expect(
        newOrdersAwaitingBusiness(five, unopened(['n1', 'n2', 'n4', 'n5'])),
        4,
      );
    });

    test('newOrdersAwaitingBusiness_AllOpened_IsZeroEvenIfStillPending', () {
      expect(
        newOrdersAwaitingBusiness([
          _order('a', when: nextMonth, status: 'Pending'),
        ], const {}),
        0,
      );
    });

    test('newOrdersAwaitingBusiness_RatingTargetAlsoCountsAsUnopened', () {
      expect(
        newOrdersAwaitingBusiness(
          [_order('a', when: nextMonth, status: 'Pending')],
          {UnreadNotificationTargets.keyFor('BookingRating', 'a')},
        ),
        1,
      );
    });

    test('newOrdersAwaitingBusiness_UnreadAboutAChatOnly_NotCounted', () {
      // A message on the order belongs to Messages, not to "new order".
      expect(
        newOrdersAwaitingBusiness(
          [_order('a', when: nextMonth, status: 'Pending')],
          {UnreadNotificationTargets.keyFor('BookingChat', 'a')},
        ),
        0,
      );
    });

    test('newOrdersAwaitingBusiness_BusinessWaitingOnCustomer_NotCounted', () {
      expect(
        newOrdersAwaitingBusiness([
          _order(
            'a',
            when: nextMonth,
            status: 'Pending',
            agreementStatus: 'AwaitingCustomer',
          ),
        ], unopened(['a'])),
        0,
      );
    });

    test('newOrdersAwaitingBusiness_OrdersPastPending_NotCounted', () {
      final statuses = ['Confirmed', 'InProgress', 'Completed', 'Cancelled'];
      expect(
        newOrdersAwaitingBusiness([
          for (final status in statuses)
            _order(status, when: nextMonth, status: status),
        ], unopened(statuses)),
        0,
      );
    });

    test('newOrdersAwaitingBusiness_NoOrders_IsZero', () {
      expect(newOrdersAwaitingBusiness(const [], const {}), 0);
    });
  });
  group('workStepsReady', () {
    test('workStepsReady_OrderOnItsDayWithCrew_CountsAsStart', () {
      expect(
        workStepsReady(
          [_order('a', when: earlierToday, acceptedWorker: true)],
          const [],
          now: now,
        ),
        1,
      );
    });

    test('workStepsReady_OrderAtExactlyItsTime_CountsAsStart', () {
      expect(
        workStepsReady(
          [_order('a', when: now, acceptedWorker: true)],
          const [],
          now: now,
        ),
        1,
      );
    });

    test('workStepsReady_OrderInProgress_CountsAsComplete', () {
      expect(
        workStepsReady(
          [_order('a', when: earlierToday, status: 'InProgress')],
          const [],
          now: now,
        ),
        1,
      );
    });

    test('workStepsReady_OrderNotYetDue_NotCounted', () {
      expect(
        workStepsReady(
          [_order('a', when: nextMonth, acceptedWorker: true)],
          const [],
          now: now,
        ),
        0,
      );
    });

    test('workStepsReady_OrderWithNobodyOnCrew_NotCounted', () {
      expect(
        workStepsReady([_order('a', when: earlierToday)], const [], now: now),
        0,
      );
    });

    test('workStepsReady_OrderPendingCancelledOrCompleted_NotCounted', () {
      expect(
        workStepsReady(
          [
            for (final status in ['Pending', 'Cancelled', 'Completed'])
              _order(
                status,
                when: earlierToday,
                status: status,
                acceptedWorker: true,
              ),
          ],
          const [],
          now: now,
        ),
        0,
      );
    });

    test('workStepsReady_OwnEventToStartOrToComplete_CountsBoth', () {
      expect(
        workStepsReady(const [], [
          _event('start', when: earlierToday),
          _event('complete', when: earlierToday, startedAt: earlierToday),
        ], now: now),
        2,
      );
    });

    test('workStepsReady_EventRaisedForAnOrder_NotCountedTwice', () {
      expect(
        workStepsReady(const [], [
          _event('p', when: earlierToday, bookingId: 'bk-9'),
        ], now: now),
        0,
      );
    });

    test('workStepsReady_EventFinishedOrNotDueOrUnstaffed_NotCounted', () {
      expect(
        workStepsReady(const [], [
          _event(
            'done',
            when: earlierToday,
            startedAt: earlierToday,
            completedAt: now,
          ),
          _event('later', when: nextMonth),
          _event('nobody', when: earlierToday, filled: 0),
        ], now: now),
        0,
      );
    });

    test('workStepsReady_EventLapsedWithNoCrew_NotCounted', () {
      expect(
        workStepsReady(const [], [
          _event(
            'lapsed',
            when: now.subtract(const Duration(days: 3)),
            filled: 0,
          ),
        ], now: now),
        0,
      );
    });
  });

  group('countByStage', () {
    test('countByStage_MixedCodes_CountsEachFilterAndKeepsEmptyOnes', () {
      final counts = countByStage([
        'S1',
        'S2',
        'S2',
        'S3',
        'S6',
      ], _stages.onBookings);

      expect(counts, {'S1': 1, 'S2': 2, 'S3': 1, 'S4': 0, 'S5': 0, 'S6': 1});
    });

    test('countByStage_CodeNotAFilterOnThisTab_IsLeftOut', () {
      // S1 and S6 are not Status management filters, so they are not counted there.
      expect(countByStage(['S1', 'S6', 'S2'], _stages.onWork), {
        'S2': 1,
        'S3': 0,
        'S4': 0,
        'S5': 0,
      });
    });

    test('countByStage_NothingToCount_EveryFilterIsZero', () {
      expect(countByStage(const [], _stages.onWork).values, everyElement(0));
    });
  });

  group('BusinessOrdersTab labels', () {
    // The labels read the real clock, so these build their dates around it.
    final realNow = DateTime.now();
    final dueNow = realNow.subtract(const Duration(minutes: 30));
    final later = realNow.add(const Duration(days: 30));

    Future<void> pumpTabs(
      WidgetTester tester, {
      Future<List<Booking>> Function()? orders,
      List<HiringPost> posts = const [],
      int unread = 0,
      Set<String>? unopened,
      bool settle = true,
      bool tall = false,
      List<OrderStage> stages = _stages,
    }) async {
      // A 360dp-wide phone, the narrowest the app targets. [tall] gives the list room to build
      // every card, for tests that count them.
      tester.view.physicalSize = Size(720, tall ? 4800 : 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderStagesProvider.overrideWith((ref) async => stages),
            businessBookingsProvider.overrideWith(
              () => _Bookings(orders ?? () async => const []),
            ),
            businessHiringPostsProvider.overrideWith(() => _Posts(posts)),
            unreadNotificationTargetsProvider.overrideWith(
              () => _Unread(unopened ?? const {}),
            ),
            bookingThreadsProvider.overrideWith(
              () => _Threads([if (unread > 0) _thread(unread, realNow)]),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: BusinessOrdersTab())),
        ),
      );
      if (settle) await tester.pumpAndSettle();
    }

    Finder pillOn(String tab) => find.byKey(ValueKey('tabCount:$tab'));

    String countOn(WidgetTester tester, String tab) => tester
        .widget<Text>(
          find.descendant(of: pillOn(tab), matching: find.byType(Text)),
        )
        .data!;

    testWidgets('Tabs_WithWorkWaiting_ShowEachCountAfterItsName', (
      tester,
    ) async {
      await pumpTabs(
        tester,
        orders: () async => [
          _order('new', when: later, status: 'Pending'),
          _order('start', when: dueNow, acceptedWorker: true),
          _order('complete', when: dueNow, status: 'InProgress'),
        ],
        posts: [_event('own', when: dueNow)],
        unread: 1,
        unopened: {UnreadNotificationTargets.keyFor('booking', 'new')},
      );

      expect(countOn(tester, 'Bookings'), '1');
      expect(countOn(tester, 'Status management'), '3');
      expect(countOn(tester, 'Messages'), '1');
      // Three names and three counts fit a 360dp phone without spilling over.
      expect(tester.takeException(), isNull);
    });

    testWidgets('FromCustomers_FiveNewThenOneOpened_GoesFromFiveToFour', (
      tester,
    ) async {
      final ids = ['n1', 'n2', 'n3', 'n4', 'n5'];
      await pumpTabs(
        tester,
        orders: () async => [
          for (final id in ids) _order(id, when: later, status: 'Pending'),
        ],
        unopened: {
          for (final id in ids) UnreadNotificationTargets.keyFor('booking', id),
        },
      );
      expect(countOn(tester, 'Bookings'), '5');

      // What opening the order does: the detail screen marks it seen, which takes it out of the
      // unread set. (markBookingSeen also tells the server; forget is the same change, locally.)
      final container = ProviderScope.containerOf(
        tester.element(find.byType(BusinessOrdersTab)),
      );
      container
          .read(unreadNotificationTargetsProvider.notifier)
          .forget('Booking', 'n3');
      await tester.pumpAndSettle();

      expect(countOn(tester, 'Bookings'), '4');
    });

    testWidgets('FromCustomers_LastNewOneOpened_CountDisappears', (
      tester,
    ) async {
      await pumpTabs(
        tester,
        orders: () async => [_order('only', when: later, status: 'Pending')],
        unopened: {UnreadNotificationTargets.keyFor('booking', 'only')},
      );
      expect(countOn(tester, 'Bookings'), '1');

      ProviderScope.containerOf(tester.element(find.byType(BusinessOrdersTab)))
          .read(unreadNotificationTargetsProvider.notifier)
          .forget('Booking', 'only');
      await tester.pumpAndSettle();

      expect(pillOn('Bookings'), findsNothing);
      expect(find.text('Bookings'), findsOneWidget);
    });

    testWidgets('Tabs_NothingWaiting_ShowNamesOnly', (tester) async {
      await pumpTabs(tester);

      for (final tab in ['Bookings', 'Status management', 'Messages']) {
        expect(pillOn(tab), findsNothing);
        expect(find.text(tab), findsOneWidget);
      }
    });

    testWidgets('Tabs_WhileOrdersLoad_ShowNamesWithoutCounts', (tester) async {
      await pumpTabs(
        tester,
        orders: () =>
            Future.delayed(const Duration(seconds: 5), () => const []),
        settle: false,
      );
      await tester.pump();

      expect(pillOn('Bookings'), findsNothing);
      expect(find.text('Bookings'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('Tabs_WhenOrdersFailToLoad_ShowNamesAndNoCrash', (
      tester,
    ) async {
      await pumpTabs(tester, orders: () async => throw Exception('offline'));

      expect(pillOn('Bookings'), findsNothing);
      expect(pillOn('Status management'), findsNothing);
      expect(find.text('Bookings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tabs_CountAbove99_ShowsCappedPill', (tester) async {
      await pumpTabs(tester, unread: 100);
      expect(countOn(tester, 'Messages'), '99+');
    });

    testWidgets('Tabs_CountOf99_ShowsExactNumber', (tester) async {
      await pumpTabs(tester, unread: 99);
      expect(countOn(tester, 'Messages'), '99');
    });

    group('Bookings tab split by stage', () {
      List<Booking> mixed() => [
        _order('new-1', when: later, status: 'Pending', stage: 'S1'),
        _order('new-2', when: later, status: 'Pending', stage: 'S1'),
        _order('conf-1', when: later, stage: 'S2'),
        _order('conf-2', when: later, status: 'Assigned', stage: 'S2'),
        _order('done-1', when: dueNow, status: 'Completed', stage: 'S5'),
        _order('off-1', when: later, status: 'Cancelled', stage: 'S6'),
      ];

      Finder chip(String text) => find.widgetWithText(ChoiceChip, text);
      int cards() => find.byType(Card).evaluate().length;

      // Scrolled into view first, as a person would: the bar is wider than a phone.
      Future<void> pick(WidgetTester tester, String text) async {
        await tester.ensureVisible(chip(text));
        await tester.pumpAndSettle();
        await tester.tap(chip(text));
        await tester.pumpAndSettle();
      }

      testWidgets('Filters_AreTheServersStages_InItsOrder_WithCounts', (
        tester,
      ) async {
        await pumpTabs(tester, orders: () async => mixed(), tall: true);

        expect(tester.takeException(), isNull);
        final labels = tester
            .widgetList<ChoiceChip>(find.byType(ChoiceChip))
            .map((c) => (c.label as Text).data)
            .toList();
        expect(labels, [
          'All 6',
          'Fresh 2',
          'Agreed 2',
          'Running 0', // empty ones stay, so the row never jumps about
          'Owed 0',
          'Closed 1',
          'Dropped 1',
        ]);
      });

      testWidgets('TappingAStage_ShowsOnlyItsBookings_AllShowsEveryOne', (
        tester,
      ) async {
        await pumpTabs(tester, orders: () async => mixed(), tall: true);
        expect(cards(), 6);

        await pick(tester, 'Fresh 2');
        expect(cards(), 2);

        await pick(tester, 'Dropped 1');
        expect(cards(), 1);

        await pick(tester, 'All 6');
        expect(cards(), 6);
      });

      testWidgets('AnEmptyStage_SaysSoInTheServersWords', (tester) async {
        await pumpTabs(tester, orders: () async => mixed(), tall: true);

        await pick(tester, 'Running 0');

        expect(cards(), 0);
        expect(find.text('No running bookings'), findsOneWidget);
      });

      testWidgets('RenamingAStageOnTheServer_RenamesItsFilter', (tester) async {
        await pumpTabs(
          tester,
          orders: () async => mixed(),
          tall: true,
          stages: [
            for (final s in _stages)
              s.code == 'S1'
                  ? const OrderStage(
                      code: 'S1',
                      label: 'Just in',
                      sortOrder: 1,
                      showOnBookings: true,
                    )
                  : s,
          ],
        );

        expect(chip('Just in 2'), findsOneWidget);
        expect(chip('Fresh 2'), findsNothing);
      });
    });

    group('Status management tab split by stage', () {
      Finder chip(String text) => find.widgetWithText(ChoiceChip, text);

      Future<void> openTab(WidgetTester tester) async {
        await pumpTabs(
          tester,
          tall: true,
          orders: () async => [
            _order('conf', when: later, stage: 'S2'),
            _order('going', when: dueNow, status: 'InProgress', stage: 'S3'),
            _order('done', when: dueNow, status: 'Completed', stage: 'S5'),
            // Never on this tab: not accepted yet, or called off.
            _order('new', when: later, status: 'Pending', stage: 'S1'),
            _order('off', when: later, status: 'Cancelled', stage: 'S6'),
          ],
          posts: [_event('own', when: later, stage: 'S2')],
        );
        // The second tab. Its name is drawn in pieces when a count sits after it.
        await tester.tap(find.byType(Tab).at(1));
        await tester.pumpAndSettle();
      }

      Future<void> pick(WidgetTester tester, String text) async {
        await tester.ensureVisible(chip(text));
        await tester.pumpAndSettle();
        await tester.tap(chip(text));
        await tester.pumpAndSettle();
      }

      testWidgets('Filters_CountOrdersAndOwnEventsTogether', (tester) async {
        await openTab(tester);

        expect(tester.takeException(), isNull);
        // Four, not six: the order not accepted yet and the cancelled one never reach this tab.
        expect(chip('All 4'), findsOneWidget);
        // The confirmed order and the own event, both in S2.
        expect(chip('Agreed 2'), findsOneWidget);
        expect(chip('Running 1'), findsOneWidget);
        expect(chip('Owed 0'), findsOneWidget);
        expect(chip('Closed 1'), findsOneWidget);
      });

      testWidgets('TappingAStage_ShowsOnlyItsWork', (tester) async {
        await openTab(tester);
        expect(find.text('Catering crew'), findsOneWidget);

        await pick(tester, 'Running 1');
        expect(find.text('Catering crew'), findsNothing);
        expect(find.text('Home wall painting'), findsOneWidget);

        await pick(tester, 'Agreed 2');
        expect(find.text('Catering crew'), findsOneWidget);
        expect(find.text('Home wall painting'), findsOneWidget);

        await pick(tester, 'Owed 0');
        expect(find.text('Nothing owed'), findsOneWidget);
      });
    });

    testWidgets('Tabs_WithCount_ReadAsOneThingToScreenReaders', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpTabs(tester, unread: 2);
      // The tab adds its position ("Tab 3 of 3") around the label, so match the label within it.
      expect(find.bySemanticsLabel(RegExp('Messages, 2 new')), findsOneWidget);
      semantics.dispose();
    });
  });
}
