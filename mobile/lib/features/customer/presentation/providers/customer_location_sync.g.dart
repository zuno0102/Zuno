// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_location_sync.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(customerLocationSync)
final customerLocationSyncProvider = CustomerLocationSyncProvider._();

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
  /// 1. A location on this device that belongs to another customer is forgotten (theirs and their
  ///    search filter).
  /// 2. The location kept in the customer's account wins over the device's; an account without one
  ///    takes the device's.
  /// 3. Unless the customer picked their district by hand, the phone's position is read — asking for
  ///    the permission the first time for this customer — and becomes their location.
  /// 4. From then on, every change to their location is saved to their account.
  ///
  /// Only the customer's location: the search filter (the pin button) is never set from here.
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
    r'd2b8b87189caad2bec5a3219b554b24089a25725';
