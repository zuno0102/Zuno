// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rental_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's usual client, pointed at the Rent service. Same interceptors, and the very same
/// [authInterceptorProvider], so Rent shares the login and its one token refresh.

@ProviderFor(rentDio)
final rentDioProvider = RentDioProvider._();

/// The app's usual client, pointed at the Rent service. Same interceptors, and the very same
/// [authInterceptorProvider], so Rent shares the login and its one token refresh.

final class RentDioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  /// The app's usual client, pointed at the Rent service. Same interceptors, and the very same
  /// [authInterceptorProvider], so Rent shares the login and its one token refresh.
  RentDioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rentDioProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rentDioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return rentDio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$rentDioHash() => r'1fde69072be0ce7c5eab2e97286a8705b9150d2d';

@ProviderFor(rentalRepository)
final rentalRepositoryProvider = RentalRepositoryProvider._();

final class RentalRepositoryProvider
    extends
        $FunctionalProvider<
          RentalRepository,
          RentalRepository,
          RentalRepository
        >
    with $Provider<RentalRepository> {
  RentalRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rentalRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rentalRepositoryHash();

  @$internal
  @override
  $ProviderElement<RentalRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RentalRepository create(Ref ref) {
    return rentalRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RentalRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RentalRepository>(value),
    );
  }
}

String _$rentalRepositoryHash() => r'a6f2154fa1976976f2bc184f4e34c1619e660600';

/// The rent catalogue — categories with their sub-categories. Read once per session; the server
/// caches it as well.

@ProviderFor(rentalCategories)
final rentalCategoriesProvider = RentalCategoriesProvider._();

/// The rent catalogue — categories with their sub-categories. Read once per session; the server
/// caches it as well.

final class RentalCategoriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RentalCategory>>,
          List<RentalCategory>,
          FutureOr<List<RentalCategory>>
        >
    with
        $FutureModifier<List<RentalCategory>>,
        $FutureProvider<List<RentalCategory>> {
  /// The rent catalogue — categories with their sub-categories. Read once per session; the server
  /// caches it as well.
  RentalCategoriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rentalCategoriesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rentalCategoriesHash();

  @$internal
  @override
  $FutureProviderElement<List<RentalCategory>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RentalCategory>> create(Ref ref) {
    return rentalCategories(ref);
  }
}

String _$rentalCategoriesHash() => r'88dd47bc916048a59fcd784e971ef8428f413868';

/// How a rent item can be charged — names, explanations and suffixes from the server's table.

@ProviderFor(rentalPriceTypes)
final rentalPriceTypesProvider = RentalPriceTypesProvider._();

/// How a rent item can be charged — names, explanations and suffixes from the server's table.

final class RentalPriceTypesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RentalPriceTypeOption>>,
          List<RentalPriceTypeOption>,
          FutureOr<List<RentalPriceTypeOption>>
        >
    with
        $FutureModifier<List<RentalPriceTypeOption>>,
        $FutureProvider<List<RentalPriceTypeOption>> {
  /// How a rent item can be charged — names, explanations and suffixes from the server's table.
  RentalPriceTypesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rentalPriceTypesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rentalPriceTypesHash();

  @$internal
  @override
  $FutureProviderElement<List<RentalPriceTypeOption>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RentalPriceTypeOption>> create(Ref ref) {
    return rentalPriceTypes(ref);
  }
}

String _$rentalPriceTypesHash() => r'bba901a0144dae3a8d0eaecb8a9bd03c9e4ea3a8';

/// The counts behind the business home screen's Rent tiles.

@ProviderFor(rentalSummary)
final rentalSummaryProvider = RentalSummaryProvider._();

/// The counts behind the business home screen's Rent tiles.

final class RentalSummaryProvider
    extends
        $FunctionalProvider<
          AsyncValue<RentalSummary>,
          RentalSummary,
          FutureOr<RentalSummary>
        >
    with $FutureModifier<RentalSummary>, $FutureProvider<RentalSummary> {
  /// The counts behind the business home screen's Rent tiles.
  RentalSummaryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rentalSummaryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rentalSummaryHash();

  @$internal
  @override
  $FutureProviderElement<RentalSummary> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<RentalSummary> create(Ref ref) {
    return rentalSummary(ref);
  }
}

String _$rentalSummaryHash() => r'1a62646377f90458885eea73d922f6adbc5a43d2';

/// Only the items available now (true) or switched off (false) — what a Rent tile opens.

@ProviderFor(rentalItemsByAvailability)
final rentalItemsByAvailabilityProvider = RentalItemsByAvailabilityFamily._();

/// Only the items available now (true) or switched off (false) — what a Rent tile opens.

final class RentalItemsByAvailabilityProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RentalItem>>,
          List<RentalItem>,
          FutureOr<List<RentalItem>>
        >
    with $FutureModifier<List<RentalItem>>, $FutureProvider<List<RentalItem>> {
  /// Only the items available now (true) or switched off (false) — what a Rent tile opens.
  RentalItemsByAvailabilityProvider._({
    required RentalItemsByAvailabilityFamily super.from,
    required bool super.argument,
  }) : super(
         retry: null,
         name: r'rentalItemsByAvailabilityProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$rentalItemsByAvailabilityHash();

  @override
  String toString() {
    return r'rentalItemsByAvailabilityProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<RentalItem>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RentalItem>> create(Ref ref) {
    final argument = this.argument as bool;
    return rentalItemsByAvailability(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RentalItemsByAvailabilityProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$rentalItemsByAvailabilityHash() =>
    r'3e4fab8e951487e30ce43e4e39bd571800c47140';

/// Only the items available now (true) or switched off (false) — what a Rent tile opens.

final class RentalItemsByAvailabilityFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<RentalItem>>, bool> {
  RentalItemsByAvailabilityFamily._()
    : super(
        retry: null,
        name: r'rentalItemsByAvailabilityProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Only the items available now (true) or switched off (false) — what a Rent tile opens.

  RentalItemsByAvailabilityProvider call(bool isAvailable) =>
      RentalItemsByAvailabilityProvider._(argument: isAvailable, from: this);

  @override
  String toString() => r'rentalItemsByAvailabilityProvider';
}

/// The Stock page: each item with in, out and total.

@ProviderFor(rentalStock)
final rentalStockProvider = RentalStockProvider._();

/// The Stock page: each item with in, out and total.

final class RentalStockProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RentalStockLine>>,
          List<RentalStockLine>,
          FutureOr<List<RentalStockLine>>
        >
    with
        $FutureModifier<List<RentalStockLine>>,
        $FutureProvider<List<RentalStockLine>> {
  /// The Stock page: each item with in, out and total.
  RentalStockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rentalStockProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rentalStockHash();

  @$internal
  @override
  $FutureProviderElement<List<RentalStockLine>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RentalStockLine>> create(Ref ref) {
    return rentalStock(ref);
  }
}

String _$rentalStockHash() => r'fa4e026f72918bbdedb50579ec82329ba5b2c48e';

/// One item's orders — where its pieces went.

@ProviderFor(rentalItemOrders)
final rentalItemOrdersProvider = RentalItemOrdersFamily._();

/// One item's orders — where its pieces went.

final class RentalItemOrdersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RentalOrder>>,
          List<RentalOrder>,
          FutureOr<List<RentalOrder>>
        >
    with
        $FutureModifier<List<RentalOrder>>,
        $FutureProvider<List<RentalOrder>> {
  /// One item's orders — where its pieces went.
  RentalItemOrdersProvider._({
    required RentalItemOrdersFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'rentalItemOrdersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$rentalItemOrdersHash();

  @override
  String toString() {
    return r'rentalItemOrdersProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<RentalOrder>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RentalOrder>> create(Ref ref) {
    final argument = this.argument as String;
    return rentalItemOrders(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RentalItemOrdersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$rentalItemOrdersHash() => r'd22c7008b768ffca5f391a5bac53c3e1991ca6ff';

/// One item's orders — where its pieces went.

final class RentalItemOrdersFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<RentalOrder>>, String> {
  RentalItemOrdersFamily._()
    : super(
        retry: null,
        name: r'rentalItemOrdersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One item's orders — where its pieces went.

  RentalItemOrdersProvider call(String rentalItemId) =>
      RentalItemOrdersProvider._(argument: rentalItemId, from: this);

  @override
  String toString() => r'rentalItemOrdersProvider';
}

/// The signed-in business's rent items, newest first.
///
/// Loading it also refreshes how customers see the business (name, logo, verified) — in the
/// background, so a slow or failed refresh never holds up the business's own list.

@ProviderFor(businessRentals)
final businessRentalsProvider = BusinessRentalsProvider._();

/// The signed-in business's rent items, newest first.
///
/// Loading it also refreshes how customers see the business (name, logo, verified) — in the
/// background, so a slow or failed refresh never holds up the business's own list.

final class BusinessRentalsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RentalItem>>,
          List<RentalItem>,
          FutureOr<List<RentalItem>>
        >
    with $FutureModifier<List<RentalItem>>, $FutureProvider<List<RentalItem>> {
  /// The signed-in business's rent items, newest first.
  ///
  /// Loading it also refreshes how customers see the business (name, logo, verified) — in the
  /// background, so a slow or failed refresh never holds up the business's own list.
  BusinessRentalsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'businessRentalsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$businessRentalsHash();

  @$internal
  @override
  $FutureProviderElement<List<RentalItem>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RentalItem>> create(Ref ref) {
    return businessRentals(ref);
  }
}

String _$businessRentalsHash() => r'9b71554d5d2aa6ede3ce0f12b57185b12d4de2c6';
