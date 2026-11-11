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
import 'package:zuno/features/catalog/domain/entities/location_state.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zuno/features/customer/data/datasources/customer_location_api.dart';
import 'package:zuno/features/customer/domain/entities/customer_location.dart';
import 'package:zuno/features/customer/domain/entities/home_sections.dart';
import 'package:zuno/features/customer/domain/entities/service_listing.dart';
import 'package:zuno/features/customer/presentation/providers/customer_home_location_provider.dart';
import 'package:zuno/features/customer/presentation/providers/customer_search_filter_provider.dart';
import 'package:zuno/features/customer/presentation/providers/daily_banners_provider.dart';
import 'package:zuno/features/customer/presentation/providers/service_search_notifier.dart';
import 'package:zuno/features/customer/presentation/screens/customer_search_tab.dart';
import 'package:zuno/features/customer/presentation/widgets/customer_location_picker.dart';

/// The Service home. The customer's own location (set up on first open, kept in the account) gives
/// "Recommended services near you" — below the categories, and only when something is listed there.
/// It is not a filter: the listings stay as they were. The pin button is the filter, kept apart.
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

const _ernakulam = District(
  id: 'd-ekm',
  name: 'Ernakulam',
  stateId: 's-kl',
  stateName: 'Kerala',
);
const _idukki = District(
  id: 'd-idk',
  name: 'Idukki',
  stateId: 's-kl',
  stateName: 'Kerala',
);

class _Search extends ServiceSearchNotifier {
  @override
  Future<List<ServiceListing>> build() async {
    final filter = ref.watch(customerSearchFilterProvider);
    if (!filter.isFiltering) return const [];
    return [_service('s-match', 'Sofa wash')];
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
  var settingsOpened = 0;

  @override
  Future<LocationResult> current({
    bool precise = false,
    bool askPermission = true,
  }) async {
    asks.add(askPermission);
    return result;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;

  @override
  Future<void> openLocationSettings() async => settingsOpened++;
}

class _Api extends CustomerLocationApi {
  _Api() : super(Dio());

  @override
  Future<District?> nearestDistrict(double latitude, double longitude) async =>
      _ernakulam;

  @override
  Future<void> save(String? districtId, CustomerLocationSource source) async {}
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  LocationService? phone,
}) async {
  // Wide enough that the two-across cards have room for the test font, which is larger than any
  // real one; the layout itself is the same at every width.
  tester.view.physicalSize = const Size(560, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(_SignedIn.new),
        serviceSearchProvider.overrideWith(_Search.new),
        // Ernakulam has two services listed; Idukki has none.
        recommendedServicesProvider.overrideWith((ref) async {
          final id = ref.watch(customerHomeLocationProvider).district?.id;
          return id == 'd-ekm'
              ? [
                  _service('s-near', 'Deep clean near you'),
                  _service('s-near2', 'Pipe fix near you'),
                ]
              : const <ServiceListing>[];
        }),
        homeSectionsProvider.overrideWith(
          (ref) async =>
              HomeSections(mostBooked: [_service('s-any', 'Anywhere')]),
        ),
        dailyBannersProvider.overrideWith((ref) async => const []),
        serviceCategoriesProvider.overrideWith((ref) async => const []),
        locationStatesProvider.overrideWith(
          (ref) async => const [LocationState(id: 's-kl', name: 'Kerala')],
        ),
        districtsForStatesProvider.overrideWith(
          (ref, csv) async => const [_ernakulam, _idukki],
        ),
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

Future<void> _setHome(
  WidgetTester tester,
  ProviderContainer c,
  District d,
) async {
  await c
      .read(customerHomeLocationProvider.notifier)
      .set(d, CustomerLocationSource.gps);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no location: no recommended section, home as before', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text(recommendedSectionTitle), findsNothing);
    expect(find.textContaining('Matching services'), findsNothing);
    expect(find.text('Booked most often'), findsOneWidget);
  });

  testWidgets(
    'their location has services: recommended, right below the categories',
    (tester) async {
      final c = await _pump(tester);
      await _setHome(tester, c, _ernakulam);

      expect(find.text(recommendedSectionTitle), findsOneWidget);
      expect(find.text('Deep clean near you'), findsOneWidget);
      expect(
        find.text('Ernakulam'),
        findsWidgets,
        reason: 'under the greeting',
      );

      final categories = tester.getTopLeft(find.text('What do you need?'));
      final recommended = tester.getTopLeft(find.text(recommendedSectionTitle));
      final more = tester.getTopLeft(find.text('Booked most often'));
      expect(recommended.dy, greaterThan(categories.dy));
      expect(recommended.dy, lessThan(more.dy));
    },
  );

  testWidgets('their location is not a filter: no filter, no matching band', (
    tester,
  ) async {
    final c = await _pump(tester);
    await _setHome(tester, c, _ernakulam);

    expect(c.read(customerSearchFilterProvider).hasLocation, isFalse);
    expect(find.textContaining('Matching services'), findsNothing);
    expect(find.text('Booked most often'), findsOneWidget);
  });

  testWidgets('nothing listed in their district: the page is as before', (
    tester,
  ) async {
    final c = await _pump(tester);
    await _setHome(tester, c, _idukki);

    expect(find.text(recommendedSectionTitle), findsNothing);
    expect(find.textContaining('Nothing is listed'), findsNothing);
    expect(find.text('Booked most often'), findsOneWidget);
  });

  testWidgets('a search hides the recommended strip and keeps its heading', (
    tester,
  ) async {
    final c = await _pump(tester);
    await _setHome(tester, c, _ernakulam);
    c.read(customerSearchFilterProvider.notifier).setKeyword('sofa');
    await tester.pumpAndSettle();

    expect(find.text('Matching services'), findsOneWidget);
    expect(find.text(recommendedSectionTitle), findsNothing);
  });

  testWidgets('Clear brings the recommended strip back; their location stays', (
    tester,
  ) async {
    final c = await _pump(tester);
    await _setHome(tester, c, _ernakulam);
    c.read(customerSearchFilterProvider.notifier).setKeyword('sofa');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text(recommendedSectionTitle), findsOneWidget);
    expect(c.read(customerHomeLocationProvider).district?.id, 'd-ekm');
  });

  group('the pin button is a search filter', () {
    testWidgets(
      '"Use my current location" filters, and is not their location',
      (tester) async {
        final phone = _Phone(const LocationResult.found(10.0159, 76.3419));
        final c = await _pump(tester, phone: phone);

        await tester.tap(find.byType(CustomerLocationButton));
        await tester.pumpAndSettle();
        expect(find.text('Show everywhere'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('location-use-current')));
        await tester.pumpAndSettle();

        expect(phone.asks, [true]);
        expect(c.read(customerSearchFilterProvider).districtIds, {'d-ekm'});
        expect(c.read(customerHomeLocationProvider).isSet, isFalse);
        expect(find.text('Services near you'), findsOneWidget);
      },
    );

    testWidgets('location refused: says so and changes nothing', (
      tester,
    ) async {
      final phone = _Phone(
        const LocationResult.unavailable(LocationProblem.deniedForever),
      );
      final c = await _pump(tester, phone: phone);

      await tester.tap(find.byType(CustomerLocationButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('location-use-current')));
      await tester.pumpAndSettle();

      expect(c.read(customerSearchFilterProvider).hasLocation, isFalse);
      expect(find.textContaining('Location is blocked'), findsOneWidget);
    });

    testWidgets('"Show everywhere" clears the filter', (tester) async {
      final c = await _pump(tester);
      c
          .read(customerSearchFilterProvider.notifier)
          .setDetectedLocation(_ernakulam);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CustomerLocationButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('location-everywhere')));
      await tester.pumpAndSettle();

      expect(c.read(customerSearchFilterProvider).hasLocation, isFalse);
    });

    testWidgets('the filter chooser can be closed', (tester) async {
      await _pump(tester, phone: _Phone(const LocationResult.found(10, 76)));
      await tester.tap(find.byType(CustomerLocationButton));
      await tester.pumpAndSettle();

      expect(find.text('Search where?'), findsOneWidget);
      await tester.tapAt(const Offset(280, 40));
      await tester.pumpAndSettle();
      expect(find.text('Search where?'), findsNothing);
    });
  });

  // Setting a location is required: the setup sheet has no way out but a location.
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

    testWidgets('says why, with "Turn on location" and no way to skip', (
      tester,
    ) async {
      await openSetup(tester, _Phone(const LocationResult.found(10, 76)));

      expect(find.text('Find services near you'), findsOneWidget);
      expect(find.byKey(const ValueKey('location-turn-on')), findsOneWidget);
      expect(find.text('Turn on location'), findsOneWidget);
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

    testWidgets(
      '"Turn on location" saves their location — not a filter — and closes',
      (tester) async {
        final phone = _Phone(const LocationResult.found(10.0159, 76.3419));
        final (c, done) = await openSetup(tester, phone);

        await tester.tap(find.byKey(const ValueKey('location-turn-on')));
        await tester.pumpAndSettle();
        await done;

        expect(phone.asks, [true]);
        expect(c.read(customerHomeLocationProvider).district?.id, 'd-ekm');
        expect(c.read(customerSearchFilterProvider).hasLocation, isFalse);
        expect(find.text('Find services near you'), findsNothing);
        expect(find.text(recommendedSectionTitle), findsOneWidget);
      },
    );

    testWidgets(
      'blocked: says how to allow it, inside the setup, which stays',
      (tester) async {
        final phone = _Phone(
          const LocationResult.unavailable(LocationProblem.deniedForever),
        );
        final (c, _) = await openSetup(tester, phone);

        await tester.tap(find.byKey(const ValueKey('location-turn-on')));
        await tester.pumpAndSettle();

        expect(phone.settingsOpened, 1, reason: 'a phone opens its settings');
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('location-problem')),
            matching: find.textContaining('Allow location for Zuno'),
          ),
          findsOneWidget,
        );
        expect(find.text('Find services near you'), findsOneWidget);
        expect(c.read(customerHomeLocationProvider).isSet, isFalse);
      },
    );

    testWidgets('location off on the phone: opens the location switch', (
      tester,
    ) async {
      final phone = _Phone(
        const LocationResult.unavailable(LocationProblem.serviceDisabled),
      );
      await openSetup(tester, phone);

      await tester.tap(find.byKey(const ValueKey('location-turn-on')));
      await tester.pumpAndSettle();

      expect(phone.settingsOpened, 1);
      expect(find.textContaining('Turn on location, then'), findsOneWidget);
    });

    testWidgets('"Choose state and district" sets one district and closes', (
      tester,
    ) async {
      final (c, done) = await openSetup(
        tester,
        _Phone(const LocationResult.found(10, 76)),
      );

      await tester.tap(find.byKey(const ValueKey('location-pick')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kerala'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Idukki'));
      await tester.pumpAndSettle();
      await done;

      final home = c.read(customerHomeLocationProvider);
      expect(home.district?.id, 'd-idk');
      expect(home.source, CustomerLocationSource.manual);
      expect(c.read(customerSearchFilterProvider).hasLocation, isFalse);
      expect(find.text('Find services near you'), findsNothing);
    });
  });
}
