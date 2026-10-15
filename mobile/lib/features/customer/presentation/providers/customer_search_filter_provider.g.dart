// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_search_filter_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CustomerSearchFilterNotifier)
final customerSearchFilterProvider = CustomerSearchFilterNotifierProvider._();

final class CustomerSearchFilterNotifierProvider
    extends
        $NotifierProvider<CustomerSearchFilterNotifier, CustomerSearchFilter> {
  CustomerSearchFilterNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customerSearchFilterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customerSearchFilterNotifierHash();

  @$internal
  @override
  CustomerSearchFilterNotifier create() => CustomerSearchFilterNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CustomerSearchFilter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CustomerSearchFilter>(value),
    );
  }
}

String _$customerSearchFilterNotifierHash() =>
    r'27a767370178dd6fc2438cddb7cccd216ffabfcc';

abstract class _$CustomerSearchFilterNotifier
    extends $Notifier<CustomerSearchFilter> {
  CustomerSearchFilter build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CustomerSearchFilter, CustomerSearchFilter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CustomerSearchFilter, CustomerSearchFilter>,
              CustomerSearchFilter,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
