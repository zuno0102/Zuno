// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'marketplace_customer_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(marketplaceCustomerRepository)
final marketplaceCustomerRepositoryProvider =
    MarketplaceCustomerRepositoryProvider._();

final class MarketplaceCustomerRepositoryProvider
    extends
        $FunctionalProvider<
          MarketplaceCustomerRepository,
          MarketplaceCustomerRepository,
          MarketplaceCustomerRepository
        >
    with $Provider<MarketplaceCustomerRepository> {
  MarketplaceCustomerRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'marketplaceCustomerRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$marketplaceCustomerRepositoryHash();

  @$internal
  @override
  $ProviderElement<MarketplaceCustomerRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MarketplaceCustomerRepository create(Ref ref) {
    return marketplaceCustomerRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MarketplaceCustomerRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MarketplaceCustomerRepository>(
        value,
      ),
    );
  }
}

String _$marketplaceCustomerRepositoryHash() =>
    r'ebc61089b5af81cf5a1b902cbb288b4d7723d018';

/// The customer's district — food offers and adverts are local, so the home keeps them to it.
/// Products and B2B lots show everywhere.

@ProviderFor(marketplaceHome)
final marketplaceHomeProvider = MarketplaceHomeProvider._();

/// The customer's district — food offers and adverts are local, so the home keeps them to it.
/// Products and B2B lots show everywhere.

final class MarketplaceHomeProvider
    extends
        $FunctionalProvider<
          AsyncValue<MarketplaceHome>,
          MarketplaceHome,
          FutureOr<MarketplaceHome>
        >
    with $FutureModifier<MarketplaceHome>, $FutureProvider<MarketplaceHome> {
  /// The customer's district — food offers and adverts are local, so the home keeps them to it.
  /// Products and B2B lots show everywhere.
  MarketplaceHomeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'marketplaceHomeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$marketplaceHomeHash();

  @$internal
  @override
  $FutureProviderElement<MarketplaceHome> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MarketplaceHome> create(Ref ref) {
    return marketplaceHome(ref);
  }
}

String _$marketplaceHomeHash() => r'063f2ce44db77d38a358b364955b99ded59d49c3';

/// "All products" at the foot of the home — products and B2B lots from everywhere, food in the
/// customer's district — a page of [pageSize] at a time as they scroll.

@ProviderFor(MarketplaceFeedNotifier)
final marketplaceFeedProvider = MarketplaceFeedNotifierFamily._();

/// "All products" at the foot of the home — products and B2B lots from everywhere, food in the
/// customer's district — a page of [pageSize] at a time as they scroll.
final class MarketplaceFeedNotifierProvider
    extends $AsyncNotifierProvider<MarketplaceFeedNotifier, MarketplaceFeed> {
  /// "All products" at the foot of the home — products and B2B lots from everywhere, food in the
  /// customer's district — a page of [pageSize] at a time as they scroll.
  MarketplaceFeedNotifierProvider._({
    required MarketplaceFeedNotifierFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'marketplaceFeedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$marketplaceFeedNotifierHash();

  @override
  String toString() {
    return r'marketplaceFeedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MarketplaceFeedNotifier create() => MarketplaceFeedNotifier();

  @override
  bool operator ==(Object other) {
    return other is MarketplaceFeedNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$marketplaceFeedNotifierHash() =>
    r'135821ec055e6e4bb47c967a653e1c89c7860a13';

/// "All products" at the foot of the home — products and B2B lots from everywhere, food in the
/// customer's district — a page of [pageSize] at a time as they scroll.

final class MarketplaceFeedNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          MarketplaceFeedNotifier,
          AsyncValue<MarketplaceFeed>,
          MarketplaceFeed,
          FutureOr<MarketplaceFeed>,
          int
        > {
  MarketplaceFeedNotifierFamily._()
    : super(
        retry: null,
        name: r'marketplaceFeedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// "All products" at the foot of the home — products and B2B lots from everywhere, food in the
  /// customer's district — a page of [pageSize] at a time as they scroll.

  MarketplaceFeedNotifierProvider call(int pageSize) =>
      MarketplaceFeedNotifierProvider._(argument: pageSize, from: this);

  @override
  String toString() => r'marketplaceFeedProvider';
}

/// "All products" at the foot of the home — products and B2B lots from everywhere, food in the
/// customer's district — a page of [pageSize] at a time as they scroll.

abstract class _$MarketplaceFeedNotifier
    extends $AsyncNotifier<MarketplaceFeed> {
  late final _$args = ref.$arg as int;
  int get pageSize => _$args;

  FutureOr<MarketplaceFeed> build(int pageSize);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<MarketplaceFeed>, MarketplaceFeed>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<MarketplaceFeed>, MarketplaceFeed>,
              AsyncValue<MarketplaceFeed>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// The first page of matching posts — products, food, adverts and B2B lots alike.

@ProviderFor(marketplaceSearch)
final marketplaceSearchProvider = MarketplaceSearchFamily._();

/// The first page of matching posts — products, food, adverts and B2B lots alike.

final class MarketplaceSearchProvider
    extends
        $FunctionalProvider<
          AsyncValue<MarketplaceCardPage>,
          MarketplaceCardPage,
          FutureOr<MarketplaceCardPage>
        >
    with
        $FutureModifier<MarketplaceCardPage>,
        $FutureProvider<MarketplaceCardPage> {
  /// The first page of matching posts — products, food, adverts and B2B lots alike.
  MarketplaceSearchProvider._({
    required MarketplaceSearchFamily super.from,
    required MarketplaceSearchQuery super.argument,
  }) : super(
         retry: null,
         name: r'marketplaceSearchProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$marketplaceSearchHash();

  @override
  String toString() {
    return r'marketplaceSearchProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<MarketplaceCardPage> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MarketplaceCardPage> create(Ref ref) {
    final argument = this.argument as MarketplaceSearchQuery;
    return marketplaceSearch(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MarketplaceSearchProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$marketplaceSearchHash() => r'8a639eda067bf73e1b961d942d5ddc7d61772b8c';

/// The first page of matching posts — products, food, adverts and B2B lots alike.

final class MarketplaceSearchFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<MarketplaceCardPage>,
          MarketplaceSearchQuery
        > {
  MarketplaceSearchFamily._()
    : super(
        retry: null,
        name: r'marketplaceSearchProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The first page of matching posts — products, food, adverts and B2B lots alike.

  MarketplaceSearchProvider call(MarketplaceSearchQuery query) =>
      MarketplaceSearchProvider._(argument: query, from: this);

  @override
  String toString() => r'marketplaceSearchProvider';
}

/// A post as the customer opens it.

@ProviderFor(marketplacePost)
final marketplacePostProvider = MarketplacePostFamily._();

/// A post as the customer opens it.

final class MarketplacePostProvider
    extends
        $FunctionalProvider<
          AsyncValue<MarketplacePostDetail>,
          MarketplacePostDetail,
          FutureOr<MarketplacePostDetail>
        >
    with
        $FutureModifier<MarketplacePostDetail>,
        $FutureProvider<MarketplacePostDetail> {
  /// A post as the customer opens it.
  MarketplacePostProvider._({
    required MarketplacePostFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'marketplacePostProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$marketplacePostHash();

  @override
  String toString() {
    return r'marketplacePostProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<MarketplacePostDetail> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MarketplacePostDetail> create(Ref ref) {
    final argument = this.argument as String;
    return marketplacePost(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MarketplacePostProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$marketplacePostHash() => r'251f0164a64209780cbec9216b965a1529f5794e';

/// A post as the customer opens it.

final class MarketplacePostFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<MarketplacePostDetail>, String> {
  MarketplacePostFamily._()
    : super(
        retry: null,
        name: r'marketplacePostProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A post as the customer opens it.

  MarketplacePostProvider call(String id) =>
      MarketplacePostProvider._(argument: id, from: this);

  @override
  String toString() => r'marketplacePostProvider';
}

@ProviderFor(marketplaceFavourites)
final marketplaceFavouritesProvider = MarketplaceFavouritesProvider._();

final class MarketplaceFavouritesProvider
    extends
        $FunctionalProvider<
          AsyncValue<MarketplaceCardPage>,
          MarketplaceCardPage,
          FutureOr<MarketplaceCardPage>
        >
    with
        $FutureModifier<MarketplaceCardPage>,
        $FutureProvider<MarketplaceCardPage> {
  MarketplaceFavouritesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'marketplaceFavouritesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$marketplaceFavouritesHash();

  @$internal
  @override
  $FutureProviderElement<MarketplaceCardPage> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MarketplaceCardPage> create(Ref ref) {
    return marketplaceFavourites(ref);
  }
}

String _$marketplaceFavouritesHash() =>
    r'60de5b08b5b30fcee1cb24d5a8de418e24e4e246';

/// The hearts the customer tapped this session, ahead of the server: a tap shows at once, and goes
/// back if the server refuses it. Cards read [isSaved] with the server's own answer as the fallback.

@ProviderFor(MarketplaceSavedPosts)
final marketplaceSavedPostsProvider = MarketplaceSavedPostsProvider._();

/// The hearts the customer tapped this session, ahead of the server: a tap shows at once, and goes
/// back if the server refuses it. Cards read [isSaved] with the server's own answer as the fallback.
final class MarketplaceSavedPostsProvider
    extends $NotifierProvider<MarketplaceSavedPosts, Map<String, bool>> {
  /// The hearts the customer tapped this session, ahead of the server: a tap shows at once, and goes
  /// back if the server refuses it. Cards read [isSaved] with the server's own answer as the fallback.
  MarketplaceSavedPostsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'marketplaceSavedPostsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$marketplaceSavedPostsHash();

  @$internal
  @override
  MarketplaceSavedPosts create() => MarketplaceSavedPosts();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, bool> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, bool>>(value),
    );
  }
}

String _$marketplaceSavedPostsHash() =>
    r'3e8021158fe7021407913062b57055038351d092';

/// The hearts the customer tapped this session, ahead of the server: a tap shows at once, and goes
/// back if the server refuses it. Cards read [isSaved] with the server's own answer as the fallback.

abstract class _$MarketplaceSavedPosts extends $Notifier<Map<String, bool>> {
  Map<String, bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Map<String, bool>, Map<String, bool>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<String, bool>, Map<String, bool>>,
              Map<String, bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The customer's product orders narrowed to [status], with a chip per status they have.

@ProviderFor(myMarketplaceOrders)
final myMarketplaceOrdersProvider = MyMarketplaceOrdersFamily._();

/// The customer's product orders narrowed to [status], with a chip per status they have.

final class MyMarketplaceOrdersProvider
    extends
        $FunctionalProvider<
          AsyncValue<MarketplaceOrderPage>,
          MarketplaceOrderPage,
          FutureOr<MarketplaceOrderPage>
        >
    with
        $FutureModifier<MarketplaceOrderPage>,
        $FutureProvider<MarketplaceOrderPage> {
  /// The customer's product orders narrowed to [status], with a chip per status they have.
  MyMarketplaceOrdersProvider._({
    required MyMarketplaceOrdersFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'myMarketplaceOrdersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$myMarketplaceOrdersHash();

  @override
  String toString() {
    return r'myMarketplaceOrdersProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<MarketplaceOrderPage> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MarketplaceOrderPage> create(Ref ref) {
    final argument = this.argument as String?;
    return myMarketplaceOrders(ref, status: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MyMarketplaceOrdersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$myMarketplaceOrdersHash() =>
    r'7bb87036634a0ca06a7e22873fa42822e7c2c271';

/// The customer's product orders narrowed to [status], with a chip per status they have.

final class MyMarketplaceOrdersFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<MarketplaceOrderPage>, String?> {
  MyMarketplaceOrdersFamily._()
    : super(
        retry: null,
        name: r'myMarketplaceOrdersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The customer's product orders narrowed to [status], with a chip per status they have.

  MyMarketplaceOrdersProvider call({String? status}) =>
      MyMarketplaceOrdersProvider._(argument: status, from: this);

  @override
  String toString() => r'myMarketplaceOrdersProvider';
}

/// One of the customer's orders, with its progress bar and history.

@ProviderFor(myMarketplaceOrder)
final myMarketplaceOrderProvider = MyMarketplaceOrderFamily._();

/// One of the customer's orders, with its progress bar and history.

final class MyMarketplaceOrderProvider
    extends
        $FunctionalProvider<
          AsyncValue<MarketplaceOrder>,
          MarketplaceOrder,
          FutureOr<MarketplaceOrder>
        >
    with $FutureModifier<MarketplaceOrder>, $FutureProvider<MarketplaceOrder> {
  /// One of the customer's orders, with its progress bar and history.
  MyMarketplaceOrderProvider._({
    required MyMarketplaceOrderFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'myMarketplaceOrderProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$myMarketplaceOrderHash();

  @override
  String toString() {
    return r'myMarketplaceOrderProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<MarketplaceOrder> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MarketplaceOrder> create(Ref ref) {
    final argument = this.argument as String;
    return myMarketplaceOrder(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MyMarketplaceOrderProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$myMarketplaceOrderHash() =>
    r'4ef99a2f65bb1bed2ea82240aef9bb0a0fad8e41';

/// One of the customer's orders, with its progress bar and history.

final class MyMarketplaceOrderFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<MarketplaceOrder>, String> {
  MyMarketplaceOrderFamily._()
    : super(
        retry: null,
        name: r'myMarketplaceOrderProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One of the customer's orders, with its progress bar and history.

  MyMarketplaceOrderProvider call(String id) =>
      MyMarketplaceOrderProvider._(argument: id, from: this);

  @override
  String toString() => r'myMarketplaceOrderProvider';
}

/// The B2B lots the customer asked for.

@ProviderFor(myMarketplaceRequests)
final myMarketplaceRequestsProvider = MyMarketplaceRequestsProvider._();

/// The B2B lots the customer asked for.

final class MyMarketplaceRequestsProvider
    extends
        $FunctionalProvider<
          AsyncValue<MarketplaceB2BRequestPage>,
          MarketplaceB2BRequestPage,
          FutureOr<MarketplaceB2BRequestPage>
        >
    with
        $FutureModifier<MarketplaceB2BRequestPage>,
        $FutureProvider<MarketplaceB2BRequestPage> {
  /// The B2B lots the customer asked for.
  MyMarketplaceRequestsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myMarketplaceRequestsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myMarketplaceRequestsHash();

  @$internal
  @override
  $FutureProviderElement<MarketplaceB2BRequestPage> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MarketplaceB2BRequestPage> create(Ref ref) {
    return myMarketplaceRequests(ref);
  }
}

String _$myMarketplaceRequestsHash() =>
    r'ccc39d9dc73aa18d70bb39ab4c52f8c8e4edb3ba';

@ProviderFor(marketplacePaymentWindow)
final marketplacePaymentWindowProvider = MarketplacePaymentWindowProvider._();

final class MarketplacePaymentWindowProvider
    extends
        $FunctionalProvider<
          MarketplacePaymentWindow,
          MarketplacePaymentWindow,
          MarketplacePaymentWindow
        >
    with $Provider<MarketplacePaymentWindow> {
  MarketplacePaymentWindowProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'marketplacePaymentWindowProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$marketplacePaymentWindowHash();

  @$internal
  @override
  $ProviderElement<MarketplacePaymentWindow> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MarketplacePaymentWindow create(Ref ref) {
    return marketplacePaymentWindow(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MarketplacePaymentWindow value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MarketplacePaymentWindow>(value),
    );
  }
}

String _$marketplacePaymentWindowHash() =>
    r'cf963c3a050243219905590395659c2b383da4e8';
