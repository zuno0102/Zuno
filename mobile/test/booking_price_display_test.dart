import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';

/// What the price row on an order actually says.
///
/// Worth its own tests because a per-person order's stored figure is a *rate*, not a total. Show
/// it bare and a ₹10,000 catering job reads as ₹500 — on the customer's screen, the business's,
/// and the worker's, all of which render the same value.
void main() {
  /// An order carrying nothing but the three values under test.
  ///
  /// Every other field is blank on purpose. They are required by the constructor and irrelevant
  /// to the arithmetic, and inventing names for them made this read like planted data — which it
  /// is not, and must not look like.
  ///
  /// The price, price type and crew size are not blank because they ARE the test: this file
  /// exists to prove that ₹500 a head with 18 people is stated correctly, and that an agreed
  /// ₹9,000 is never multiplied a second time into ₹162,000.
  Booking booking({
    required double price,
    String? priceType,
    int requiredWorkerCount = 1,
  }) => Booking(
    id: '',
    reference: '',
    businessOwnerProfileId: '',
    businessName: '',
    customerProfileId: '',
    customerName: '',
    businessServiceId: '',
    serviceName: '',
    serviceCategoryName: '',
    status: 'Pending',
    scheduledDate: DateTime(2026, 1, 1),
    priceQuoted: price,
    priceType: priceType,
    requiredWorkerCount: requiredWorkerCount,
  );

  group('a price that is not per person', () {
    test('a flat price shows the figure alone', () {
      expect(booking(price: 700, priceType: PriceType.fixed).priceDisplay(), '₹700');
    });

    test('an hourly price keeps its unit', () {
      expect(
        booking(price: 250, priceType: PriceType.hourly).priceDisplay(),
        '₹250/hr',
      );
    });

    test('an order placed before price types were recorded still reads correctly', () {
      // The 258 orders already in the database have no price type at all.
      expect(booking(price: 5000).priceDisplay(), '₹5,000');
    });
  });

  group('a per-person price', () {
    test('says so, and says the crew is unsettled, before a number is agreed', () {
      final result = booking(
        price: 500,
        priceType: PriceType.perPerson,
        requiredWorkerCount: 0,
      ).priceDisplay();

      expect(result, contains('₹500 per person'));
      expect(result, contains('to be agreed'));
      // The bare rate on its own would be read as the price of the job.
      expect(result, isNot('₹500'));
    });

    // Accepting an offer overwrites priceQuoted with the agreed TOTAL, so from that moment the
    // stored figure must not be multiplied again. Getting this backwards turns an agreed ₹9,000
    // into ₹162,000 on every screen that shows the order.
    test('shows the agreed total, not the rate, once terms are settled', () {
      expect(
        booking(
          price: 9000,
          priceType: PriceType.perPerson,
          requiredWorkerCount: 18,
        ).priceDisplay(),
        '₹9,000 · 18 people',
      );
    });

    test('names the headcount it was agreed at', () {
      // The case the whole feature exists for: the business wanted 20, the customer said 18.
      expect(
        booking(
          price: 10000,
          priceType: PriceType.perPerson,
          requiredWorkerCount: 20,
        ).priceDisplay(),
        '₹10,000 · 20 people',
      );
    });

    test('is flagged as per person so screens can treat it differently', () {
      expect(
        booking(price: 500, priceType: PriceType.perPerson).isPricedPerPerson,
        isTrue,
      );
      expect(booking(price: 500, priceType: PriceType.fixed).isPricedPerPerson, isFalse);
    });
  });
}
