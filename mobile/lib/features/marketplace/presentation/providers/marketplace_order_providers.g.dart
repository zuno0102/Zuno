// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'marketplace_order_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(marketplaceOrderRepository)
final marketplaceOrderRepositoryProvider =
    MarketplaceOrderRepositoryProvider._();

final class MarketplaceOrderRepositoryProvider
    extends
        $FunctionalProvider<
          MarketplaceOrderRepository,
          MarketplaceOrderRepository,
          MarketplaceOrderRepository
        >
    with $Provider<MarketplaceOrderRepository> {
  MarketplaceOrderRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'marketplaceOrderRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$marketplaceOrderRepositoryHash();

  @$internal
  @override
  $ProviderElement<MarketplaceOrderRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MarketplaceOrderRepository create(Ref ref) {
    return marketplaceOrderRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MarketplaceOrderRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MarketplaceOrderRepository>(value),
    );
  }
}

String _$marketplaceOrderRepositoryHash() =>
    r'6ff12fbe34dd2716aab76944e0904fe0d8d4eabf';

/// The business's product orders narrowed to [status] (null for all), with every status's count.

@ProviderFor(businessMarketplaceOrders)
final businessMarketplaceOrdersProvider = BusinessMarketplaceOrdersFamily._();

/// The business's product orders narrowed to [status] (null for all), with every status's count.

final class BusinessMarketplaceOrdersProvider
    extends
        $FunctionalProvider<
          AsyncValue<MarketplaceOrderPage>,
          MarketplaceOrderPage,
          FutureOr<MarketplaceOrderPage>
        >
    with
        $FutureModifier<MarketplaceOrderPage>,
        $FutureProvider<MarketplaceOrderPage> {
  /// The business's product orders narrowed to [status] (null for all), with every status's count.
  BusinessMarketplaceOrdersProvider._({
    required BusinessMarketplaceOrdersFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'businessMarketplaceOrdersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$businessMarketplaceOrdersHash();

  @override
  String toString() {
    return r'businessMarketplaceOrdersProvider'
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
    return businessMarketplaceOrders(ref, status: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BusinessMarketplaceOrdersProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$businessMarketplaceOrdersHash() =>
    r'8483805ef69b94a3aa41fb12c214ac81ad1cd7b0';

/// The business's product orders narrowed to [status] (null for all), with every status's count.

final class BusinessMarketplaceOrdersFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<MarketplaceOrderPage>, String?> {
  BusinessMarketplaceOrdersFamily._()
    : super(
        retry: null,
        name: r'businessMarketplaceOrdersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The business's product orders narrowed to [status] (null for all), with every status's count.

  BusinessMarketplaceOrdersProvider call({String? status}) =>
      BusinessMarketplaceOrdersProvider._(argument: status, from: this);

  @override
  String toString() => r'businessMarketplaceOrdersProvider';
}

/// One order with its history, for its own page.

@ProviderFor(businessMarketplaceOrder)
final businessMarketplaceOrderProvider = BusinessMarketplaceOrderFamily._();

/// One order with its history, for its own page.

final class BusinessMarketplaceOrderProvider
    extends
        $FunctionalProvider<
          AsyncValue<MarketplaceOrder>,
          MarketplaceOrder,
          FutureOr<MarketplaceOrder>
        >
    with $FutureModifier<MarketplaceOrder>, $FutureProvider<MarketplaceOrder> {
  /// One order with its history, for its own page.
  BusinessMarketplaceOrderProvider._({
    required BusinessMarketplaceOrderFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'businessMarketplaceOrderProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$businessMarketplaceOrderHash();

  @override
  String toString() {
    return r'businessMarketplaceOrderProvider'
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
    return businessMarketplaceOrder(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BusinessMarketplaceOrderProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$businessMarketplaceOrderHash() =>
    r'6a094c7fdfdd32b91bb61966f820556fb16b1f7f';

/// One order with its history, for its own page.

final class BusinessMarketplaceOrderFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<MarketplaceOrder>, String> {
  BusinessMarketplaceOrderFamily._()
    : super(
        retry: null,
        name: r'businessMarketplaceOrderProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One order with its history, for its own page.

  BusinessMarketplaceOrderProvider call(String id) =>
      BusinessMarketplaceOrderProvider._(argument: id, from: this);

  @override
  String toString() => r'businessMarketplaceOrderProvider';
}

/// The B2B requests on the business's lots narrowed to [status], with every status's count.

@ProviderFor(businessB2BRequests)
final businessB2BRequestsProvider = BusinessB2BRequestsFamily._();

/// The B2B requests on the business's lots narrowed to [status], with every status's count.

final class BusinessB2BRequestsProvider
    extends
        $FunctionalProvider<
          AsyncValue<MarketplaceB2BRequestPage>,
          MarketplaceB2BRequestPage,
          FutureOr<MarketplaceB2BRequestPage>
        >
    with
        $FutureModifier<MarketplaceB2BRequestPage>,
        $FutureProvider<MarketplaceB2BRequestPage> {
  /// The B2B requests on the business's lots narrowed to [status], with every status's count.
  BusinessB2BRequestsProvider._({
    required BusinessB2BRequestsFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'businessB2BRequestsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$businessB2BRequestsHash();

  @override
  String toString() {
    return r'businessB2BRequestsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<MarketplaceB2BRequestPage> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MarketplaceB2BRequestPage> create(Ref ref) {
    final argument = this.argument as String?;
    return businessB2BRequests(ref, status: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BusinessB2BRequestsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$businessB2BRequestsHash() =>
    r'02b07ba76b4e9abb223f8c25213b6d9670eb5e75';

/// The B2B requests on the business's lots narrowed to [status], with every status's count.

final class BusinessB2BRequestsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<MarketplaceB2BRequestPage>,
          String?
        > {
  BusinessB2BRequestsFamily._()
    : super(
        retry: null,
        name: r'businessB2BRequestsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The B2B requests on the business's lots narrowed to [status], with every status's count.

  BusinessB2BRequestsProvider call({String? status}) =>
      BusinessB2BRequestsProvider._(argument: status, from: this);

  @override
  String toString() => r'businessB2BRequestsProvider';
}

@ProviderFor(marketplacePaymentSettings)
final marketplacePaymentSettingsProvider =
    MarketplacePaymentSettingsProvider._();

final class MarketplacePaymentSettingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<MarketplacePaymentSettings>,
          MarketplacePaymentSettings,
          FutureOr<MarketplacePaymentSettings>
        >
    with
        $FutureModifier<MarketplacePaymentSettings>,
        $FutureProvider<MarketplacePaymentSettings> {
  MarketplacePaymentSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'marketplacePaymentSettingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$marketplacePaymentSettingsHash();

  @$internal
  @override
  $FutureProviderElement<MarketplacePaymentSettings> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MarketplacePaymentSettings> create(Ref ref) {
    return marketplacePaymentSettings(ref);
  }
}

String _$marketplacePaymentSettingsHash() =>
    r'9e1789e66004e6d189145590e5ecb62c4842fcac';
