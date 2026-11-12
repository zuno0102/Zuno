import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/error/app_exceptions.dart';
import 'package:zuno/features/business_owner/domain/entities/business_profile.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_profile_notifier.dart';
import 'package:zuno/features/catalog/domain/entities/district.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zuno/features/customer/data/datasources/customer_location_api.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:zuno/features/worker/presentation/widgets/place_search_sheet.dart';

const _kanyakumari = District(
  id: 'd-kk',
  name: 'Kanyakumari',
  stateId: 's-tn',
  stateName: 'Tamil Nadu',
);
const _thiruvananthapuram = District(
  id: 'd-tvm',
  name: 'Thiruvananthapuram',
  stateId: 's-kl',
  stateName: 'Kerala',
);

/// Marthandam, as the map search finds it.
const _marthandam = SearchedPlace(
  name: 'Marthandam',
  fullName: 'Marthandam, Kanyakumari, Tamil Nadu',
  latitude: 8.31,
  longitude: 77.22,
);

class _Profile extends BusinessProfileNotifier {
  _Profile(this.profile);

  final BusinessProfile profile;

  @override
  Future<BusinessProfile> build() async => profile;
}

/// Answers "which district is this point in" with [district], or fails like a phone offline.
class _Api extends CustomerLocationApi {
  _Api(this.district, {this.fails = false}) : super(Dio());

  final District? district;
  final bool fails;
  final asked = <(double, double)>[];

  @override
  Future<District?> nearestDistrict(double latitude, double longitude) async {
    asked.add((latitude, longitude));
    if (fails) throw const NetworkAppException('offline');
    return district;
  }
}

/// The map search: finds [places] for any address, or fails like the server being down.
class _Search extends PlaceSearchClient {
  _Search([this.places = const [], this.fails = false]) : super(Dio());

  final List<SearchedPlace> places;
  final bool fails;
  final asked = <String>[];

  @override
  Future<List<SearchedPlace>> search(String query) async {
    asked.add(query);
    if (fails) {
      throw DioException(requestOptions: RequestOptions(path: '/places'));
    }
    return places;
  }
}

BusinessProfile _business({
  String? city,
  String? state,
  String? postalCode,
  double? latitude,
  double? longitude,
}) => BusinessProfile(
  id: 'b-1',
  businessName: 'shajil shajil',
  verificationStatus: 'Verified',
  city: city,
  state: state,
  postalCode: postalCode,
  latitude: latitude,
  longitude: longitude,
);

Future<District?> _resolve(
  BusinessProfile profile,
  _Api api, [
  _Search? search,
]) {
  final container = ProviderContainer(
    overrides: [
      businessProfileProvider.overrideWith(() => _Profile(profile)),
      customerLocationApiProvider.overrideWithValue(api),
      placeSearchClientProvider.overrideWithValue(search ?? _Search()),
      allDistrictsProvider.overrideWith(
        (ref) async => const [_kanyakumari, _thiruvananthapuram],
      ),
    ],
  );
  addTearDown(container.dispose);
  return container.read(marketplaceBusinessDistrictProvider.future);
}

void main() {
  test('the registered pin says the district', () async {
    final api = _Api(_kanyakumari);
    final search = _Search();

    final district = await _resolve(
      _business(
        city: 'Marthandam',
        state: 'Tamil Nadu',
        latitude: 8.3,
        longitude: 77.2,
      ),
      api,
      search,
    );

    expect(district?.id, 'd-kk');
    expect(api.asked, [(8.3, 77.2)]);
    expect(search.asked, isEmpty, reason: 'the pin was enough');
  });

  test('without a pin, the address is found on the map', () async {
    final api = _Api(_kanyakumari);
    final search = _Search([_marthandam]);

    final district = await _resolve(
      _business(city: 'Marthandam', postalCode: '629165', state: 'Tamil Nadu'),
      api,
      search,
    );

    expect(district?.id, 'd-kk', reason: 'a town that is not a district');
    expect(search.asked, ['Marthandam, 629165, Tamil Nadu']);
    expect(api.asked, [(8.31, 77.22)]);
  });

  test(
    'without a pin or a map match, the town and state are matched by name',
    () async {
      final api = _Api(null);

      final district = await _resolve(
        _business(city: ' kanyakumari ', state: 'Tamil Nadu'),
        api,
      );

      expect(district?.id, 'd-kk');
      expect(api.asked, isEmpty);
    },
  );

  test('a pin and a search that both fail fall back to the names', () async {
    final district = await _resolve(
      _business(
        city: 'Thiruvananthapuram',
        state: 'Kerala',
        latitude: 8.5,
        longitude: 76.9,
      ),
      _Api(null, fails: true),
      _Search(const [], true),
    );

    expect(district?.id, 'd-tvm');
  });

  test('an address nothing can place says nothing', () async {
    final district = await _resolve(
      _business(city: 'Marthandam', state: 'Tamil Nadu'),
      _Api(null),
    );

    expect(district, isNull);
  });

  test('a profile with no address says nothing and asks nobody', () async {
    final api = _Api(_kanyakumari);
    final search = _Search([_marthandam]);

    final district = await _resolve(_business(), api, search);

    expect(district, isNull);
    expect(api.asked, isEmpty);
    expect(search.asked, isEmpty);
  });
}
