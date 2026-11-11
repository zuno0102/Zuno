import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuno/core/location/location_service.dart';
import 'package:zuno/features/catalog/domain/entities/district.dart';
import 'package:zuno/features/customer/data/datasources/customer_location_api.dart';
import 'package:zuno/features/customer/domain/entities/customer_location.dart';
import 'package:zuno/features/customer/presentation/providers/customer_location_sync.dart';
import 'package:zuno/features/customer/presentation/providers/customer_search_filter_provider.dart';

/// Every time the customer app opens: the account's location for a new phone, then the phone's own
/// position (asking permission once), unless the customer picked or cleared a location themselves —
/// and every change is saved back to the account.
const _ernakulam = District(
  id: 'd-ekm',
  name: 'Ernakulam',
  stateId: 's-kl',
  stateName: 'Kerala',
);
const _thrissur = District(
  id: 'd-tsr',
  name: 'Thrissur',
  stateId: 's-kl',
  stateName: 'Kerala',
);

class _Phone implements LocationService {
  _Phone([this.result = const LocationResult.found(10.0159, 76.3419)]);

  LocationResult result;
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
  _Api({
    this.account = const SavedCustomerLocation(),
    this.nearest = _ernakulam,
  }) : super(Dio());

  SavedCustomerLocation account;
  District? nearest;
  bool offline = false;
  final saves = <String>[];

  @override
  Future<District?> nearestDistrict(double latitude, double longitude) async {
    if (offline) throw Exception('offline');
    return nearest;
  }

  @override
  Future<SavedCustomerLocation> myLocation() async {
    if (offline) throw Exception('offline');
    return account;
  }

  @override
  Future<void> save(String? districtId, CustomerLocationSource source) async {
    saves.add('$districtId:${source.code}');
  }
}

Future<ProviderContainer> _open({
  required _Phone phone,
  required _Api api,
  Map<String, Object> saved = const {},
}) async {
  SharedPreferences.setMockInitialValues(saved);
  final container = ProviderContainer(
    overrides: [
      locationServiceProvider.overrideWithValue(phone),
      customerLocationApiProvider.overrideWithValue(api),
    ],
  );
  addTearDown(container.dispose);
  await container.read(customerLocationSyncProvider.future);
  return container;
}

CustomerSearchFilter _filter(ProviderContainer c) =>
    c.read(customerSearchFilterProvider);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'first open: asks for permission, sets the district, saves it to the account',
    () async {
      final phone = _Phone();
      final api = _Api();

      final c = await _open(phone: phone, api: api);
      await _settle();

      expect(phone.asks, [true], reason: 'asked the first time');
      expect(_filter(c).districtIds, {'d-ekm'});
      expect(_filter(c).primaryDistrictName, 'Ernakulam');
      expect(_filter(c).locationSource, CustomerLocationSource.gps);
      expect(api.saves, ['d-ekm:Gps']);
    },
  );

  test('later opens read the phone quietly, without asking again', () async {
    final phone = _Phone();
    final api = _Api(nearest: _thrissur);

    final c = await _open(
      phone: phone,
      api: api,
      saved: {
        customerLocationAskedKey: true,
        'customer_filter_district_ids': ['d-ekm'],
        'customer_filter_state_ids': ['s-kl'],
        'customer_filter_primary_district': 'Ernakulam',
        'customer_filter_location_source': 'Gps',
      },
    );
    await _settle();

    expect(phone.asks, [false], reason: 'never asked twice');
    expect(_filter(c).districtIds, {'d-tsr'}, reason: 'they moved');
    expect(api.saves, ['d-tsr:Gps']);
  });

  test('a district picked by hand is never replaced by the phone', () async {
    final phone = _Phone();
    final api = _Api(nearest: _thrissur);

    final c = await _open(
      phone: phone,
      api: api,
      saved: {
        'customer_filter_district_ids': ['d-ekm'],
        'customer_filter_primary_district': 'Ernakulam',
        'customer_filter_location_source': 'Manual',
      },
    );

    expect(phone.asks, isEmpty);
    expect(_filter(c).districtIds, {'d-ekm'});
    expect(api.saves, isEmpty);
  });

  test(
    'a district saved before this version counts as picked by hand',
    () async {
      final phone = _Phone();
      final c = await _open(
        phone: phone,
        api: _Api(nearest: _thrissur),
        saved: {
          'customer_filter_district_ids': ['d-ekm'],
          'customer_filter_primary_district': 'Ernakulam',
        },
      );

      expect(phone.asks, isEmpty);
      expect(_filter(c).districtIds, {'d-ekm'});
    },
  );

  test('cleared to everywhere on purpose stays everywhere', () async {
    final phone = _Phone();
    final c = await _open(
      phone: phone,
      api: _Api(),
      saved: {'customer_filter_location_source': 'Cleared'},
    );

    expect(phone.asks, isEmpty);
    expect(_filter(c).hasLocation, isFalse);
  });

  test('a new phone takes the location kept in the account', () async {
    final phone = _Phone();
    final api = _Api(
      account: const SavedCustomerLocation(
        district: _thrissur,
        source: CustomerLocationSource.manual,
      ),
    );

    final c = await _open(phone: phone, api: api);
    await _settle();

    expect(_filter(c).districtIds, {'d-tsr'});
    expect(_filter(c).locationSource, CustomerLocationSource.manual);
    expect(phone.asks, isEmpty, reason: 'picked by hand in the account');
    expect(
      api.saves,
      isEmpty,
      reason: 'what came from the account is not sent back',
    );
  });

  test('a new phone whose account was cleared stays everywhere', () async {
    final phone = _Phone();
    final c = await _open(
      phone: phone,
      api: _Api(
        account: const SavedCustomerLocation(
          source: CustomerLocationSource.cleared,
        ),
      ),
    );

    expect(_filter(c).hasLocation, isFalse);
    expect(phone.asks, isEmpty);
  });

  test(
    'permission refused: nothing changes, and the screen is not broken',
    () async {
      final phone = _Phone(
        const LocationResult.unavailable(LocationProblem.denied),
      );
      final api = _Api();

      final c = await _open(phone: phone, api: api);

      expect(_filter(c).hasLocation, isFalse);
      expect(api.saves, isEmpty);
    },
  );

  test('outside every served district: nothing changes', () async {
    final api = _Api()..nearest = null;
    final c = await _open(phone: _Phone(), api: api);

    expect(_filter(c).hasLocation, isFalse);
    expect(api.saves, isEmpty);
  });

  test('offline: nothing changes and nothing fails', () async {
    final api = _Api()..offline = true;
    final c = await _open(phone: _Phone(), api: api);

    expect(_filter(c).hasLocation, isFalse);
  });

  test('picking or clearing afterwards is saved to the account', () async {
    final api = _Api();
    final c = await _open(phone: _Phone(), api: api);
    await _settle();
    final filter = c.read(customerSearchFilterProvider.notifier);

    filter.setLocation(
      stateIds: {'s-kl'},
      districtIds: {'d-tsr'},
      primaryDistrictName: 'Thrissur',
    );
    await _settle();
    filter.clearLocation();
    await _settle();

    expect(api.saves, ['d-ekm:Gps', 'd-tsr:Manual', 'null:Cleared']);
  });

  test('a search does not touch the account', () async {
    final api = _Api();
    final c = await _open(phone: _Phone(), api: api);
    await _settle();

    c.read(customerSearchFilterProvider.notifier)
      ..setKeyword('tent')
      ..clearSearch();
    await _settle();

    expect(api.saves, ['d-ekm:Gps']);
    expect(_filter(c).locationSource, CustomerLocationSource.gps);
  });
}
