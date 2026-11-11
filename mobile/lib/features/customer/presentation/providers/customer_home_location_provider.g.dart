// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_home_location_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CustomerHomeLocationNotifier)
final customerHomeLocationProvider = CustomerHomeLocationNotifierProvider._();

final class CustomerHomeLocationNotifierProvider
    extends
        $NotifierProvider<CustomerHomeLocationNotifier, CustomerHomeLocation> {
  CustomerHomeLocationNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customerHomeLocationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customerHomeLocationNotifierHash();

  @$internal
  @override
  CustomerHomeLocationNotifier create() => CustomerHomeLocationNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CustomerHomeLocation value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CustomerHomeLocation>(value),
    );
  }
}

String _$customerHomeLocationNotifierHash() =>
    r'5bc2962d89a0704e6cb779e492f2e3bbf897a05e';

abstract class _$CustomerHomeLocationNotifier
    extends $Notifier<CustomerHomeLocation> {
  CustomerHomeLocation build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CustomerHomeLocation, CustomerHomeLocation>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CustomerHomeLocation, CustomerHomeLocation>,
              CustomerHomeLocation,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
