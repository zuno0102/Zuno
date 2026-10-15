import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/domain/entities/rating.dart';

/// When the two sides may message each other about an order.
///
/// The same window as the phone number, deliberately: a conversation opens when the business takes
/// the order on, and closes if it is called off. Before confirmation there is nothing agreed to
/// discuss — the offer on the booking is where a pending order is settled — and after cancellation
/// there is nothing left to arrange.
void main() {
  Booking booking(String status, {bool rated = false}) => Booking(
    rating: rated
        ? Rating(score: 5, createdDate: DateTime(2026, 10, 1))
        : null,
    id: 'b-1',
    businessOwnerProfileId: 'bo-1',
    businessName: 'Kerala Painters',
    customerProfileId: 'c-1',
    customerName: 'Zuno Customer',
    businessServiceId: 's-1',
    serviceName: 'Painting',
    serviceCategoryName: 'Home improvement',
    status: status,
    scheduledDate: DateTime(2026, 10, 20),
    priceQuoted: 4500,
  );

  group('the conversation is open', () {
    test('once the business has confirmed the order', () {
      expect(booking('Confirmed').canBeMessaged, isTrue);
    });

    test('while crew are assigned and while the work is under way', () {
      expect(booking('Assigned').canBeMessaged, isTrue);
      expect(booking('InProgress').canBeMessaged, isTrue);
    });

    test('and after it is finished, while there is still follow-up to do', () {
      // The window between finishing and rating is where a missing item or an invoice gets sorted.
      expect(booking('Completed').canBeMessaged, isTrue);
    });
  });

  group('and closed', () {
    test('before the business has taken the order on', () {
      expect(booking('Pending').canBeMessaged, isFalse);
    });

    test('and once the order is cancelled', () {
      expect(booking('Cancelled').canBeMessaged, isFalse);
    });

    test('and once the customer has rated it', () {
      // Rating is the customer's last act on an order — offered once, and it cannot be taken back —
      // so it closes the conversation with it.
      expect(booking('Completed', rated: true).canBeMessaged, isFalse);
    });

    test('a rating on an unfinished order does not close anything', () {
      // Defensive: only a finished-and-rated order is closed by the rating, not any row that happens
      // to carry one.
      expect(booking('InProgress', rated: true).canBeMessaged, isTrue);
    });
  });

  test('it follows the phone, except that a rating closes it', () {
    // The two were the same rule until rating was added. Pinned so the difference stays exactly one
    // case rather than quietly becoming two unrelated rules.
    for (final status in [
      'Pending',
      'Confirmed',
      'Assigned',
      'InProgress',
      'Completed',
      'Cancelled',
    ]) {
      expect(
        booking(status).canBeMessaged,
        booking(status).canBeCalled,
        reason: status,
      );
    }

    final rated = booking('Completed', rated: true);
    expect(rated.canBeCalled, isTrue, reason: 'the phone stays available');
    expect(rated.canBeMessaged, isFalse, reason: 'the conversation does not');
  });
}
