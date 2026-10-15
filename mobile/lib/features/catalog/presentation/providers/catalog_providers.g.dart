// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(catalogRemoteDataSource)
final catalogRemoteDataSourceProvider = CatalogRemoteDataSourceProvider._();

final class CatalogRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          CatalogRemoteDataSource,
          CatalogRemoteDataSource,
          CatalogRemoteDataSource
        >
    with $Provider<CatalogRemoteDataSource> {
  CatalogRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'catalogRemoteDataSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$catalogRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<CatalogRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CatalogRemoteDataSource create(Ref ref) {
    return catalogRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CatalogRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CatalogRemoteDataSource>(value),
    );
  }
}

String _$catalogRemoteDataSourceHash() =>
    r'4d4cf409f81ac1223a6555bf15bc94d2621503e6';

/// Reference data — categories rarely change within a session, so this is kept alive
/// instead of being refetched every time a category picker opens.

@ProviderFor(serviceCategories)
final serviceCategoriesProvider = ServiceCategoriesProvider._();

/// Reference data — categories rarely change within a session, so this is kept alive
/// instead of being refetched every time a category picker opens.

final class ServiceCategoriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ServiceCategory>>,
          List<ServiceCategory>,
          FutureOr<List<ServiceCategory>>
        >
    with
        $FutureModifier<List<ServiceCategory>>,
        $FutureProvider<List<ServiceCategory>> {
  /// Reference data — categories rarely change within a session, so this is kept alive
  /// instead of being refetched every time a category picker opens.
  ServiceCategoriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serviceCategoriesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serviceCategoriesHash();

  @$internal
  @override
  $FutureProviderElement<List<ServiceCategory>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ServiceCategory>> create(Ref ref) {
    return serviceCategories(ref);
  }
}

String _$serviceCategoriesHash() => r'd7924e13f827d82f3538dc9777a33d61bd77813c';

/// India states — reference data, rarely changes within a session.

@ProviderFor(locationStates)
final locationStatesProvider = LocationStatesProvider._();

/// India states — reference data, rarely changes within a session.

final class LocationStatesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LocationState>>,
          List<LocationState>,
          FutureOr<List<LocationState>>
        >
    with
        $FutureModifier<List<LocationState>>,
        $FutureProvider<List<LocationState>> {
  /// India states — reference data, rarely changes within a session.
  LocationStatesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'locationStatesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$locationStatesHash();

  @$internal
  @override
  $FutureProviderElement<List<LocationState>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<LocationState>> create(Ref ref) {
    return locationStates(ref);
  }
}

String _$locationStatesHash() => r'2f64a28714731cc597a7e4604868e12577ce2cbf';

/// Districts filtered to a set of selected state ids. Keyed by a sorted, comma-joined id
/// string (rather than the raw List) so repeated calls with the same selection hit the
/// cache instead of refetching — Dart Lists don't compare equal by value, but Strings do.
/// Auto-dispose (not keepAlive) since many different state combinations could be queried
/// across a session and there's no need to hold them all in memory indefinitely.

@ProviderFor(districtsForStates)
final districtsForStatesProvider = DistrictsForStatesFamily._();

/// Districts filtered to a set of selected state ids. Keyed by a sorted, comma-joined id
/// string (rather than the raw List) so repeated calls with the same selection hit the
/// cache instead of refetching — Dart Lists don't compare equal by value, but Strings do.
/// Auto-dispose (not keepAlive) since many different state combinations could be queried
/// across a session and there's no need to hold them all in memory indefinitely.

final class DistrictsForStatesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<District>>,
          List<District>,
          FutureOr<List<District>>
        >
    with $FutureModifier<List<District>>, $FutureProvider<List<District>> {
  /// Districts filtered to a set of selected state ids. Keyed by a sorted, comma-joined id
  /// string (rather than the raw List) so repeated calls with the same selection hit the
  /// cache instead of refetching — Dart Lists don't compare equal by value, but Strings do.
  /// Auto-dispose (not keepAlive) since many different state combinations could be queried
  /// across a session and there's no need to hold them all in memory indefinitely.
  DistrictsForStatesProvider._({
    required DistrictsForStatesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'districtsForStatesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$districtsForStatesHash();

  @override
  String toString() {
    return r'districtsForStatesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<District>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<District>> create(Ref ref) {
    final argument = this.argument as String;
    return districtsForStates(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DistrictsForStatesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$districtsForStatesHash() =>
    r'3145c414715d3723d83b6248df25fc7a8e6b2795';

/// Districts filtered to a set of selected state ids. Keyed by a sorted, comma-joined id
/// string (rather than the raw List) so repeated calls with the same selection hit the
/// cache instead of refetching — Dart Lists don't compare equal by value, but Strings do.
/// Auto-dispose (not keepAlive) since many different state combinations could be queried
/// across a session and there's no need to hold them all in memory indefinitely.

final class DistrictsForStatesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<District>>, String> {
  DistrictsForStatesFamily._()
    : super(
        retry: null,
        name: r'districtsForStatesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Districts filtered to a set of selected state ids. Keyed by a sorted, comma-joined id
  /// string (rather than the raw List) so repeated calls with the same selection hit the
  /// cache instead of refetching — Dart Lists don't compare equal by value, but Strings do.
  /// Auto-dispose (not keepAlive) since many different state combinations could be queried
  /// across a session and there's no need to hold them all in memory indefinitely.

  DistrictsForStatesProvider call(String stateIdsCsv) =>
      DistrictsForStatesProvider._(argument: stateIdsCsv, from: this);

  @override
  String toString() => r'districtsForStatesProvider';
}

/// Every district in the country, cached for the session.
///
/// Fetched once and kept, because it powers the place suggestions that appear as somebody types.
/// The list is about 765 rows and never changes, so holding it is cheaper than a network call per
/// keystroke — which the free geocoder would refuse anyway, and which it cannot answer at all since
/// it does no prefix matching.

@ProviderFor(allDistricts)
final allDistrictsProvider = AllDistrictsProvider._();

/// Every district in the country, cached for the session.
///
/// Fetched once and kept, because it powers the place suggestions that appear as somebody types.
/// The list is about 765 rows and never changes, so holding it is cheaper than a network call per
/// keystroke — which the free geocoder would refuse anyway, and which it cannot answer at all since
/// it does no prefix matching.

final class AllDistrictsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<District>>,
          List<District>,
          FutureOr<List<District>>
        >
    with $FutureModifier<List<District>>, $FutureProvider<List<District>> {
  /// Every district in the country, cached for the session.
  ///
  /// Fetched once and kept, because it powers the place suggestions that appear as somebody types.
  /// The list is about 765 rows and never changes, so holding it is cheaper than a network call per
  /// keystroke — which the free geocoder would refuse anyway, and which it cannot answer at all since
  /// it does no prefix matching.
  AllDistrictsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allDistrictsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allDistrictsHash();

  @$internal
  @override
  $FutureProviderElement<List<District>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<District>> create(Ref ref) {
    return allDistricts(ref);
  }
}

String _$allDistrictsHash() => r'd1745a438f779d0080962cca10b4620d2250d14e';
