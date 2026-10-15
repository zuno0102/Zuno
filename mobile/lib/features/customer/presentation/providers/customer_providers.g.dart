// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(customerRemoteDataSource)
final customerRemoteDataSourceProvider = CustomerRemoteDataSourceProvider._();

final class CustomerRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          CustomerRemoteDataSource,
          CustomerRemoteDataSource,
          CustomerRemoteDataSource
        >
    with $Provider<CustomerRemoteDataSource> {
  CustomerRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customerRemoteDataSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customerRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<CustomerRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CustomerRemoteDataSource create(Ref ref) {
    return customerRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CustomerRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CustomerRemoteDataSource>(value),
    );
  }
}

String _$customerRemoteDataSourceHash() =>
    r'26316a3b9215fe62f1c9806cad91a9d1f26141c7';

@ProviderFor(customerRepository)
final customerRepositoryProvider = CustomerRepositoryProvider._();

final class CustomerRepositoryProvider
    extends
        $FunctionalProvider<
          CustomerRepository,
          CustomerRepository,
          CustomerRepository
        >
    with $Provider<CustomerRepository> {
  CustomerRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customerRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customerRepositoryHash();

  @$internal
  @override
  $ProviderElement<CustomerRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CustomerRepository create(Ref ref) {
    return customerRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CustomerRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CustomerRepository>(value),
    );
  }
}

String _$customerRepositoryHash() =>
    r'da1fec4f54e4a2f1fb67d23d8e362f8338ab6c18';

@ProviderFor(businessDetail)
final businessDetailProvider = BusinessDetailFamily._();

final class BusinessDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<BusinessDetail>,
          BusinessDetail,
          FutureOr<BusinessDetail>
        >
    with $FutureModifier<BusinessDetail>, $FutureProvider<BusinessDetail> {
  BusinessDetailProvider._({
    required BusinessDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'businessDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$businessDetailHash();

  @override
  String toString() {
    return r'businessDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<BusinessDetail> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BusinessDetail> create(Ref ref) {
    final argument = this.argument as String;
    return businessDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BusinessDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$businessDetailHash() => r'ee799446b4c0c3567729c2ae6d129f7b345bfdad';

final class BusinessDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<BusinessDetail>, String> {
  BusinessDetailFamily._()
    : super(
        retry: null,
        name: r'businessDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BusinessDetailProvider call(String businessId) =>
      BusinessDetailProvider._(argument: businessId, from: this);

  @override
  String toString() => r'businessDetailProvider';
}

@ProviderFor(serviceDetail)
final serviceDetailProvider = ServiceDetailFamily._();

final class ServiceDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<ServiceDetail>,
          ServiceDetail,
          FutureOr<ServiceDetail>
        >
    with $FutureModifier<ServiceDetail>, $FutureProvider<ServiceDetail> {
  ServiceDetailProvider._({
    required ServiceDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'serviceDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$serviceDetailHash();

  @override
  String toString() {
    return r'serviceDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ServiceDetail> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ServiceDetail> create(Ref ref) {
    final argument = this.argument as String;
    return serviceDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ServiceDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$serviceDetailHash() => r'ea1663864b5759c77223ac9dc424e3011e026c59';

final class ServiceDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ServiceDetail>, String> {
  ServiceDetailFamily._()
    : super(
        retry: null,
        name: r'serviceDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ServiceDetailProvider call(String serviceId) =>
      ServiceDetailProvider._(argument: serviceId, from: this);

  @override
  String toString() => r'serviceDetailProvider';
}
