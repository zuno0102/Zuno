import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/domain/entities/rating.dart';
import 'package:zuno/features/booking/presentation/providers/customer_bookings_notifier.dart';

/// The number on the customer's Bookings tab: orders only the customer can move forward.
Booking order({
  String status = 'Confirmed',
  String agreementStatus = 'NotRequired',
  Rating? rating,
}) => Booking(
  id: 'b-1',
  businessOwnerProfileId: 'bo-1',
  businessName: 'shajil shajil',
  customerProfileId: 'c-1',
  customerName: 'Beaulin',
  businessServiceId: 's-1',
  serviceName: 'Home wall painting',
  serviceCategoryName: 'Painting',
  status: status,
  scheduledDate: DateTime(2026, 10, 24, 10),
  priceQuoted: 1200,
  agreementStatus: agreementStatus,
  rating: rating,
);

void main() {
  test('an offer from the business waiting for the customer counts', () {
    expect(bookingNeedsCustomer(order(status: 'Pending', agreementStatus: 'AwaitingCustomer')), isTrue);
  });

  test('a finished job not yet rated counts', () {
    expect(bookingNeedsCustomer(order(status: 'Completed')), isTrue);
  });

  test('a finished job already rated does not', () {
    expect(
      bookingNeedsCustomer(order(status: 'Completed', rating: Rating(score: 5, createdDate: DateTime(2026, 10, 25)))),
      isFalse,
    );
  });

  test('waiting on the business, or nothing to do, does not', () {
    expect(bookingNeedsCustomer(order(status: 'Pending', agreementStatus: 'AwaitingBusiness')), isFalse);
    expect(bookingNeedsCustomer(order()), isFalse);
  });

  test('a cancelled order never counts', () {
    expect(bookingNeedsCustomer(order(status: 'Cancelled', agreementStatus: 'AwaitingCustomer')), isFalse);
  });
}
