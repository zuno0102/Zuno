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
import 'package:zuno/features/customer/presentation/providers/customer_home_location_provider.dart';
import 'package:zuno/features/customer/presentation/providers/customer_search_filter_provider.dart';

part 'customer_location_sync.g.dart';

/// What reading the phone's location came to.
class PhoneLocationOutcome {
  const PhoneLocationOutcome.found(District this.district) : problem = null;

  const PhoneLocationOutcome.outsideArea() : district = null, problem = null;

  const PhoneLocationOutcome.unavailable(LocationProblem this.problem)
    : district = null;

  /// The district the phone is in, already handed to whoever asked.
  final District? district;

  /// Why the position could not be read; null when it was read.
  final LocationProblem? problem;

  /// Read, but further than any district Zuno serves — nothing is changed.
  bool get isOutsideArea => district == null && problem == null;
}

/// Reads where the phone is and turns it into a district, handed to [onFound]: the customer's
/// location (setup and app open) or the search filter (the pin button's "Use my current location").
Future<PhoneLocationOutcome> locateCustomerFromPhone({
  required LocationService locationService,
  required CustomerLocationApi api,
  required void Function(District district) onFound,
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

  onFound(district);
  return PhoneLocationOutcome.found(district);
}

/// Who the location kept on this device belongs to. A different customer signing in on the same
/// phone or browser starts from their own account and phone, never from the last person's district.
const customerLocationOwnerKey = 'customer_location_owner';

/// Whether this customer has been shown the system location permission dialog on app open. Shown
/// once per customer; after that the app asks with its own setup sheet, which explains itself.
String customerLocationAskedKey(String userId) =>
    'customer_location_permission_asked:$userId';

/// How the open-time check ended, so the app knows whether to ask the customer itself.
enum CustomerLocationOpen {
  /// The customer's location is set.
  settled,

  /// No location yet, and the phone or browser gave none: the permission is blocked, no fix came,
  /// or the place is outside the area. Setting it is required, so the app shows its setup sheet
  /// until they do. Browsers remember "Block" per site, so on the web the automatic ask can end
  /// without any popup at all.
  needsChoice,
}

/// Runs when the customer app opens, and again whenever a different customer signs in.
///
/// 1. A location on this device that belongs to another customer is forgotten (theirs and their
///    search filter).
/// 2. The location kept in the customer's account wins over the device's; an account without one
///    takes the device's.
/// 3. Unless the customer picked their district by hand, the phone's position is read — asking for
///    the permission the first time for this customer — and becomes their location.
/// 4. From then on, every change to their location is saved to their account.
///
/// Only the customer's location: the search filter (the pin button) is never set from here.
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

  final home = ref.read(customerHomeLocationProvider.notifier);
  final filter = ref.read(customerSearchFilterProvider.notifier);
  final api = ref.read(customerLocationApiProvider);
  await home.ready;
  await filter.ready;
  final store = await SharedPreferences.getInstance();

  // 1. Someone else's location on this device. A device from before owners were kept has its
  //    location adopted by whoever signs in first.
  final owner = store.getString(customerLocationOwnerKey);
  if (owner != null && owner != userId) {
    await home.forget();
    await filter.forget();
  }
  await store.setString(customerLocationOwnerKey, userId);

  // 2. The account is where the customer's location lives: signing in on phone B after setting it
  //    on phone A starts B in the same place, whatever B held from before. An account with no
  //    location yet takes this device's (set before locations were kept in accounts, or while
  //    offline), so the next phone finds it there.
  SavedCustomerLocation? account;
  try {
    account = await api.myLocation();
  } on Object {
    // Offline, or a server without the field yet: the device keeps what it has, and the setup
    // below asks if that is nothing.
  }
  if (account != null && _hasPlace(account)) {
    if (_savedKey(account) !=
        _accountKey(ref.read(customerHomeLocationProvider))) {
      await home.applySaved(account);
    }
  }

  // 4. Every change from here on is saved to the account — but not the one just read from it.
  var saved = account != null && _hasPlace(account)
      ? _savedKey(account)
      : _accountKey(ref.read(customerHomeLocationProvider));
  var sent = false;
  void save(CustomerHomeLocation next) {
    final source = next.source;
    final key = _accountKey(next);
    if (source == null || !next.isSet || key == saved) return;
    saved = key;
    sent = true;
    unawaited(api.save(next.district!.id, source).catchError((Object _) {}));
  }

  ref.listen(customerHomeLocationProvider, (_, next) => save(next));

  // An account with no place yet takes this device's — once, after the phone below has had its
  // say, so a phone that has moved saves only where it is now.
  void giveAccountThisDevicesLocation() {
    if (account == null || _hasPlace(account) || sent) return;
    saved = 'none';
    save(ref.read(customerHomeLocationProvider));
  }

  // 3. The phone — unless the customer picked their district themselves.
  final current = ref.read(customerHomeLocationProvider);
  if (current.isSet && current.source == CustomerLocationSource.manual) {
    giveAccountThisDevicesLocation();
    return CustomerLocationOpen.settled;
  }

  final askedKey = customerLocationAskedKey(userId);
  final asked = store.getBool(askedKey) ?? false;
  await store.setBool(askedKey, true);

  try {
    await locateCustomerFromPhone(
      locationService: ref.read(locationServiceProvider),
      api: api,
      onFound: (d) => home.set(d, CustomerLocationSource.gps),
      askPermission: !asked,
    );
  } on Object {
    // No district found is the same as no location read: nothing changes.
  }
  giveAccountThisDevicesLocation();

  // Setting a location is required: until the customer has one, every open asks with the app's
  // own setup sheet. (The system permission dialog is still asked only once, above.)
  return ref.read(customerHomeLocationProvider).isSet
      ? CustomerLocationOpen.settled
      : CustomerLocationOpen.needsChoice;
}

String _accountKey(CustomerHomeLocation location) =>
    '${location.source?.code}|${location.district?.id}';

String _savedKey(SavedCustomerLocation location) =>
    '${location.source?.code}|${location.district?.id}';

/// A district the device can take; never set, or an older "everywhere", is not one.
bool _hasPlace(SavedCustomerLocation location) =>
    location.district != null &&
    location.source != null &&
    location.source != CustomerLocationSource.cleared;
