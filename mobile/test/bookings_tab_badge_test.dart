import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/domain/entities/rating.dart';
import 'package:zuno/features/booking/presentation/providers/customer_bookings_notifier.dart';
import 'package:zuno/features/notifications/presentation/providers/notification_providers.dart';

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
    expect(
      bookingNeedsCustomer(
        order(status: 'Pending', agreementStatus: 'AwaitingCustomer'),
      ),
      isTrue,
    );
  });

  test('a finished job not yet rated counts', () {
    expect(bookingNeedsCustomer(order(status: 'Completed')), isTrue);
  });

  test('a finished job already rated does not', () {
    expect(
      bookingNeedsCustomer(
        order(
          status: 'Completed',
          rating: Rating(score: 5, createdDate: DateTime(2026, 10, 25)),
        ),
      ),
      isFalse,
    );
  });

  test('waiting on the business, or nothing to do, does not', () {
    expect(
      bookingNeedsCustomer(
        order(status: 'Pending', agreementStatus: 'AwaitingBusiness'),
      ),
      isFalse,
    );
    expect(bookingNeedsCustomer(order()), isFalse);
  });

  test('a cancelled order never counts', () {
    expect(
      bookingNeedsCustomer(
        order(status: 'Cancelled', agreementStatus: 'AwaitingCustomer'),
      ),
      isFalse,
    );
  });

  // The number still means "you have something to do here", but it stops counting an order the
  // customer has already opened — and starts again when the business does something new on it.
  group('and stops once the customer has looked', () {
    Future<int> countFor(
      List<Booking> bookings,
      Set<String> unreadTargets,
    ) async {
      final container = ProviderContainer(
        overrides: [
          customerBookingsProvider.overrideWith(() => _FixedBookings(bookings)),
          unreadNotificationTargetsProvider.overrideWith(
            () => _FixedTargets(unreadTargets),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Both sources are fetched, so the count is only meaningful once they have arrived.
      await container.read(customerBookingsProvider.future);
      await container.read(unreadNotificationTargetsProvider.future);

      return container.read(customerBookingsNeedingMeCountProvider);
    }

    final waiting = order(
      status: 'Pending',
      agreementStatus: 'AwaitingCustomer',
    );

    test('an offer they have not opened counts', () async {
      expect(await countFor([waiting], {'booking:b-1'}), 1);
    });

    test('the same offer counts no more once they have opened it', () async {
      expect(await countFor([waiting], const {}), 0);
    });

    // The rating invitation points at the same order under its own target, and a job waiting to
    // be rated is exactly what this badge is for — so it has to count under either name.
    test('a job waiting to be rated counts under its own target', () async {
      expect(
        await countFor([order(status: 'Completed')], {'bookingrating:b-1'}),
        1,
      );
    });

    test(
      'an order with news on it that needs nothing still does not count',
      () async {
        expect(await countFor([order()], {'booking:b-1'}), 0);
      },
    );
  });
}

class _FixedBookings extends CustomerBookingsNotifier {
  _FixedBookings(this._bookings);

  final List<Booking> _bookings;

  @override
  Future<List<Booking>> build() async => _bookings;
}

class _FixedTargets extends UnreadNotificationTargets {
  _FixedTargets(this._targets);

  final Set<String> _targets;

  @override
  Future<Set<String>> build() async => _targets;
}
