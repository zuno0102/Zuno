// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rental_customer_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The panel the customer has open. Every login opens on Service; Rent is one tap away and holds
/// only until the next login, so a customer never lands on Rent without choosing it.

@ProviderFor(CustomerPanelChoice)
final customerPanelChoiceProvider = CustomerPanelChoiceProvider._();

/// The panel the customer has open. Every login opens on Service; Rent is one tap away and holds
/// only until the next login, so a customer never lands on Rent without choosing it.
final class CustomerPanelChoiceProvider
    extends $NotifierProvider<CustomerPanelChoice, CustomerPanel> {
  /// The panel the customer has open. Every login opens on Service; Rent is one tap away and holds
  /// only until the next login, so a customer never lands on Rent without choosing it.
  CustomerPanelChoiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customerPanelChoiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customerPanelChoiceHash();

  @$internal
  @override
  CustomerPanelChoice create() => CustomerPanelChoice();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CustomerPanel value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CustomerPanel>(value),
    );
  }
}

String _$customerPanelChoiceHash() =>
    r'f3392a5b21412d7e8757990fa9494831ddbb5e54';

/// The panel the customer has open. Every login opens on Service; Rent is one tap away and holds
/// only until the next login, so a customer never lands on Rent without choosing it.

abstract class _$CustomerPanelChoice extends $Notifier<CustomerPanel> {
  CustomerPanel build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CustomerPanel, CustomerPanel>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CustomerPanel, CustomerPanel>,
              CustomerPanel,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Which shuffle the Rent home is showing. A pull to refresh rolls a new one.

@ProviderFor(RentalHomeSeed)
final rentalHomeSeedProvider = RentalHomeSeedProvider._();

/// Which shuffle the Rent home is showing. A pull to refresh rolls a new one.
final class RentalHomeSeedProvider
    extends $NotifierProvider<RentalHomeSeed, int> {
  /// Which shuffle the Rent home is showing. A pull to refresh rolls a new one.
  RentalHomeSeedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rentalHomeSeedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rentalHomeSeedHash();

  @$internal
  @override
  RentalHomeSeed create() => RentalHomeSeed();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$rentalHomeSeedHash() => r'1bc156e417f532a1af7506869fb9533e1541a2f5';

/// Which shuffle the Rent home is showing. A pull to refresh rolls a new one.

abstract class _$RentalHomeSeed extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Kept alive: the Rent home is rebuilt every time the customer comes back from another tab.

@ProviderFor(RentalBrowse)
final rentalBrowseProvider = RentalBrowseProvider._();

/// Kept alive: the Rent home is rebuilt every time the customer comes back from another tab.
final class RentalBrowseProvider
    extends $NotifierProvider<RentalBrowse, RentalBrowseFilter> {
  /// Kept alive: the Rent home is rebuilt every time the customer comes back from another tab.
  RentalBrowseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rentalBrowseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rentalBrowseHash();

  @$internal
  @override
  RentalBrowse create() => RentalBrowse();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RentalBrowseFilter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RentalBrowseFilter>(value),
    );
  }
}

String _$rentalBrowseHash() => r'60a996d05190e2870b8a1e9c6dd98a96d49e389c';

/// Kept alive: the Rent home is rebuilt every time the customer comes back from another tab.

abstract class _$RentalBrowse extends $Notifier<RentalBrowseFilter> {
  RentalBrowseFilter build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<RentalBrowseFilter, RentalBrowseFilter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<RentalBrowseFilter, RentalBrowseFilter>,
              RentalBrowseFilter,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The shared location's districts, sorted — a stable key for the lists below.

@ProviderFor(rentalDistrictIds)
final rentalDistrictIdsProvider = RentalDistrictIdsProvider._();

/// The shared location's districts, sorted — a stable key for the lists below.

final class RentalDistrictIdsProvider
    extends $FunctionalProvider<List<String>, List<String>, List<String>>
    with $Provider<List<String>> {
  /// The shared location's districts, sorted — a stable key for the lists below.
  RentalDistrictIdsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rentalDistrictIdsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rentalDistrictIdsHash();

  @$internal
  @override
  $ProviderElement<List<String>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<String> create(Ref ref) {
    return rentalDistrictIds(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<String>>(value),
    );
  }
}

String _$rentalDistrictIdsHash() => r'1266f5a53497cb741ac3b7ec7fc791dd3d68009e';

/// The Rent home for the current shuffle and location.

@ProviderFor(rentalHome)
final rentalHomeProvider = RentalHomeProvider._();

/// The Rent home for the current shuffle and location.

final class RentalHomeProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RentalHomeSection>>,
          List<RentalHomeSection>,
          FutureOr<List<RentalHomeSection>>
        >
    with
        $FutureModifier<List<RentalHomeSection>>,
        $FutureProvider<List<RentalHomeSection>> {
  /// The Rent home for the current shuffle and location.
  RentalHomeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rentalHomeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rentalHomeHash();

  @$internal
  @override
  $FutureProviderElement<List<RentalHomeSection>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RentalHomeSection>> create(Ref ref) {
    return rentalHome(ref);
  }
}

String _$rentalHomeHash() => r'b868dc710307b3b1834c0be28515dfc5621c30a7';

/// The featured items at the top of the Rent home — the same all day, others tomorrow.

@ProviderFor(rentalBanners)
final rentalBannersProvider = RentalBannersProvider._();

/// The featured items at the top of the Rent home — the same all day, others tomorrow.

final class RentalBannersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RentalCard>>,
          List<RentalCard>,
          FutureOr<List<RentalCard>>
        >
    with $FutureModifier<List<RentalCard>>, $FutureProvider<List<RentalCard>> {
  /// The featured items at the top of the Rent home — the same all day, others tomorrow.
  RentalBannersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rentalBannersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rentalBannersHash();

  @$internal
  @override
  $FutureProviderElement<List<RentalCard>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RentalCard>> create(Ref ref) {
    return rentalBanners(ref);
  }
}

String _$rentalBannersHash() => r'4617662fb00d6e5e4a3971fe9328fe6c0d690b99';

/// What matches the category and words the customer chose, near them.

@ProviderFor(rentalSearch)
final rentalSearchProvider = RentalSearchProvider._();

/// What matches the category and words the customer chose, near them.

final class RentalSearchProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RentalCard>>,
          List<RentalCard>,
          FutureOr<List<RentalCard>>
        >
    with $FutureModifier<List<RentalCard>>, $FutureProvider<List<RentalCard>> {
  /// What matches the category and words the customer chose, near them.
  RentalSearchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rentalSearchProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rentalSearchHash();

  @$internal
  @override
  $FutureProviderElement<List<RentalCard>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RentalCard>> create(Ref ref) {
    return rentalSearch(ref);
  }
}

String _$rentalSearchHash() => r'a37b32692675c4327f86de4bbb930af19469d1f1';

/// One rent item as a customer opens it.

@ProviderFor(rentalItemDetail)
final rentalItemDetailProvider = RentalItemDetailFamily._();

/// One rent item as a customer opens it.

final class RentalItemDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<RentalItemDetail>,
          RentalItemDetail,
          FutureOr<RentalItemDetail>
        >
    with $FutureModifier<RentalItemDetail>, $FutureProvider<RentalItemDetail> {
  /// One rent item as a customer opens it.
  RentalItemDetailProvider._({
    required RentalItemDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'rentalItemDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$rentalItemDetailHash();

  @override
  String toString() {
    return r'rentalItemDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<RentalItemDetail> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<RentalItemDetail> create(Ref ref) {
    final argument = this.argument as String;
    return rentalItemDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RentalItemDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$rentalItemDetailHash() => r'6c57696adaf0a37adc5409c7f37cdc51cfd081d7';

/// One rent item as a customer opens it.

final class RentalItemDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<RentalItemDetail>, String> {
  RentalItemDetailFamily._()
    : super(
        retry: null,
        name: r'rentalItemDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One rent item as a customer opens it.

  RentalItemDetailProvider call(String id) =>
      RentalItemDetailProvider._(argument: id, from: this);

  @override
  String toString() => r'rentalItemDetailProvider';
}

/// "Recommended rentals near you": what can be rented in the customer's own district — set up on
/// first open and kept in their account. Not the search filter. Empty when no location is set.

@ProviderFor(rentalRecommended)
final rentalRecommendedProvider = RentalRecommendedProvider._();

/// "Recommended rentals near you": what can be rented in the customer's own district — set up on
/// first open and kept in their account. Not the search filter. Empty when no location is set.

final class RentalRecommendedProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RentalCard>>,
          List<RentalCard>,
          FutureOr<List<RentalCard>>
        >
    with $FutureModifier<List<RentalCard>>, $FutureProvider<List<RentalCard>> {
  /// "Recommended rentals near you": what can be rented in the customer's own district — set up on
  /// first open and kept in their account. Not the search filter. Empty when no location is set.
  RentalRecommendedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rentalRecommendedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rentalRecommendedHash();

  @$internal
  @override
  $FutureProviderElement<List<RentalCard>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RentalCard>> create(Ref ref) {
    return rentalRecommended(ref);
  }
}

String _$rentalRecommendedHash() => r'2ee4fae71a3e4c30d29fbf7616d32e5a1f9074e7';
