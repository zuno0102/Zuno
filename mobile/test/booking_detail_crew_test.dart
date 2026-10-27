import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/domain/entities/booking_worker_assignment.dart';
import 'package:zuno/features/booking/presentation/providers/business_bookings_notifier.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_booking_detail_screen.dart';

/// The crew on an order's Booking Details screen starts closed, like everywhere else, and opens on
/// a tap. It used to open itself on this one screen.
class _Orders extends BusinessBookingsNotifier {
  _Orders(this._orders);
  final List<Booking> _orders;
  @override
  Future<List<Booking>> build() async => _orders;
}

void main() {
  final booking = Booking(
    id: 'bk-1',
    businessOwnerProfileId: 'bo-1',
    businessName: 'shajil shajil',
    customerProfileId: 'c-1',
    customerName: 'orange orange',
    customerPhone: '8590182955',
    businessServiceId: 's-1',
    serviceName: 'Drawing',
    serviceCategoryName: 'Painting',
    status: 'Completed',
    scheduledDate: DateTime(2026, 10, 20, 10),
    priceQuoted: 1500,
    agreementStatus: 'NotRequired',
    assignedWorkers: const [
      BookingWorkerAssignment(
        workerProfileId: 'w-1',
        workerName: 'grape grape',
        status: 'Completed',
        displayStatus: 'Completed',
      ),
    ],
  );

  Future<void> pumpDetail(WidgetTester tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessBookingsProvider.overrideWith(() => _Orders([booking])),
        ],
        child: MaterialApp(home: BusinessBookingDetailScreen(booking: booking)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the crew starts closed, with its count showing', (tester) async {
    await pumpDetail(tester);

    await tester.ensureVisible(find.text('Crew'));
    await tester.pumpAndSettle();

    expect(find.text('1 worked this job'), findsOneWidget);
    expect(find.text('grape grape'), findsNothing);
  });

  testWidgets('tapping Crew opens it', (tester) async {
    await pumpDetail(tester);

    await tester.ensureVisible(find.text('Crew'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crew'));
    await tester.pumpAndSettle();

    expect(find.text('grape grape'), findsOneWidget);
  });
}
