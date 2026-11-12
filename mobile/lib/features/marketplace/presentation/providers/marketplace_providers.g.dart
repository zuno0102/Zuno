// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'marketplace_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's usual client, pointed at the Marketplace service. Same interceptors, and the very
/// same [authInterceptorProvider], so Marketplace shares the login and its one token refresh.

@ProviderFor(marketplaceDio)
final marketplaceDioProvider = MarketplaceDioProvider._();

/// The app's usual client, pointed at the Marketplace service. Same interceptors, and the very
/// same [authInterceptorProvider], so Marketplace shares the login and its one token refresh.

final class MarketplaceDioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  /// The app's usual client, pointed at the Marketplace service. Same interceptors, and the very
  /// same [authInterceptorProvider], so Marketplace shares the login and its one token refresh.
  MarketplaceDioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'marketplaceDioProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$marketplaceDioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return marketplaceDio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$marketplaceDioHash() => r'13f0fd3fe408e17813671280031ee41429862289';

@ProviderFor(marketplaceRepository)
final marketplaceRepositoryProvider = MarketplaceRepositoryProvider._();

final class MarketplaceRepositoryProvider
    extends
        $FunctionalProvider<
          MarketplaceRepository,
          MarketplaceRepository,
          MarketplaceRepository
        >
    with $Provider<MarketplaceRepository> {
  MarketplaceRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'marketplaceRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$marketplaceRepositoryHash();

  @$internal
  @override
  $ProviderElement<MarketplaceRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MarketplaceRepository create(Ref ref) {
    return marketplaceRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MarketplaceRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MarketplaceRepository>(value),
    );
  }
}

String _$marketplaceRepositoryHash() =>
    r'1d397ebe41931ef15b4af61f39cfb41fed90d134';

/// Where the business is, as a district — where its products are said to be, so the form does not
/// ask. From its registered pin; else its town and state matched by name; null when neither does,
/// and the form then asks for the district.

@ProviderFor(marketplaceBusinessDistrict)
final marketplaceBusinessDistrictProvider =
    MarketplaceBusinessDistrictProvider._();

/// Where the business is, as a district — where its products are said to be, so the form does not
/// ask. From its registered pin; else its town and state matched by name; null when neither does,
/// and the form then asks for the district.

final class MarketplaceBusinessDistrictProvider
    extends
        $FunctionalProvider<
          AsyncValue<District?>,
          District?,
          FutureOr<District?>
        >
    with $FutureModifier<District?>, $FutureProvider<District?> {
  /// Where the business is, as a district — where its products are said to be, so the form does not
  /// ask. From its registered pin; else its town and state matched by name; null when neither does,
  /// and the form then asks for the district.
  MarketplaceBusinessDistrictProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'marketplaceBusinessDistrictProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$marketplaceBusinessDistrictHash();

  @$internal
  @override
  $FutureProviderElement<District?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<District?> create(Ref ref) {
    return marketplaceBusinessDistrict(ref);
  }
}

String _$marketplaceBusinessDistrictHash() =>
    r'ab7b540c36c79574f47fe6e838d11f4bf4117dbb';

/// The categories a business can post in, with their details. The server caches them too. Kept
/// for the session — they change only when the super admin edits them, which reloads them — so
/// opening a Marketplace screen again costs no request.

@ProviderFor(marketplaceCategories)
final marketplaceCategoriesProvider = MarketplaceCategoriesProvider._();

/// The categories a business can post in, with their details. The server caches them too. Kept
/// for the session — they change only when the super admin edits them, which reloads them — so
/// opening a Marketplace screen again costs no request.

final class MarketplaceCategoriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MarketplaceCategory>>,
          List<MarketplaceCategory>,
          FutureOr<List<MarketplaceCategory>>
        >
    with
        $FutureModifier<List<MarketplaceCategory>>,
        $FutureProvider<List<MarketplaceCategory>> {
  /// The categories a business can post in, with their details. The server caches them too. Kept
  /// for the session — they change only when the super admin edits them, which reloads them — so
  /// opening a Marketplace screen again costs no request.
  MarketplaceCategoriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'marketplaceCategoriesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$marketplaceCategoriesHash();

  @$internal
  @override
  $FutureProviderElement<List<MarketplaceCategory>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MarketplaceCategory>> create(Ref ref) {
    return marketplaceCategories(ref);
  }
}

String _$marketplaceCategoriesHash() =>
    r'723100ee63b84ecb0f4c3ddb57033c1e18eefcfd';

/// The post kinds, statuses (with colours) and limits, from the server's tables.

@ProviderFor(marketplaceOptions)
final marketplaceOptionsProvider = MarketplaceOptionsProvider._();

/// The post kinds, statuses (with colours) and limits, from the server's tables.

final class MarketplaceOptionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<MarketplaceOptions>,
          MarketplaceOptions,
          FutureOr<MarketplaceOptions>
        >
    with
        $FutureModifier<MarketplaceOptions>,
        $FutureProvider<MarketplaceOptions> {
  /// The post kinds, statuses (with colours) and limits, from the server's tables.
  MarketplaceOptionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'marketplaceOptionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$marketplaceOptionsHash();

  @$internal
  @override
  $FutureProviderElement<MarketplaceOptions> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MarketplaceOptions> create(Ref ref) {
    return marketplaceOptions(ref);
  }
}

String _$marketplaceOptionsHash() =>
    r'419f8a5ec00731651f8875fd14e7dab666cf54f7';

/// The counts behind the Marketplace tiles, and the plan banner.

@ProviderFor(marketplaceSummary)
final marketplaceSummaryProvider = MarketplaceSummaryProvider._();

/// The counts behind the Marketplace tiles, and the plan banner.

final class MarketplaceSummaryProvider
    extends
        $FunctionalProvider<
          AsyncValue<MarketplaceSummary>,
          MarketplaceSummary,
          FutureOr<MarketplaceSummary>
        >
    with
        $FutureModifier<MarketplaceSummary>,
        $FutureProvider<MarketplaceSummary> {
  /// The counts behind the Marketplace tiles, and the plan banner.
  MarketplaceSummaryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'marketplaceSummaryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$marketplaceSummaryHash();

  @$internal
  @override
  $FutureProviderElement<MarketplaceSummary> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MarketplaceSummary> create(Ref ref) {
    return marketplaceSummary(ref);
  }
}

String _$marketplaceSummaryHash() =>
    r'bd2fc1382479d012fb1cf883588d1065c3047100';

/// The business's posts; [categoryId] (a main category) and [status] narrow the list (null for all).
///
/// Loading the full list also refreshes how customers see the business (name, verified) — in the
/// background, so a slow or failed refresh never holds up the business's own list.

@ProviderFor(businessMarketplacePosts)
final businessMarketplacePostsProvider = BusinessMarketplacePostsFamily._();

/// The business's posts; [categoryId] (a main category) and [status] narrow the list (null for all).
///
/// Loading the full list also refreshes how customers see the business (name, verified) — in the
/// background, so a slow or failed refresh never holds up the business's own list.

final class BusinessMarketplacePostsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MarketplacePost>>,
          List<MarketplacePost>,
          FutureOr<List<MarketplacePost>>
        >
    with
        $FutureModifier<List<MarketplacePost>>,
        $FutureProvider<List<MarketplacePost>> {
  /// The business's posts; [categoryId] (a main category) and [status] narrow the list (null for all).
  ///
  /// Loading the full list also refreshes how customers see the business (name, verified) — in the
  /// background, so a slow or failed refresh never holds up the business's own list.
  BusinessMarketplacePostsProvider._({
    required BusinessMarketplacePostsFamily super.from,
    required ({String? categoryId, String? status}) super.argument,
  }) : super(
         retry: null,
         name: r'businessMarketplacePostsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$businessMarketplacePostsHash();

  @override
  String toString() {
    return r'businessMarketplacePostsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<MarketplacePost>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MarketplacePost>> create(Ref ref) {
    final argument = this.argument as ({String? categoryId, String? status});
    return businessMarketplacePosts(
      ref,
      categoryId: argument.categoryId,
      status: argument.status,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BusinessMarketplacePostsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$businessMarketplacePostsHash() =>
    r'3e1537caf7f322f2bb8591dd2f7e875d5f765b14';

/// The business's posts; [categoryId] (a main category) and [status] narrow the list (null for all).
///
/// Loading the full list also refreshes how customers see the business (name, verified) — in the
/// background, so a slow or failed refresh never holds up the business's own list.

final class BusinessMarketplacePostsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<MarketplacePost>>,
          ({String? categoryId, String? status})
        > {
  BusinessMarketplacePostsFamily._()
    : super(
        retry: null,
        name: r'businessMarketplacePostsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The business's posts; [categoryId] (a main category) and [status] narrow the list (null for all).
  ///
  /// Loading the full list also refreshes how customers see the business (name, verified) — in the
  /// background, so a slow or failed refresh never holds up the business's own list.

  BusinessMarketplacePostsProvider call({String? categoryId, String? status}) =>
      BusinessMarketplacePostsProvider._(
        argument: (categoryId: categoryId, status: status),
        from: this,
      );

  @override
  String toString() => r'businessMarketplacePostsProvider';
}

/// The super admin's categories: every one, switched off or not.

@ProviderFor(adminMarketplaceCategories)
final adminMarketplaceCategoriesProvider =
    AdminMarketplaceCategoriesProvider._();

/// The super admin's categories: every one, switched off or not.

final class AdminMarketplaceCategoriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MarketplaceCategory>>,
          List<MarketplaceCategory>,
          FutureOr<List<MarketplaceCategory>>
        >
    with
        $FutureModifier<List<MarketplaceCategory>>,
        $FutureProvider<List<MarketplaceCategory>> {
  /// The super admin's categories: every one, switched off or not.
  AdminMarketplaceCategoriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'adminMarketplaceCategoriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$adminMarketplaceCategoriesHash();

  @$internal
  @override
  $FutureProviderElement<List<MarketplaceCategory>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MarketplaceCategory>> create(Ref ref) {
    return adminMarketplaceCategories(ref);
  }
}

String _$adminMarketplaceCategoriesHash() =>
    r'68c5ffc82509b98db9f33dd8c23d74719426062b';
