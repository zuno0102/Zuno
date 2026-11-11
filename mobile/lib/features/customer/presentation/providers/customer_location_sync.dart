import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuno/core/location/location_service.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/auth/presentation/providers/auth_state.dart';
import 'package:zuno/features/catalog/domain/entities/district.dart';
import 'package:zuno/features/customer/data/datasources/customer_location_api.dart';
import 'package:zuno/features/customer/domain/entities/customer_location.dart';
import 'package:zuno/features/customer/presentation/providers/customer_search_filter_provider.dart';

part 'customer_location_sync.g.dart';

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

/// Who the location kept on this device belongs to. A different customer signing in on the same
/// phone or browser starts from their own account and phone, never from the last person's district.
const customerLocationOwnerKey = 'customer_location_owner';

/// Whether this customer has been asked for the location permission on app open. Asked once per
/// customer: after that the open-time check only reads the position when it was allowed, and never
/// asks again — asking on every launch is how people learn to refuse everything.
String customerLocationAskedKey(String userId) =>
    'customer_location_permission_asked:$userId';

/// How the open-time check ended, so the app knows whether to ask the customer itself.
enum CustomerLocationOpen {
  /// A location is set, the customer chose one (or everywhere), or they were asked before.
  settled,

  /// A customer's first open, and the phone or browser gave no location: the permission is
  /// blocked, no fix came, or the place is outside the area. The app then shows the "Where are
  /// you?" chooser, where a tap on "Use my current location" asks again. Browsers remember "Block"
  /// per site, so on the web the automatic ask can end without any popup at all.
  needsChoice,
}

/// Runs when the customer app opens, and again whenever a different customer signs in.
///
/// 1. A location on this device that belongs to another customer is forgotten.
/// 2. A device with no location of its own takes the one kept in the customer's account.
/// 3. Unless the customer picked or cleared a location themselves, the phone's position is read —
///    asking for the permission the first time for this customer — and becomes their district.
/// 4. From then on, every change to the location is saved to their account.
///
/// Never fails out loud: no permission, no signal or no network leaves the location as it was, and
/// the customer can still pick one by hand.
@Riverpod(keepAlive: true)
Future<CustomerLocationOpen> customerLocationSync(Ref ref) async {
  final userId = ref.watch(
    authProvider.select(
      (auth) => switch (auth.value) {
        AuthAuthenticated(:final user) => user.id,
        _ => null,
      },
    ),
  );
  if (userId == null) return CustomerLocationOpen.settled;

  final filter = ref.read(customerSearchFilterProvider.notifier);
  final api = ref.read(customerLocationApiProvider);
  await filter.ready;
  final store = await SharedPreferences.getInstance();

  // 1. Someone else's location on this device. A device from before owners were kept has its
  //    location adopted by whoever signs in first.
  final owner = store.getString(customerLocationOwnerKey);
  if (owner != null && owner != userId) await filter.forget();
  await store.setString(customerLocationOwnerKey, userId);

  // 2. The account, for a device that has never been told anything for this customer.
  if (ref.read(customerSearchFilterProvider).locationSource == null) {
    try {
      filter.applySaved(await api.myLocation());
    } on Object {
      // Offline, or a server without the field yet: the device simply starts at everywhere.
    }
  }

  // 4. Every change from here on is saved to the account — but not the one just read from it.
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

  // 3. The phone — unless the customer chose a place, or everywhere, themselves.
  final source = ref.read(customerSearchFilterProvider).locationSource;
  if (source == CustomerLocationSource.manual ||
      source == CustomerLocationSource.cleared) {
    return CustomerLocationOpen.settled;
  }

  final askedKey = customerLocationAskedKey(userId);
  final asked = store.getBool(askedKey) ?? false;
  await store.setBool(askedKey, true);

  var found = false;
  try {
    final outcome = await locateCustomerFromPhone(
      locationService: ref.read(locationServiceProvider),
      api: api,
      filter: filter,
      askPermission: !asked,
    );
    found = outcome.district != null;
  } on Object {
    // No district found is the same as no location read: nothing changes.
  }

  // Asked once per customer: only their first open hands the question to the app's own chooser.
  final hasLocation = ref.read(customerSearchFilterProvider).hasLocation;
  return !asked && !found && !hasLocation
      ? CustomerLocationOpen.needsChoice
      : CustomerLocationOpen.settled;
}

String _accountKey(CustomerSearchFilter filter) =>
    '${filter.locationSource?.code}|${filter.districtIds.firstOrNull}';
