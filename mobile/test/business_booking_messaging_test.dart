import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/domain/entities/booking_message.dart';
import 'package:zuno/features/booking/domain/entities/rating.dart';
import 'package:zuno/features/booking/presentation/providers/booking_message_providers.dart';
import 'package:zuno/features/booking/presentation/providers/business_bookings_notifier.dart';
import 'package:zuno/features/booking/presentation/screens/booking_chat_screen.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_booking_detail_screen.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_orders_tab.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/presentation/providers/business_hiring_posts_notifier.dart';
import 'package:zuno/shared/widgets/status_pill.dart';

/// The business's side of a booking conversation.
///
/// It had none: no control on an order and no list of conversations, so the only way in was a chat
/// notification — which arrives only after the customer has written. A business could reply and
/// never start, and once the notification was cleared the thread was unreachable.
///
/// What these cover is what the app decides: when the way in is offered, who it says the other
/// person is, and that an empty list does not dead-end. Who may message at all is the server's
/// rule, mirrored by `Booking.canBeMessaged` and pinned by `booking_can_be_messaged_test.dart`.
class _FakeThreads extends BookingThreads {
  _FakeThreads(this._threads);

  final List<BookingThread> _threads;

  @override
  Future<List<BookingThread>> build() async => _threads;
}

class _FakeBusinessBookings extends BusinessBookingsNotifier {
  _FakeBusinessBookings(this._orders);

  final List<Booking> _orders;

  @override
  Future<List<Booking>> build() async => _orders;
}

/// Status management watches this, and TabBarView builds the tab next to the open one — so an
/// un-overridden copy would reach for the network and the pump would never settle.
class _FakePosts extends BusinessHiringPostsNotifier {
  @override
  Future<List<HiringPost>> build() async => const [];
}

/// The conversation behind the chat screen, without its 6-second poll.
class _FakeConversation extends BookingConversation {
  @override
  Future<List<BookingMessage>> build(String bookingId) async => const [];
}

void main() {
  final scheduled = DateTime(2026, 11, 14, 10);

  Booking order({
    String status = 'Confirmed',
    String? customerPhone = '9876500000',
    Rating? rating,
  }) => Booking(
    id: 'bk-1',
    businessOwnerProfileId: 'bo-1',
    businessName: 'Shajil Caterers',
    customerProfileId: 'c-1',
    customerName: 'Beaulin',
    customerPhone: customerPhone,
    businessServiceId: 's-1',
    serviceName: 'Home wall painting',
    serviceCategoryName: 'Painting',
    status: status,
    scheduledDate: scheduled,
    priceQuoted: 1400,
    agreementStatus: 'NotRequired',
    rating: rating,
  );

  BookingThread thread({int unreadCount = 0}) => BookingThread(
    bookingId: 'bk-1',
    title: 'Home wall painting',
    counterpartName: 'Beaulin',
    scheduledDate: scheduled,
    bookingStatus: 'Confirmed',
    lastMessage: 'What time are you arriving?',
    lastMessageAt: DateTime(2026, 11, 10, 9),
    lastMessageIsMine: false,
    unreadCount: unreadCount,
  );

  Future<void> pumpOrders(
    WidgetTester tester, {
    List<Booking> orders = const [],
    List<BookingThread> threads = const [],
  }) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessBookingsProvider.overrideWith(
            () => _FakeBusinessBookings(orders),
          ),
          businessHiringPostsProvider.overrideWith(_FakePosts.new),
          bookingThreadsProvider.overrideWith(() => _FakeThreads(threads)),
          bookingConversationProvider.overrideWith2((_) => _FakeConversation()),
        ],
        child: const MaterialApp(home: Scaffold(body: BusinessOrdersTab())),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpDetail(WidgetTester tester, Booking booking) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessBookingsProvider.overrideWith(
            () => _FakeBusinessBookings([booking]),
          ),
        ],
        child: MaterialApp(home: BusinessBookingDetailScreen(booking: booking)),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the message icon on an order', () {
    testWidgets('is offered on an order the business has taken on', (
      tester,
    ) async {
      await pumpOrders(tester, orders: [order()]);

      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    });

    testWidgets('and not before it is confirmed, nor once it is cancelled', (
      tester,
    ) async {
      await pumpOrders(tester, orders: [order(status: 'Pending')]);
      expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);

      await pumpOrders(tester, orders: [order(status: 'Cancelled')]);
      expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
    });

    /// The case that would slip through if this were guarded by `canBeCalled`: calling a finished
    /// order is still reasonable, messaging it is not once the customer has rated — and the server
    /// refuses with "You rated this order, which closed its conversation."
    testWidgets('and not once the customer has rated it', (tester) async {
      await pumpOrders(
        tester,
        orders: [
          order(
            status: 'Completed',
            rating: Rating(score: 5, createdDate: DateTime(2026, 11, 15)),
          ),
        ],
      );

      expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
      // Still callable, which is what makes the two rules genuinely different.
      expect(find.byIcon(Icons.call), findsOneWidget);
    });

    testWidgets('opens that order\'s conversation, naming the customer', (
      tester,
    ) async {
      await pumpOrders(tester, orders: [order()]);

      await tester.tap(find.byIcon(Icons.chat_bubble_outline));
      await tester.pumpAndSettle();

      expect(find.byType(BookingChatScreen), findsOneWidget);
      // The customer, not the business's own name.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Beaulin'),
        ),
        findsOneWidget,
      );
    });

    /// A ListTile takes its height from title and subtitle, never from the trailing column, so a
    /// second button stacked under the first paints outside the card. This is the assertion that
    /// catches somebody turning the Row back into a Column.
    testWidgets('sits beside the call button without overflowing', (
      tester,
    ) async {
      await pumpOrders(tester, orders: [order()]);

      expect(find.byIcon(Icons.call), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the order card layout', () {
    // The status pill and the Message / Call buttons used to be squeezed into ~62px beside the
    // text: 6px apart, with buttons shrunk below a comfortable tap size.
    Future<void> pumpPhone(WidgetTester tester, List<Booking> orders) async {
      tester.view.physicalSize = const Size(
        720,
        1600,
      ); // 360dp, the narrowest phone targeted
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessBookingsProvider.overrideWith(
              () => _FakeBusinessBookings(orders),
            ),
            businessHiringPostsProvider.overrideWith(_FakePosts.new),
            bookingThreadsProvider.overrideWith(() => _FakeThreads(const [])),
            bookingConversationProvider.overrideWith2(
              (_) => _FakeConversation(),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: BusinessOrdersTab())),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder button(String tooltip) => find
        .ancestor(
          of: find.byTooltip(tooltip),
          matching: find.byType(IconButton),
        )
        .first;

    testWidgets('OrderCard_Confirmed_LeavesSpaceBetweenStatusAndButtons', (
      tester,
    ) async {
      await pumpPhone(tester, [order()]);

      final status = tester.getRect(find.byType(StatusPill));
      final message = tester.getRect(button('Message customer'));
      expect(message.top - status.bottom, greaterThanOrEqualTo(12));
      expect(tester.takeException(), isNull);
    });

    testWidgets('OrderCard_Buttons_AreAtLeast40dpToTap', (tester) async {
      await pumpPhone(tester, [order()]);

      for (final tip in ['Message customer', 'Call customer']) {
        final size = tester.getSize(button(tip));
        expect(size.width, greaterThanOrEqualTo(40), reason: tip);
        expect(size.height, greaterThanOrEqualTo(40), reason: tip);
      }
    });

    testWidgets('OrderCard_AnyShapeOfOrder_FitsA360dpPhone', (tester) async {
      Booking long(String id) => Booking(
        id: id,
        businessOwnerProfileId: 'bo-1',
        businessName: 'Shajil Caterers',
        customerProfileId: 'c-1',
        customerName: 'Beaulin Shajil Sundaram from Marthandam',
        customerPhone: '9876500000',
        businessServiceId: 's-1',
        serviceName: 'Home wall painting with two coats and primer',
        serviceCategoryName: 'Painting',
        variantName: 'Exterior, full house',
        status: 'Confirmed',
        scheduledDate: scheduled,
        priceQuoted: 1400,
        agreementStatus: 'NotRequired',
      );

      await pumpPhone(tester, [
        order(),
        order(status: 'Pending'), // no buttons at all
        order(customerPhone: null), // message only
        long('bk-long'),
      ]);

      expect(tester.takeException(), isNull);
    });

    testWidgets('OrderCard_Pending_ShowsStatusWithoutButtons', (tester) async {
      await pumpPhone(tester, [order(status: 'Pending')]);

      expect(find.byTooltip('Message customer'), findsNothing);
      expect(find.byTooltip('Call customer'), findsNothing);
    });
  });

  group('the Messages tab', () {
    testWidgets('joins the other two inside Orders', (tester) async {
      await pumpOrders(tester);

      expect(find.text('Bookings'), findsOneWidget);
      expect(find.text('Status management'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
    });

    testWidgets('lists conversations with the customer named', (tester) async {
      await pumpOrders(tester, threads: [thread()]);

      await tester.tap(find.text('Messages'));
      await tester.pumpAndSettle();

      expect(find.text('Beaulin'), findsOneWidget);
      expect(find.text('Home wall painting'), findsOneWidget);
      expect(find.text('What time are you arriving?'), findsOneWidget);
    });

    testWidgets('carries the number of unread messages', (tester) async {
      await pumpOrders(tester, threads: [thread(unreadCount: 3)]);

      expect(find.text('3'), findsWidgets);
    });

    testWidgets('and carries nothing when nothing is unread', (tester) async {
      await pumpOrders(tester, threads: [thread()]);

      expect(find.text('0'), findsNothing);
    });

    /// A thread exists only once somebody has written, so an empty list must send them somewhere a
    /// conversation can be started. This is also the test that fails if `DefaultTabController.of`
    /// is asked from above the controller, where it throws.
    testWidgets('points an empty list back at the orders', (tester) async {
      await pumpOrders(tester, orders: [order()]);

      await tester.tap(find.text('Messages'));
      await tester.pumpAndSettle();
      expect(find.text('No messages yet'), findsOneWidget);

      await tester.tap(find.text('Go to an order'));
      await tester.pumpAndSettle();

      expect(
        DefaultTabController.of(tester.element(find.byType(TabBarView))).index,
        0,
      );
      expect(find.byIcon(Icons.chat_bubble_outline), findsWidgets);
    });
  });

  group('the order detail screen', () {
    testWidgets('offers Message beside Call customer', (tester) async {
      await pumpDetail(tester, order());

      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Call customer'), findsOneWidget);
    });

    testWidgets('and no Message once the customer has rated it', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        order(
          status: 'Completed',
          rating: Rating(score: 4, createdDate: DateTime(2026, 11, 15)),
        ),
      );

      expect(find.text('Message'), findsNothing);
      expect(find.text('Call customer'), findsOneWidget);
    });
  });
}
