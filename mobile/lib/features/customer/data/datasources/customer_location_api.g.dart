// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_location_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(customerLocationApi)
final customerLocationApiProvider = CustomerLocationApiProvider._();

final class CustomerLocationApiProvider
    extends
        $FunctionalProvider<
          CustomerLocationApi,
          CustomerLocationApi,
          CustomerLocationApi
        >
    with $Provider<CustomerLocationApi> {
  CustomerLocationApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customerLocationApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customerLocationApiHash();

  @$internal
  @override
  $ProviderElement<CustomerLocationApi> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CustomerLocationApi create(Ref ref) {
    return customerLocationApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CustomerLocationApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CustomerLocationApi>(value),
    );
  }
}

String _$customerLocationApiHash() =>
    r'fa66dabb89fcaab3c4dd36698b56092e7b68fd51';
