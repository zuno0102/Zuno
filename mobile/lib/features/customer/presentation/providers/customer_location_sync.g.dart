// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_location_sync.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(customerLocationSync)
final customerLocationSyncProvider = CustomerLocationSyncProvider._();

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

final class CustomerLocationSyncProvider
    extends
        $FunctionalProvider<
          AsyncValue<CustomerLocationOpen>,
          CustomerLocationOpen,
          FutureOr<CustomerLocationOpen>
        >
    with
        $FutureModifier<CustomerLocationOpen>,
        $FutureProvider<CustomerLocationOpen> {
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
  CustomerLocationSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customerLocationSyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customerLocationSyncHash();

  @$internal
  @override
  $FutureProviderElement<CustomerLocationOpen> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CustomerLocationOpen> create(Ref ref) {
    return customerLocationSync(ref);
  }
}

String _$customerLocationSyncHash() =>
    r'677d36807b09e065f0d6ed29eaa408201125e5f7';
