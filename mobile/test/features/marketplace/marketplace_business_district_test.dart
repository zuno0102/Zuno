import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/business_owner/domain/entities/business_profile.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_profile_notifier.dart';
import 'package:zuno/features/catalog/domain/entities/district.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zuno/features/customer/data/datasources/customer_location_api.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_providers.dart';

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
    if (fails) throw Exception('offline');
    return district;
  }
}

BusinessProfile _business({
  String? city,
  String? state,
  double? latitude,
  double? longitude,
}) => BusinessProfile(
  id: 'b-1',
  businessName: 'shajil shajil',
  verificationStatus: 'Verified',
  city: city,
  state: state,
  latitude: latitude,
  longitude: longitude,
);

Future<District?> _resolve(BusinessProfile profile, _Api api) {
  final container = ProviderContainer(
    overrides: [
      businessProfileProvider.overrideWith(() => _Profile(profile)),
      customerLocationApiProvider.overrideWithValue(api),
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

    final district = await _resolve(
      _business(
        city: 'Marthandam',
        state: 'Tamil Nadu',
        latitude: 8.3,
        longitude: 77.2,
      ),
      api,
    );

    expect(district?.id, 'd-kk');
    expect(api.asked, [(8.3, 77.2)]);
  });

  test('without a pin, the town and state are matched by name', () async {
    final api = _Api(null);

    final district = await _resolve(
      _business(city: ' kanyakumari ', state: 'Tamil Nadu'),
      api,
    );

    expect(district?.id, 'd-kk');
    expect(api.asked, isEmpty);
  });

  test('a pin that cannot be looked up falls back to the names', () async {
    final district = await _resolve(
      _business(
        city: 'Thiruvananthapuram',
        state: 'Kerala',
        latitude: 8.5,
        longitude: 76.9,
      ),
      _Api(null, fails: true),
    );

    expect(district?.id, 'd-tvm');
  });

  test('a town that is not a district, with no pin, says nothing', () async {
    final district = await _resolve(
      _business(city: 'Marthandam', state: 'Tamil Nadu'),
      _Api(null),
    );

    expect(district, isNull);
  });
}
