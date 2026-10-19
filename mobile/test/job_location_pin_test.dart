import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/domain/repositories/booking_repository.dart';
import 'package:zuno/features/booking/presentation/providers/booking_providers.dart';
import 'package:zuno/features/customer/domain/entities/customer_service.dart';
import 'package:zuno/features/customer/presentation/screens/create_booking_screen.dart';
import 'package:zuno/shared/widgets/job_location_card.dart';
import 'package:zuno/shared/widgets/location_pin_picker.dart';
import 'package:zuno/shared/widgets/primary_button.dart';

/// The job location is pinned on a map, not only typed — and whoever has to get there sees the pin.
class _CountingBookingRepository implements BookingRepository {
  int createCalls = 0;

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
    throw UnimplementedError();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<void> _pumpCard(WidgetTester tester, JobLocationCard card) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: card))));
  // Pumped by hand: the map asks for tiles, which never arrive in a test.
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('JobLocationCard', () {
    testWidgets('a pinned job offers directions to the pin', (tester) async {
      await _pumpCard(
        tester,
        const JobLocationCard(
          latitude: 8.3123,
          longitude: 77.2201,
          caption: 'Exact location from the customer',
          addressLines: ['12, Church Street', null, 'Marthandam', 'Tamil Nadu', '629165'],
        ),
      );

      expect(find.text('Exact location from the customer'), findsOneWidget);
      expect(find.text('Directions'), findsOneWidget);
      expect(find.text('Copy address'), findsOneWidget);
      // Blank parts are skipped rather than leaving ", ," in the address.
      expect(find.text('12, Church Street, Marthandam, Tamil Nadu, 629165'), findsOneWidget);
    });

    testWidgets('an order from before pinning falls back to searching the address', (tester) async {
      await _pumpCard(
        tester,
        const JobLocationCard(addressLines: ['14 Nila Nagar', 'Thrissur', 'Kerala']),
      );

      expect(find.text('Search in Maps'), findsOneWidget);
      expect(find.text('Directions'), findsNothing);
      expect(find.textContaining('No map pin'), findsOneWidget);
    });

    testWidgets('a read-only preview has no buttons', (tester) async {
      await _pumpCard(
        tester,
        const JobLocationCard(
          latitude: 8.3,
          longitude: 77.2,
          addressLines: ['x'],
          showActions: false,
        ),
      );

      expect(find.text('Directions'), findsNothing);
      expect(find.text('Copy address'), findsNothing);
    });
  });

  group('PickedLocation.summary', () {
    test('reads street, area, town', () {
      const picked = PickedLocation(
        latitude: 8.3,
        longitude: 77.2,
        street: 'Church Street',
        locality: 'Nila Nagar',
        city: 'Marthandam',
      );
      expect(picked.summary, 'Church Street, Nila Nagar, Marthandam');
    });

    test('falls back to coordinates when the map could not name the spot', () {
      const picked = PickedLocation(latitude: 8.312345, longitude: 77.220111);
      expect(picked.summary, '8.31235, 77.22011');
    });
  });

  testWidgets('a booking cannot be sent without a map pin', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final repository = _CountingBookingRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [bookingRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: CreateBookingScreen(
            businessName: 'Shajil Caterers',
            service: CustomerService(
              id: 's-1',
              serviceCategoryName: 'Catering',
              name: 'Wedding catering',
              priceType: 'Fixed',
              price: 25000,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('bookingPickPin')), findsOneWidget);
    expect(find.text('Pin the job location on the map'), findsOneWidget);

    final confirm = find.byType(PrimaryButton);
    await tester.ensureVisible(confirm);
    await tester.pump();
    await tester.tap(confirm);
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('bookingPickPin')));
    await tester.pump();

    expect(find.text('Pin the job location on the map before booking.'), findsOneWidget);
    expect(find.textContaining('the worker uses this pin'), findsOneWidget);
    expect(repository.createCalls, 0);
  });
}
