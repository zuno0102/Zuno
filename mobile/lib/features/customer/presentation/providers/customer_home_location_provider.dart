import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuno/features/catalog/domain/entities/district.dart';
import 'package:zuno/features/customer/domain/entities/customer_location.dart';

part 'customer_home_location_provider.g.dart';

/// Where the customer is: the district set up when they first open the app — from the phone, or
/// picked by hand — and kept in their account.
///
/// **Not a search filter.** It decides only the "Recommended … near you" section; every other
/// listing is as it always was. Narrowing a search to districts is the location (pin) button's job,
/// kept in `customerSearchFilterProvider`, and the two never change each other.
class CustomerHomeLocation {
  const CustomerHomeLocation({this.district, this.source});

  final District? district;

  /// From the phone (updated when they move) or picked by hand (left alone). Null until set.
  final CustomerLocationSource? source;

  bool get isSet => district != null;
}

@Riverpod(keepAlive: true)
class CustomerHomeLocationNotifier extends _$CustomerHomeLocationNotifier {
  static const _keyId = 'customer_home_district_id';
  static const _keyName = 'customer_home_district_name';
  static const _keyStateId = 'customer_home_state_id';
  static const _keyStateName = 'customer_home_state_name';
  static const _keySource = 'customer_home_location_source';

  /// Done once the location kept on this device has been read back.
  late Future<void> ready;

  @override
  CustomerHomeLocation build() {
    ready = _restore();
    unawaited(ready);
    return const CustomerHomeLocation();
  }

  Future<void> _restore() async {
    try {
      final store = await SharedPreferences.getInstance();
      final id = store.getString(_keyId);
      final source = CustomerLocationSource.fromCode(
        store.getString(_keySource),
      );
      // Set while this was loading: that is newer than what the device held.
      if (state.isSet || id == null || source == null) return;
      state = CustomerHomeLocation(
        district: District(
          id: id,
          name: store.getString(_keyName) ?? '',
          stateId: store.getString(_keyStateId) ?? '',
          stateName: store.getString(_keyStateName) ?? '',
        ),
        source: source,
      );
    } on Exception {
      // Unreadable storage: the customer is simply asked to set it again.
    }
  }

  /// Sets where the customer is — read from the phone ([CustomerLocationSource.gps]) or picked.
  Future<void> set(District district, CustomerLocationSource source) async {
    state = CustomerHomeLocation(district: district, source: source);
    try {
      final store = await SharedPreferences.getInstance();
      await store.setString(_keyId, district.id);
      await store.setString(_keyName, district.name);
      await store.setString(_keyStateId, district.stateId);
      await store.setString(_keyStateName, district.stateName);
      await store.setString(_keySource, source.code);
    } on Exception {
      // Kept for this session; the account holds it for the next.
    }
  }

  /// The location kept in the customer's account, for a device that has none of its own.
  /// An account with no district (never set, or the old "everywhere") leaves it unset.
  Future<void> applySaved(SavedCustomerLocation saved) async {
    final district = saved.district;
    final source = saved.source;
    if (district == null ||
        source == null ||
        source == CustomerLocationSource.cleared) {
      return;
    }
    await set(district, source);
  }

  /// Forgets it on this device — for a different customer signing in on it.
  Future<void> forget() async {
    state = const CustomerHomeLocation();
    try {
      final store = await SharedPreferences.getInstance();
      for (final key in [
        _keyId,
        _keyName,
        _keyStateId,
        _keyStateName,
        _keySource,
      ]) {
        await store.remove(key);
      }
    } on Exception {
      // Nothing to undo.
    }
  }
}
