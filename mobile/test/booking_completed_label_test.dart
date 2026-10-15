import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';

/// What a finished order is called, per viewer.
///
/// The bug these exist for: the label was `isWageClear ? 'Completed' : 'Awaiting payment'`, and
/// `wageStatus` arrives **empty** for everyone except a business reading its own orders. So a worker's
/// job list and a customer's order list stamped "Awaiting payment" on every finished order — on data
/// that could not know whether a rupee was owed. A worker saw two jobs awaiting payment that had been
/// paid in full, while their own dashboard correctly said nothing was waiting. Absent information must
/// never read as bad news.
void main() {
  Booking booking({
    String status = 'Completed',
    String wageStatus = '',
    String? myPaymentStatus,
    double? myWageAmount,
  }) => Booking(
    id: 'b-1',
    businessOwnerProfileId: 'bo-1',
    businessName: 'Test Caterers',
    customerProfileId: 'c-1',
    customerName: 'A Customer',
    businessServiceId: 's-1',
    serviceName: 'Catering',
    serviceCategoryName: 'Events',
    status: status,
    scheduledDate: DateTime(2026, 9, 15),
    priceQuoted: 20000,
    wageStatus: wageStatus,
    myPaymentStatus: myPaymentStatus,
    myWageAmount: myWageAmount,
    completedAt: DateTime(2026, 9, 15),
  );

  group('a viewer with no wage information', () {
    test('is told the work is done, not that money is owed', () {
      // The worker's job list and the customer's order list, both of which ask the server for
      // bookings without wages.
      expect(booking().orderStatusLabel(), 'Completed');
    });

    test('and that is not merely because wages happen to be clear', () {
      final order = booking();
      expect(order.hasWageInfo, isFalse);
      expect(
        order.isWageClear,
        isFalse,
        reason: 'the old label read this false as "unpaid", which was the bug',
      );
      expect(order.orderStatusLabel(), 'Completed');
    });
  });

  group('the worker on the order', () {
    test('a wage of their own that has not arrived reads as awaiting payment', () {
      expect(
        booking(myPaymentStatus: 'Unpaid', myWageAmount: 900).orderStatusLabel(),
        'Awaiting payment',
      );
    });

    test('and so does one that was attempted and failed', () {
      expect(
        booking(myPaymentStatus: 'Failed', myWageAmount: 900).orderStatusLabel(),
        'Awaiting payment',
      );
    });

    test('their own paid wage reads as completed', () {
      expect(
        booking(myPaymentStatus: 'Paid', myWageAmount: 900).orderStatusLabel(),
        'Completed',
      );
    });

    test('a mirror assignment with no wage is not an unpaid wage', () {
      // The exact shape of the reported bug. Accepting a hiring-post offer on an order creates an
      // assignment deliberately without a salary — the money lives on the application — so this row
      // sits at Unpaid for ever while the worker has already been paid in full.
      final order = booking(myPaymentStatus: 'Unpaid');

      expect(order.hasMyWage, isFalse);
      expect(order.myWageIsOutstanding, isFalse);
      expect(order.orderStatusLabel(), 'Completed');
    });

    test('their own wage wins over the crew-wide roll-up', () {
      // Somebody else on the crew being unpaid is not this worker's unpaid wage.
      expect(
        booking(
          wageStatus: 'Outstanding',
          myPaymentStatus: 'Paid',
          myWageAmount: 900,
        ).orderStatusLabel(),
        'Completed',
      );
    });
  });

  group('the business reading its own orders', () {
    test('outstanding crew wages still read as awaiting payment', () {
      // Unchanged behaviour, and the reason the roll-up exists: the business is the one who owes it.
      expect(
        booking(wageStatus: 'Outstanding').orderStatusLabel(),
        'Awaiting payment',
      );
    });

    test('settled crew wages read as completed', () {
      expect(booking(wageStatus: 'Settled').orderStatusLabel(), 'Completed');
    });

    test('an order that owed no wages at all reads as completed', () {
      expect(
        booking(wageStatus: 'NoWagesThroughZuno').orderStatusLabel(),
        'Completed',
      );
    });

    test('a disputed wage is still money outstanding', () {
      expect(
        booking(wageStatus: 'Disputed').orderStatusLabel(),
        'Awaiting payment',
      );
    });
  });

  group('every other status is untouched', () {
    test('and none of them consult wages', () {
      expect(booking(status: 'Pending').orderStatusLabel(), 'Active');
      expect(booking(status: 'Confirmed').orderStatusLabel(), 'Confirmed');
      expect(booking(status: 'Assigned').orderStatusLabel(), 'Confirmed');
      expect(booking(status: 'InProgress').orderStatusLabel(), 'In progress');
      expect(booking(status: 'Cancelled').orderStatusLabel(), 'Cancelled');
    });
  });
}
