import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuno/core/location/location_service.dart';
import 'package:zuno/features/catalog/domain/entities/district.dart';
import 'package:zuno/features/customer/data/datasources/customer_location_api.dart';
import 'package:zuno/features/customer/domain/entities/customer_location.dart';
import 'package:zuno/features/customer/presentation/providers/customer_search_filter_provider.dart';

part 'customer_location_sync.g.dart';

/// Whether the location permission has been asked for on app open already. Asked once: after that
/// the open-time check only reads the position when it was allowed, and never asks again — asking on
/// every launch is how people learn to refuse everything.
const customerLocationAskedKey = 'customer_location_permission_asked';

/// What reading the phone's location came to.
class PhoneLocationOutcome {
  const PhoneLocationOutcome.found(District this.district) : problem = null;

  const PhoneLocationOutcome.outsideArea() : district = null, problem = null;

  const PhoneLocationOutcome.unavailable(LocationProblem this.problem)
    : district = null;

  /// The district the phone is in, already set as the customer's location.
  final District? district;

  /// Why the position could not be read; null when it was read.
  final LocationProblem? problem;

  /// Read, but further than any district Zuno serves — the location is left as it was.
  bool get isOutsideArea => district == null && problem == null;
}

/// Reads where the phone is, turns it into a district, and sets it as the customer's location (read
/// from the phone). Used on every app open, and by "Use my current location" in the picker.
Future<PhoneLocationOutcome> locateCustomerFromPhone({
  required LocationService locationService,
  required CustomerLocationApi api,
  required CustomerSearchFilterNotifier filter,
  required bool askPermission,
}) async {
  final position = await locationService.current(askPermission: askPermission);
  if (!position.hasPosition) {
    return PhoneLocationOutcome.unavailable(
      position.problem ?? LocationProblem.failed,
    );
  }

  final district = await api.nearestDistrict(
    position.latitude!,
    position.longitude!,
  );
  if (district == null) return const PhoneLocationOutcome.outsideArea();

  filter.setDetectedLocation(district);
  return PhoneLocationOutcome.found(district);
}

/// Runs once each time the customer app opens.
///
/// 1. A phone with no location of its own takes the one kept in the customer's account.
/// 2. Unless the customer picked or cleared a location themselves, the phone's position is read —
///    asking for the permission the first time only — and becomes their district.
/// 3. From then on, every change to the location is saved to their account.
///
/// Never fails out loud: no permission, no signal or no network leaves the location as it was, and
/// the customer can still pick one by hand.
@Riverpod(keepAlive: true)
Future<void> customerLocationSync(Ref ref) async {
  final filter = ref.read(customerSearchFilterProvider.notifier);
  final api = ref.read(customerLocationApiProvider);
  await filter.ready;

  // 1. The account, for a phone that has never been told anything.
  if (ref.read(customerSearchFilterProvider).locationSource == null) {
    try {
      filter.applySaved(await api.myLocation());
    } on Object {
      // Offline, or a server without the field yet: the phone simply starts at everywhere.
    }
  }

  // 3. Every change from here on is saved to the account — but not the one just read from it.
  var saved = _accountKey(ref.read(customerSearchFilterProvider));
  ref.listen(customerSearchFilterProvider, (_, next) {
    final source = next.locationSource;
    final key = _accountKey(next);
    if (source == null || key == saved) return;
    saved = key;
    unawaited(
      api.save(next.districtIds.firstOrNull, source).catchError((Object _) {}),
    );
  });

  // 2. The phone — unless the customer chose a place, or everywhere, themselves.
  final source = ref.read(customerSearchFilterProvider).locationSource;
  if (source == CustomerLocationSource.manual ||
      source == CustomerLocationSource.cleared) {
    return;
  }

  try {
    final store = await SharedPreferences.getInstance();
    final asked = store.getBool(customerLocationAskedKey) ?? false;
    await store.setBool(customerLocationAskedKey, true);

    await locateCustomerFromPhone(
      locationService: ref.read(locationServiceProvider),
      api: api,
      filter: filter,
      askPermission: !asked,
    );
  } on Object {
    // No district found is the same as no location read: nothing changes.
  }
}

String _accountKey(CustomerSearchFilter filter) =>
    '${filter.locationSource?.code}|${filter.districtIds.firstOrNull}';
