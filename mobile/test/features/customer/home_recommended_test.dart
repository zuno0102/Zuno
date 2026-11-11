import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuno/core/location/location_service.dart';
import 'package:zuno/features/auth/domain/entities/user.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/auth/presentation/providers/auth_state.dart';
import 'package:zuno/features/catalog/domain/entities/district.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zuno/features/customer/data/datasources/customer_location_api.dart';
import 'package:zuno/features/customer/domain/entities/customer_location.dart';
import 'package:zuno/features/customer/domain/entities/home_sections.dart';
import 'package:zuno/features/customer/domain/entities/service_listing.dart';
import 'package:zuno/features/customer/presentation/providers/customer_search_filter_provider.dart';
import 'package:zuno/features/customer/presentation/providers/daily_banners_provider.dart';
import 'package:zuno/features/customer/presentation/providers/service_search_notifier.dart';
import 'package:zuno/features/customer/presentation/screens/customer_search_tab.dart';
import 'package:zuno/features/customer/presentation/widgets/customer_location_picker.dart';

/// The Service home with a location: "Recommended services near you" comes first, before the banner
/// and the categories. A search or category keeps the band and headings it always had.
ServiceListing _service(String id, String name) => ServiceListing(
  id: id,
  name: name,
  serviceCategoryName: 'Cleaning',
  serviceCategoryId: 'cat-clean',
  price: 1200,
  priceType: 'Fixed',
  businessOwnerProfileId: 'b-1',
  businessName: 'Shine Co',
);

class _Search extends ServiceSearchNotifier {
  @override
  Future<List<ServiceListing>> build() async {
    final filter = ref.watch(customerSearchFilterProvider);
    if (!filter.hasLocation && !filter.hasSearchTerms) return const [];
    return [
      _service('s-near', 'Deep clean near you'),
      _service('s-near2', 'Sofa wash near you'),
    ];
  }
}

class _SignedIn extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthAuthenticated(
    User(
      id: 'u1',
      firstName: 'Asha',
      lastName: 'K',
      role: 'Customer',
      emailConfirmed: true,
      phoneNumberConfirmed: true,
    ),
  );
}

class _Phone implements LocationService {
  _Phone(this.result);

  final LocationResult result;
  final asks = <bool>[];

  @override
  Future<LocationResult> current({
    bool precise = false,
    bool askPermission = true,
  }) async {
    asks.add(askPermission);
    return result;
  }

  @override
  Future<void> openSettings() async {}

  @override
  Future<void> openLocationSettings() async {}
}

class _Api extends CustomerLocationApi {
  _Api() : super(Dio());

  @override
  Future<District?> nearestDistrict(double latitude, double longitude) async =>
      const District(
        id: 'd-ekm',
        name: 'Ernakulam',
        stateId: 's-kl',
        stateName: 'Kerala',
      );

  @override
  Future<void> save(String? districtId, CustomerLocationSource source) async {}
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  LocationService? phone,
}) async {
  // Wide enough that the two-across cards have room for the test font, which is larger than any
  // real one; the layout itself is the same at every width.
  tester.view.physicalSize = const Size(560, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(_SignedIn.new),
        serviceSearchProvider.overrideWith(_Search.new),
        homeSectionsProvider.overrideWith(
          (ref) async =>
              HomeSections(mostBooked: [_service('s-any', 'Anywhere')]),
        ),
        dailyBannersProvider.overrideWith((ref) async => const []),
        serviceCategoriesProvider.overrideWith((ref) async => const []),
        if (phone != null) locationServiceProvider.overrideWithValue(phone),
        customerLocationApiProvider.overrideWithValue(_Api()),
      ],
      child: const MaterialApp(home: Scaffold(body: CustomerSearchTab())),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(CustomerSearchTab)),
  );
}

void _setErnakulam(ProviderContainer c) => c
    .read(customerSearchFilterProvider.notifier)
    .setDetectedLocation(
      const District(
        id: 'd-ekm',
        name: 'Ernakulam',
        stateId: 's-kl',
        stateName: 'Kerala',
      ),
    );

void main() {
  testWidgets('no location: no recommended section, home as before', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text(recommendedSectionTitle), findsNothing);
    expect(find.textContaining('Matching services'), findsNothing);
    expect(find.text('Booked most often'), findsOneWidget);
  });

  testWidgets('a location: "Recommended services near you" comes first', (
    tester,
  ) async {
    final c = await _pump(tester);
    _setErnakulam(c);
    await tester.pumpAndSettle();

    expect(find.text(recommendedSectionTitle), findsOneWidget);
    expect(find.text('Deep clean near you'), findsOneWidget);
    expect(find.text('Ernakulam'), findsWidgets, reason: 'under the greeting');

    // Above the categories and the rest of the home.
    final recommended = tester.getTopLeft(find.text(recommendedSectionTitle));
    final more = tester.getTopLeft(find.text('Booked most often'));
    expect(recommended.dy, lessThan(more.dy));

    expect(
      find.textContaining('Matching services'),
      findsNothing,
      reason: 'a location on its own is not a search',
    );
  });

  testWidgets('a search under a location keeps the existing heading', (
    tester,
  ) async {
    final c = await _pump(tester);
    _setErnakulam(c);
    c.read(customerSearchFilterProvider.notifier).setKeyword('sofa');
    await tester.pumpAndSettle();

    expect(find.text('Matching services near you'), findsOneWidget);
    expect(find.text(recommendedSectionTitle), findsNothing);
  });

  testWidgets('a search with no location: "Matching services"', (tester) async {
    final c = await _pump(tester);
    c.read(customerSearchFilterProvider.notifier).setKeyword('sofa');
    await tester.pumpAndSettle();

    expect(find.text('Matching services'), findsOneWidget);
    expect(find.text(recommendedSectionTitle), findsNothing);
  });

  testWidgets('clearing the search brings the recommended section back', (
    tester,
  ) async {
    final c = await _pump(tester);
    _setErnakulam(c);
    c.read(customerSearchFilterProvider.notifier).setKeyword('sofa');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text(recommendedSectionTitle), findsOneWidget);
    expect(
      c.read(customerSearchFilterProvider).districtIds,
      {'d-ekm'},
      reason: 'Clear never reaches the location',
    );
  });

  testWidgets(
    '"Use my current location" asks the phone and sets the district',
    (tester) async {
      final phone = _Phone(const LocationResult.found(10.0159, 76.3419));
      final c = await _pump(tester, phone: phone);

      await tester.tap(find.byType(CustomerLocationButton));
      await tester.pumpAndSettle();
      expect(
        find.text('Show everywhere'),
        findsNothing,
        reason: 'nothing to clear yet',
      );
      await tester.tap(find.byKey(const ValueKey('location-use-current')));
      await tester.pumpAndSettle();

      expect(phone.asks, [true], reason: 'tapped on purpose, so it may ask');
      expect(c.read(customerSearchFilterProvider).districtIds, {'d-ekm'});
      expect(
        c.read(customerSearchFilterProvider).locationSource,
        CustomerLocationSource.gps,
      );
      expect(find.text('Showing listings near Ernakulam.'), findsOneWidget);
      expect(find.text(recommendedSectionTitle), findsOneWidget);
    },
  );

  testWidgets('location refused: says so and changes nothing', (tester) async {
    final phone = _Phone(
      const LocationResult.unavailable(LocationProblem.deniedForever),
    );
    final c = await _pump(tester, phone: phone);

    await tester.tap(find.byType(CustomerLocationButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('location-use-current')));
    await tester.pumpAndSettle();

    expect(c.read(customerSearchFilterProvider).hasLocation, isFalse);
    expect(find.textContaining('Location is blocked for Zuno'), findsOneWidget);
  });

  testWidgets(
    '"Show everywhere" clears it, and remembers that it was cleared',
    (tester) async {
      final c = await _pump(tester);
      _setErnakulam(c);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CustomerLocationButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('location-everywhere')));
      await tester.pumpAndSettle();

      expect(c.read(customerSearchFilterProvider).hasLocation, isFalse);
      expect(
        c.read(customerSearchFilterProvider).locationSource,
        CustomerLocationSource.cleared,
      );
      expect(find.text(recommendedSectionTitle), findsNothing);
    },
  );

  // Location setup is required: the setup sheet has no way out but a location.
  group('required location setup', () {
    Future<(ProviderContainer, Future<void>)> openSetup(
      WidgetTester tester,
      LocationService phone,
    ) async {
      final c = await _pump(tester, phone: phone);
      final element = tester.element(find.byType(CustomerSearchTab));
      final done = requireCustomerLocation(element, element as WidgetRef);
      await tester.pumpAndSettle();
      return (c, done);
    }

    testWidgets('says why, and offers no "Not now" or "everywhere"', (
      tester,
    ) async {
      await openSetup(tester, _Phone(const LocationResult.found(10, 76)));

      expect(find.text('Find services near you'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('location-use-current')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('location-pick')), findsOneWidget);
      expect(find.text('Not now'), findsNothing);
      expect(find.byKey(const ValueKey('location-everywhere')), findsNothing);
    });

    testWidgets('tapping outside or pressing back does not close it', (
      tester,
    ) async {
      await openSetup(tester, _Phone(const LocationResult.found(10, 76)));

      await tester.tapAt(const Offset(280, 40));
      await tester.pumpAndSettle();
      expect(find.text('Find services near you'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Find services near you'), findsOneWidget);
    });

    testWidgets('"Use my current location" sets the district and it closes', (
      tester,
    ) async {
      final phone = _Phone(const LocationResult.found(10.0159, 76.3419));
      final (c, done) = await openSetup(tester, phone);

      await tester.tap(find.byKey(const ValueKey('location-use-current')));
      await tester.pumpAndSettle();
      await done;

      expect(phone.asks, [true]);
      expect(c.read(customerSearchFilterProvider).districtIds, {'d-ekm'});
      expect(find.text('Find services near you'), findsNothing);
      expect(find.text(recommendedSectionTitle), findsOneWidget);
    });

    testWidgets('blocked: says how to allow it, and the setup comes back', (
      tester,
    ) async {
      final phone = _Phone(
        const LocationResult.unavailable(LocationProblem.deniedForever),
      );
      final (c, _) = await openSetup(tester, phone);

      await tester.tap(find.byKey(const ValueKey('location-use-current')));
      await tester.pumpAndSettle();

      // Shown inside the setup sheet, not behind it.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('location-problem')),
          matching: find.textContaining('Location is blocked'),
        ),
        findsOneWidget,
      );
      expect(find.text('Find services near you'), findsOneWidget);
      expect(c.read(customerSearchFilterProvider).hasLocation, isFalse);
    });
  });

  testWidgets('the everyday chooser can be closed and has no setup text', (
    tester,
  ) async {
    await _pump(tester, phone: _Phone(const LocationResult.found(10, 76)));
    await tester.tap(find.byType(CustomerLocationButton));
    await tester.pumpAndSettle();

    expect(find.text('Where are you?'), findsOneWidget);
    expect(find.text('Find services near you'), findsNothing);

    await tester.tapAt(const Offset(280, 40));
    await tester.pumpAndSettle();
    expect(find.text('Where are you?'), findsNothing);
  });
}
