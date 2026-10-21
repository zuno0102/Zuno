import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/domain/entities/booking_message.dart';
import 'package:zuno/features/booking/presentation/providers/booking_message_providers.dart';
import 'package:zuno/features/booking/presentation/providers/customer_bookings_notifier.dart';
import 'package:zuno/features/customer/presentation/screens/customer_bookings_hub.dart';
import 'package:zuno/features/notifications/presentation/providers/notification_providers.dart';

/// The customer's Bookings bottom tab holds two top tabs — the orders, and the messages about them —
/// instead of chat having a bottom tab of its own.
class _Bookings extends CustomerBookingsNotifier {
  _Bookings(this._list);
  final List<Booking> _list;
  @override
  Future<List<Booking>> build() async => _list;
}

class _Threads extends BookingThreads {
  _Threads(this._list);
  final List<BookingThread> _list;
  @override
  Future<List<BookingThread>> build() async => _list;
}

class _Targets extends UnreadNotificationTargets {
  _Targets(this._set);
  final Set<String> _set;
  @override
  Future<Set<String>> build() async => _set;
}

Booking _offerWaiting() => Booking(
  id: 'b-1',
  businessOwnerProfileId: 'bo-1',
  businessName: 'shajil shajil',
  customerProfileId: 'c-1',
  customerName: 'Beaulin',
  businessServiceId: 's-1',
  serviceName: 'home wall painting',
  serviceCategoryName: 'Painting',
  status: 'Pending',
  scheduledDate: DateTime(2026, 10, 24, 22),
  priceQuoted: 1200,
  agreementStatus: 'AwaitingCustomer',
);

BookingThread _thread({int unread = 0}) => BookingThread(
  bookingId: 'b-1',
  title: 'home wall painting',
  counterpartName: 'shajil shajil',
  scheduledDate: DateTime(2026, 10, 24),
  bookingStatus: 'Confirmed',
  lastMessage: 'Can we start at 9?',
  lastMessageAt: DateTime(2026, 10, 20, 9),
  lastMessageIsMine: false,
  unreadCount: unread,
);

Future<void> _pump(
  WidgetTester tester, {
  required List<Booking> bookings,
  required List<BookingThread> threads,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        customerBookingsProvider.overrideWith(() => _Bookings(bookings)),
        bookingThreadsProvider.overrideWith(() => _Threads(threads)),
        unreadNotificationTargetsProvider.overrideWith(
          () => _Targets({'booking:b-1'}),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: CustomerBookingsHub())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on the orders, with Messages one tap away', (
    tester,
  ) async {
    await _pump(tester, bookings: [_offerWaiting()], threads: [_thread()]);

    expect(find.byKey(const Key('hubBookingsTab')), findsOneWidget);
    expect(find.byKey(const Key('hubMessagesTab')), findsOneWidget);
    // The order list is showing.
    expect(find.text('shajil shajil'), findsWidgets);

    await tester.tap(find.byKey(const Key('hubMessagesTab')));
    await tester.pumpAndSettle();

    expect(find.text('Can we start at 9?'), findsOneWidget);
  });

  testWidgets('each top tab carries its own count', (tester) async {
    await _pump(
      tester,
      bookings: [_offerWaiting()],
      threads: [_thread(unread: 3)],
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('hubBookingsTab')),
        matching: find.text('1'),
      ),
      findsOneWidget,
      reason: 'one offer waiting for the customer',
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('hubMessagesTab')),
        matching: find.text('3'),
      ),
      findsOneWidget,
      reason: 'three unread messages',
    );
  });

  testWidgets('no count when nothing is waiting', (tester) async {
    await _pump(tester, bookings: const [], threads: [_thread()]);

    expect(
      find.descendant(
        of: find.byKey(const Key('hubMessagesTab')),
        matching: find.byType(Badge),
      ),
      findsNothing,
    );
  });
}
