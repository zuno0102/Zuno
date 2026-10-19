import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/domain/repositories/booking_repository.dart';
import 'package:zuno/features/booking/presentation/providers/booking_providers.dart';
import 'package:zuno/features/booking/presentation/providers/customer_bookings_notifier.dart';

/// Placing an order must not fail because nobody was watching the order list.
///
/// The bug: this notifier is auto-disposed, and Book service is opened from search — a screen that
/// never watches the customer's bookings. Reading the notifier to place an order therefore created it
/// with no listener, Riverpod disposed it while the POST was still in flight, and the refresh
/// afterwards threw "Cannot use the Ref of customerBookingsProvider after it has been disposed".
///
/// The customer saw that in red on the booking form — for an order the server had already accepted.
/// Confirmed in the database: the booking existed, timestamped to the second the error appeared. The
/// obvious response to an error is to try again, so this bug was one tap away from duplicate orders.
class _FakeBookingRepository implements BookingRepository {
  _FakeBookingRepository({Completer<void>? createGate}) : _createGate = createGate;

  /// Lets a test hold the create call open, the way a slow network does.
  final Completer<void>? _createGate;

  int createCalls = 0;
  int listCalls = 0;

  @override
  Future<Booking> createBooking({
    required String businessServiceId,
    String? businessServiceVariantId,
    required DateTime scheduledDate,
    String? notes,
    required String addressLine1,
    String? addressLine2,
    required String city,
    required String state,
    required String postalCode,
    String? country,
    required double latitude,
    required double longitude,
    Map<String, String> answers = const {},
  }) async {
    createCalls++;
    await _createGate?.future;
    return _booking;
  }

  @override
  Future<List<Booking>> getMyBookingsAsCustomer() async {
    listCalls++;
    return [_booking];
  }

  static final _booking = Booking(
    id: 'b-1',
    businessOwnerProfileId: 'bo-1',
    businessName: 'bahhs',
    customerProfileId: 'c-1',
    customerName: 'Zuno Customer',
    businessServiceId: 's-1',
    serviceName: 'Catering',
    serviceCategoryName: 'Events',
    status: 'Pending',
    scheduledDate: DateTime(2026, 10, 7, 23, 2),
    priceQuoted: 250,
  );

  // Everything else on the interface is irrelevant here and must never be called.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  Future<void> place(CustomerBookingsNotifier notifier) => notifier.createBooking(
    businessServiceId: 's-1',
    scheduledDate: DateTime(2026, 10, 7, 23, 2),
    addressLine1: '12 Main Road',
    city: 'Thiruvananthapuram',
    state: 'Kerala',
    postalCode: '695001',
    latitude: 8.5241,
    longitude: 76.9366,
  );

  test('placing an order refreshes the list while the screen is still there', () async {
    final repository = _FakeBookingRepository();
    final container = ProviderContainer(
      overrides: [bookingRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    // A listener, standing in for the bookings tab being on screen.
    container.listen(customerBookingsProvider, (_, _) {});

    await place(container.read(customerBookingsProvider.notifier));

    expect(repository.createCalls, 1);
    expect(container.read(customerBookingsProvider).value, isNotNull);
  });

  test('and still succeeds when the provider dies mid-request', () async {
    // The reported crash, reproduced: nothing holds the provider open, and it goes away while the
    // server is still thinking.
    final gate = Completer<void>();
    final repository = _FakeBookingRepository(createGate: gate);
    final container = ProviderContainer(
      overrides: [bookingRepositoryProvider.overrideWithValue(repository)],
    );

    final pending = place(container.read(customerBookingsProvider.notifier));

    // Whatever the initial build fetched. The refresh must not add to it.
    final fetchesBeforeDisposal = repository.listCalls;

    // Disposed with the order in flight.
    container.dispose();
    gate.complete();

    // The caller sees the order placed, not an error about a disposed Ref.
    await expectLater(pending, completes);
    expect(repository.createCalls, 1);
    expect(
      repository.listCalls,
      fetchesBeforeDisposal,
      reason: 'nothing to refresh once the provider is gone, and asking would throw',
    );
  });

  test('a failure from the server still reaches the caller', () async {
    // The guard must not swallow real errors — a booking the server refused has to say so.
    final container = ProviderContainer(
      overrides: [
        bookingRepositoryProvider.overrideWithValue(_RefusingRepository()),
      ],
    );
    addTearDown(container.dispose);
    container.listen(customerBookingsProvider, (_, _) {});

    await expectLater(
      place(container.read(customerBookingsProvider.notifier)),
      throwsA(isA<Exception>()),
    );
  });
}

class _RefusingRepository extends _FakeBookingRepository {
  @override
  Future<Booking> createBooking({
    required String businessServiceId,
    String? businessServiceVariantId,
    required DateTime scheduledDate,
    String? notes,
    required String addressLine1,
    String? addressLine2,
    required String city,
    required String state,
    required String postalCode,
    String? country,
    required double latitude,
    required double longitude,
    Map<String, String> answers = const {},
  }) async => throw Exception('That date is already taken.');
}
