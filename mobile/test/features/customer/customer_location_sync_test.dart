import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuno/core/location/location_service.dart';
import 'package:zuno/features/auth/domain/entities/user.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/auth/presentation/providers/auth_state.dart';
import 'package:zuno/features/catalog/domain/entities/district.dart';
import 'package:zuno/features/customer/data/datasources/customer_location_api.dart';
import 'package:zuno/features/customer/domain/entities/customer_location.dart';
import 'package:zuno/features/customer/presentation/providers/customer_home_location_provider.dart';
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

/// A signed-in customer who can be swapped for another, as signing out and in does.
class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async => _as('u1');

  void signInAs(String id) => state = AsyncData(_as(id));

  static AuthState _as(String id) => AuthAuthenticated(
    User(
      id: id,
      firstName: 'Asha',
      lastName: 'K',
      role: 'Customer',
      emailConfirmed: true,
      phoneNumberConfirmed: true,
    ),
  );
}

Future<ProviderContainer> _open({
  required _Phone phone,
  required _Api api,
  Map<String, Object> saved = const {},
}) async {
  SharedPreferences.setMockInitialValues(saved);
  final container = ProviderContainer(
    overrides: [
      authProvider.overrideWith(_Auth.new),
      locationServiceProvider.overrideWithValue(phone),
      customerLocationApiProvider.overrideWithValue(api),
    ],
  );
  addTearDown(container.dispose);
  await container.read(authProvider.future);
  await container.read(customerLocationSyncProvider.future);
  return container;
}

CustomerSearchFilter _filter(ProviderContainer c) =>
    c.read(customerSearchFilterProvider);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

CustomerHomeLocation _home(ProviderContainer c) =>
    c.read(customerHomeLocationProvider);

const _homeEkm = {
  'customer_home_district_id': 'd-ekm',
  'customer_home_district_name': 'Ernakulam',
  'customer_home_state_id': 's-kl',
  'customer_home_state_name': 'Kerala',
};

void main() {
  test(
    'first open: asks for permission, sets their location, saves it to the account',
    () async {
      final phone = _Phone();
      final api = _Api();
      final c = await _open(phone: phone, api: api);
      await _settle();

      expect(phone.asks, [true]);
      expect(_home(c).district?.id, 'd-ekm');
      expect(_home(c).source, CustomerLocationSource.gps);
      expect(api.saves, ['d-ekm:Gps']);
    },
  );

  // The report: the location set up on first open must not become a search filter.
  test('the search filter is left alone: listings stay unfiltered', () async {
    final c = await _open(phone: _Phone(), api: _Api());
    await _settle();

    expect(_filter(c).hasLocation, isFalse);
    expect(_filter(c).isFiltering, isFalse);
  });

  test('later opens read the phone quietly, without asking again', () async {
    final phone = _Phone();
    final api = _Api(nearest: _thrissur);
    final c = await _open(
      phone: phone,
      api: api,
      saved: {
        customerLocationAskedKey('u1'): true,
        customerLocationOwnerKey: 'u1',
        ..._homeEkm,
        'customer_home_location_source': 'Gps',
      },
    );
    await _settle();

    expect(phone.asks, [false], reason: 'never asked twice');
    expect(_home(c).district?.id, 'd-tsr', reason: 'they moved');
    expect(api.saves, ['d-tsr:Gps']);
  });

  test('a district picked by hand is never replaced by the phone', () async {
    final phone = _Phone();
    final c = await _open(
      phone: phone,
      api: _Api(nearest: _thrissur),
      saved: {
        customerLocationOwnerKey: 'u1',
        ..._homeEkm,
        'customer_home_location_source': 'Manual',
      },
    );
    await _settle();

    expect(phone.asks, isEmpty);
    expect(_home(c).district?.id, 'd-ekm');
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

    expect(_home(c).district?.id, 'd-tsr');
    expect(phone.asks, isEmpty, reason: 'picked by hand: the phone stays out');
    expect(api.saves, isEmpty, reason: 'not written back what was just read');
  });

  test(
    'phone B with an older location of its own takes the one set on phone A',
    () async {
      final phone = _Phone(); // Phone B stands in Ernakulam.
      final api = _Api(
        account: const SavedCustomerLocation(
          district: _thrissur,
          source: CustomerLocationSource.manual,
        ),
      );
      final c = await _open(
        phone: phone,
        api: api,
        saved: {
          customerLocationOwnerKey: 'u1',
          ..._homeEkm,
          'customer_home_location_source': 'Manual',
        },
      );
      await _settle();

      expect(_home(c).district?.id, 'd-tsr');
      expect(_home(c).source, CustomerLocationSource.manual);
      expect(
        phone.asks,
        isEmpty,
        reason: 'picked by hand on A: the phone stays out',
      );
      expect(api.saves, isEmpty, reason: 'not written back what was just read');
    },
  );

  test(
    'a location only this device has is saved to an account without one',
    () async {
      final api = _Api();
      final c = await _open(
        phone: _Phone(),
        api: api,
        saved: {
          customerLocationOwnerKey: 'u1',
          ..._homeEkm,
          'customer_home_location_source': 'Manual',
        },
      );
      await _settle();

      expect(_home(c).district?.id, 'd-ekm');
      expect(api.saves, ['d-ekm:Manual'], reason: 'so phone B finds it');
    },
  );

  test(
    'an account cleared to everywhere takes this device\'s location',
    () async {
      final api = _Api(
        account: const SavedCustomerLocation(
          source: CustomerLocationSource.cleared,
        ),
      );
      final c = await _open(
        phone: _Phone(),
        api: api,
        saved: {
          customerLocationOwnerKey: 'u1',
          ..._homeEkm,
          'customer_home_location_source': 'Manual',
        },
      );
      await _settle();

      expect(_home(c).district?.id, 'd-ekm');
      expect(api.saves, ['d-ekm:Manual']);
    },
  );

  test(
    'a phone location the account lacks is saved once, even when unchanged',
    () async {
      final api = _Api(); // The phone still reads Ernakulam.
      final c = await _open(
        phone: _Phone(),
        api: api,
        saved: {
          customerLocationAskedKey('u1'): true,
          customerLocationOwnerKey: 'u1',
          ..._homeEkm,
          'customer_home_location_source': 'Gps',
        },
      );
      await _settle();

      expect(_home(c).district?.id, 'd-ekm');
      expect(api.saves, ['d-ekm:Gps']);
    },
  );

  test('the account and the device agree: nothing is saved', () async {
    final api = _Api(
      account: const SavedCustomerLocation(
        district: _ernakulam,
        source: CustomerLocationSource.manual,
      ),
    );
    final c = await _open(
      phone: _Phone(),
      api: api,
      saved: {
        customerLocationOwnerKey: 'u1',
        ..._homeEkm,
        'customer_home_location_source': 'Manual',
      },
    );
    await _settle();

    expect(_home(c).district?.id, 'd-ekm');
    expect(api.saves, isEmpty);
  });

  test(
    'offline: the device keeps its own location and saves nothing',
    () async {
      final api = _Api()..offline = true;
      final c = await _open(
        phone: _Phone(),
        api: api,
        saved: {
          customerLocationOwnerKey: 'u1',
          ..._homeEkm,
          'customer_home_location_source': 'Manual',
        },
      );
      await _settle();

      expect(_home(c).district?.id, 'd-ekm');
      expect(api.saves, isEmpty);
    },
  );

  test('an older account cleared to everywhere is set up again', () async {
    final phone = _Phone();
    final c = await _open(
      phone: phone,
      api: _Api(
        account: const SavedCustomerLocation(
          source: CustomerLocationSource.cleared,
        ),
      ),
    );
    await _settle();

    expect(phone.asks, [true]);
    expect(_home(c).district?.id, 'd-ekm');
  });

  test('outside every served district: nothing set', () async {
    final c = await _open(phone: _Phone(), api: _Api(nearest: null));
    expect(_home(c).isSet, isFalse);
  });

  test('offline: nothing set and nothing fails', () async {
    final c = await _open(phone: _Phone(), api: _Api()..offline = true);
    expect(_home(c).isSet, isFalse);
  });

  test(
    'a district filter on the pin button is not saved to the account',
    () async {
      final api = _Api();
      final c = await _open(phone: _Phone(), api: api);
      await _settle();
      api.saves.clear();

      c
          .read(customerSearchFilterProvider.notifier)
          .setLocation(
            stateIds: {'s-kl'},
            districtIds: {'d-tsr'},
            primaryDistrictName: 'Thrissur',
          );
      await _settle();

      expect(api.saves, isEmpty);
      expect(_home(c).district?.id, 'd-ekm');
    },
  );

  test('changing their location afterwards is saved to the account', () async {
    final api = _Api();
    final c = await _open(phone: _Phone(), api: api);
    await _settle();
    api.saves.clear();

    await c
        .read(customerHomeLocationProvider.notifier)
        .set(_thrissur, CustomerLocationSource.manual);
    await _settle();

    expect(api.saves, ['d-tsr:Manual']);
  });

  test(
    'a filter the phone set in an older version is not brought back',
    () async {
      final c = await _open(
        phone: _Phone(),
        api: _Api(),
        saved: {
          customerLocationOwnerKey: 'u1',
          'customer_filter_district_ids': ['d-ekm'],
          'customer_filter_primary_district': 'Ernakulam',
          'customer_filter_location_source': 'Gps',
        },
      );
      await _settle();

      expect(_filter(c).hasLocation, isFalse);
    },
  );

  test('a filter picked by hand stays, apart from their location', () async {
    final c = await _open(
      phone: _Phone(),
      api: _Api(),
      saved: {
        customerLocationOwnerKey: 'u1',
        'customer_filter_district_ids': ['d-tsr'],
        'customer_filter_primary_district': 'Thrissur',
        'customer_filter_location_source': 'Manual',
      },
    );
    await _settle();

    expect(_filter(c).districtIds, {'d-tsr'});
    expect(_home(c).district?.id, 'd-ekm');
  });

  test('a second customer on the same device starts fresh', () async {
    final phone = _Phone();
    final api = _Api(nearest: _thrissur);
    final c = await _open(
      phone: phone,
      api: api,
      saved: {
        customerLocationAskedKey('u-first'): true,
        customerLocationOwnerKey: 'u-first',
        ..._homeEkm,
        'customer_home_location_source': 'Manual',
        'customer_filter_district_ids': ['d-ekm'],
        'customer_filter_location_source': 'Manual',
      },
    );
    await _settle();

    expect(phone.asks, [
      true,
    ], reason: 'a customer never asked before is asked');
    expect(_home(c).district?.id, 'd-tsr', reason: 'not the last person\'s');
    expect(_filter(c).hasLocation, isFalse, reason: 'nor their filter');
    expect(api.saves, ['d-tsr:Gps']);
  });

  test('signing out and in as someone else runs it again for them', () async {
    final phone = _Phone();
    final c = await _open(phone: phone, api: _Api());
    await _settle();
    expect(phone.asks, [true]);

    (c.read(authProvider.notifier) as _Auth).signInAs('u2');
    await c.read(customerLocationSyncProvider.future);
    await _settle();

    expect(phone.asks, [true, true]);
    expect(_home(c).district?.id, 'd-ekm');
  });

  test('the same customer coming back is not asked again', () async {
    final phone = _Phone();
    final c = await _open(phone: phone, api: _Api());
    await _settle();

    (c.read(authProvider.notifier) as _Auth).signInAs('u1');
    await c.read(customerLocationSyncProvider.future);
    await _settle();

    expect(phone.asks, [true]);
  });

  // The web report: a browser that remembers "Block" answers without asking, so the app asks
  // itself — and setting a location is required.
  group('what the open tells the app', () {
    Future<CustomerLocationOpen> openWith(
      _Phone phone, {
      _Api? api,
      Map<String, Object> saved = const {},
    }) async {
      final c = await _open(phone: phone, api: api ?? _Api(), saved: saved);
      return c.read(customerLocationSyncProvider.future);
    }

    test('location found: nothing more to ask', () async {
      expect(await openWith(_Phone()), CustomerLocationOpen.settled);
    });

    test('blocked: the app asks itself', () async {
      final phone = _Phone(
        const LocationResult.unavailable(LocationProblem.deniedForever),
      );
      expect(await openWith(phone), CustomerLocationOpen.needsChoice);
    });

    test('outside the area: the app asks itself', () async {
      expect(
        await openWith(_Phone(), api: _Api(nearest: null)),
        CustomerLocationOpen.needsChoice,
      );
    });

    test('still no location on a later open: asked again', () async {
      final phone = _Phone(
        const LocationResult.unavailable(LocationProblem.denied),
      );
      final result = await openWith(
        phone,
        saved: {
          customerLocationAskedKey('u1'): true,
          customerLocationOwnerKey: 'u1',
        },
      );
      expect(result, CustomerLocationOpen.needsChoice);
      expect(phone.asks, [false], reason: 'the system dialog only once');
    });

    test('a location in the account: nothing to ask', () async {
      final phone = _Phone(
        const LocationResult.unavailable(LocationProblem.deniedForever),
      );
      final result = await openWith(
        phone,
        api: _Api(
          account: const SavedCustomerLocation(
            district: _ernakulam,
            source: CustomerLocationSource.gps,
          ),
        ),
      );
      expect(result, CustomerLocationOpen.settled);
    });

    test('a district picked by hand: nothing to ask', () async {
      final result = await openWith(
        _Phone(),
        saved: {
          customerLocationOwnerKey: 'u1',
          ..._homeEkm,
          'customer_home_location_source': 'Manual',
        },
      );
      expect(result, CustomerLocationOpen.settled);
    });
  });
}
