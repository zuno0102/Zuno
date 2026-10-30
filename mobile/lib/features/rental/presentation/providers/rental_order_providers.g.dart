// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rental_order_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The customer's side of the Rent server, on the same client and login as the business side.

@ProviderFor(rentalCustomerDataSource)
final rentalCustomerDataSourceProvider = RentalCustomerDataSourceProvider._();

/// The customer's side of the Rent server, on the same client and login as the business side.

final class RentalCustomerDataSourceProvider
    extends
        $FunctionalProvider<
          RentalCustomerRemoteDataSource,
          RentalCustomerRemoteDataSource,
          RentalCustomerRemoteDataSource
        >
    with $Provider<RentalCustomerRemoteDataSource> {
  /// The customer's side of the Rent server, on the same client and login as the business side.
  RentalCustomerDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rentalCustomerDataSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rentalCustomerDataSourceHash();

  @$internal
  @override
  $ProviderElement<RentalCustomerRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RentalCustomerRemoteDataSource create(Ref ref) {
    return rentalCustomerDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RentalCustomerRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RentalCustomerRemoteDataSource>(
        value,
      ),
    );
  }
}

String _$rentalCustomerDataSourceHash() =>
    r'6fad48daf00fc03531c6ee3f80d26a46dbf9e370';

@ProviderFor(rentalCustomerRepository)
final rentalCustomerRepositoryProvider = RentalCustomerRepositoryProvider._();

final class RentalCustomerRepositoryProvider
    extends
        $FunctionalProvider<
          RentalCustomerRepository,
          RentalCustomerRepository,
          RentalCustomerRepository
        >
    with $Provider<RentalCustomerRepository> {
  RentalCustomerRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rentalCustomerRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rentalCustomerRepositoryHash();

  @$internal
  @override
  $ProviderElement<RentalCustomerRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RentalCustomerRepository create(Ref ref) {
    return rentalCustomerRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RentalCustomerRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RentalCustomerRepository>(value),
    );
  }
}

String _$rentalCustomerRepositoryHash() =>
    r'0aaf31d9c981d1b5eec0a1c3fbe9537946759d83';

/// The order screens' data for one side — the business's orders, or the customer's.

@ProviderFor(rentalOrdersGateway)
final rentalOrdersGatewayProvider = RentalOrdersGatewayFamily._();

/// The order screens' data for one side — the business's orders, or the customer's.

final class RentalOrdersGatewayProvider
    extends
        $FunctionalProvider<
          RentalOrdersGateway,
          RentalOrdersGateway,
          RentalOrdersGateway
        >
    with $Provider<RentalOrdersGateway> {
  /// The order screens' data for one side — the business's orders, or the customer's.
  RentalOrdersGatewayProvider._({
    required RentalOrdersGatewayFamily super.from,
    required RentalAudience super.argument,
  }) : super(
         retry: null,
         name: r'rentalOrdersGatewayProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$rentalOrdersGatewayHash();

  @override
  String toString() {
    return r'rentalOrdersGatewayProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<RentalOrdersGateway> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RentalOrdersGateway create(Ref ref) {
    final argument = this.argument as RentalAudience;
    return rentalOrdersGateway(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RentalOrdersGateway value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RentalOrdersGateway>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RentalOrdersGatewayProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$rentalOrdersGatewayHash() =>
    r'5579eb076a8672a1558b3965c33e4b50a994d2ed';

/// The order screens' data for one side — the business's orders, or the customer's.

final class RentalOrdersGatewayFamily extends $Family
    with $FunctionalFamilyOverride<RentalOrdersGateway, RentalAudience> {
  RentalOrdersGatewayFamily._()
    : super(
        retry: null,
        name: r'rentalOrdersGatewayProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// The order screens' data for one side — the business's orders, or the customer's.

  RentalOrdersGatewayProvider call(RentalAudience audience) =>
      RentalOrdersGatewayProvider._(argument: audience, from: this);

  @override
  String toString() => r'rentalOrdersGatewayProvider';
}

/// One side's rent orders, newest first; one status only when [status] is given.

@ProviderFor(rentalOrders)
final rentalOrdersProvider = RentalOrdersFamily._();

/// One side's rent orders, newest first; one status only when [status] is given.

final class RentalOrdersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RentalOrder>>,
          List<RentalOrder>,
          FutureOr<List<RentalOrder>>
        >
    with
        $FutureModifier<List<RentalOrder>>,
        $FutureProvider<List<RentalOrder>> {
  /// One side's rent orders, newest first; one status only when [status] is given.
  RentalOrdersProvider._({
    required RentalOrdersFamily super.from,
    required (String?, RentalAudience) super.argument,
  }) : super(
         retry: null,
         name: r'rentalOrdersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$rentalOrdersHash();

  @override
  String toString() {
    return r'rentalOrdersProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<RentalOrder>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RentalOrder>> create(Ref ref) {
    final argument = this.argument as (String?, RentalAudience);
    return rentalOrders(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is RentalOrdersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$rentalOrdersHash() => r'825810397e57b3a7ddb875eeaba6a7455aa58cd8';

/// One side's rent orders, newest first; one status only when [status] is given.

final class RentalOrdersFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<RentalOrder>>,
          (String?, RentalAudience)
        > {
  RentalOrdersFamily._()
    : super(
        retry: null,
        name: r'rentalOrdersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One side's rent orders, newest first; one status only when [status] is given.

  RentalOrdersProvider call(
    String? status, [
    RentalAudience audience = RentalAudience.business,
  ]) => RentalOrdersProvider._(argument: (status, audience), from: this);

  @override
  String toString() => r'rentalOrdersProvider';
}

/// How many of the business's rent orders sit in each status — the filter chips.

@ProviderFor(rentalOrderCounts)
final rentalOrderCountsProvider = RentalOrderCountsProvider._();

/// How many of the business's rent orders sit in each status — the filter chips.

final class RentalOrderCountsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RentalOrderStatusCount>>,
          List<RentalOrderStatusCount>,
          FutureOr<List<RentalOrderStatusCount>>
        >
    with
        $FutureModifier<List<RentalOrderStatusCount>>,
        $FutureProvider<List<RentalOrderStatusCount>> {
  /// How many of the business's rent orders sit in each status — the filter chips.
  RentalOrderCountsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rentalOrderCountsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rentalOrderCountsHash();

  @$internal
  @override
  $FutureProviderElement<List<RentalOrderStatusCount>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RentalOrderStatusCount>> create(Ref ref) {
    return rentalOrderCounts(ref);
  }
}

String _$rentalOrderCountsHash() => r'fedb5acc1efb178569b75049fb6a030064768d5a';

/// One rent order, with what this side can do to it next.

@ProviderFor(rentalOrder)
final rentalOrderProvider = RentalOrderFamily._();

/// One rent order, with what this side can do to it next.

final class RentalOrderProvider
    extends
        $FunctionalProvider<
          AsyncValue<RentalOrder>,
          RentalOrder,
          FutureOr<RentalOrder>
        >
    with $FutureModifier<RentalOrder>, $FutureProvider<RentalOrder> {
  /// One rent order, with what this side can do to it next.
  RentalOrderProvider._({
    required RentalOrderFamily super.from,
    required (String, RentalAudience) super.argument,
  }) : super(
         retry: null,
         name: r'rentalOrderProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$rentalOrderHash();

  @override
  String toString() {
    return r'rentalOrderProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<RentalOrder> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<RentalOrder> create(Ref ref) {
    final argument = this.argument as (String, RentalAudience);
    return rentalOrder(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is RentalOrderProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$rentalOrderHash() => r'd2df448de62fd864fd5c135ad1db3c18529ee41d';

/// One rent order, with what this side can do to it next.

final class RentalOrderFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<RentalOrder>,
          (String, RentalAudience)
        > {
  RentalOrderFamily._()
    : super(
        retry: null,
        name: r'rentalOrderProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One rent order, with what this side can do to it next.

  RentalOrderProvider call(
    String id, [
    RentalAudience audience = RentalAudience.business,
  ]) => RentalOrderProvider._(argument: (id, audience), from: this);

  @override
  String toString() => r'rentalOrderProvider';
}

/// Every step of an order and its add-ons, oldest first.

@ProviderFor(rentalOrderHistory)
final rentalOrderHistoryProvider = RentalOrderHistoryFamily._();

/// Every step of an order and its add-ons, oldest first.

final class RentalOrderHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RentalOrderEvent>>,
          List<RentalOrderEvent>,
          FutureOr<List<RentalOrderEvent>>
        >
    with
        $FutureModifier<List<RentalOrderEvent>>,
        $FutureProvider<List<RentalOrderEvent>> {
  /// Every step of an order and its add-ons, oldest first.
  RentalOrderHistoryProvider._({
    required RentalOrderHistoryFamily super.from,
    required (String, RentalAudience) super.argument,
  }) : super(
         retry: null,
         name: r'rentalOrderHistoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$rentalOrderHistoryHash();

  @override
  String toString() {
    return r'rentalOrderHistoryProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<RentalOrderEvent>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RentalOrderEvent>> create(Ref ref) {
    final argument = this.argument as (String, RentalAudience);
    return rentalOrderHistory(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is RentalOrderHistoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$rentalOrderHistoryHash() =>
    r'55cc02bc61765e8f3e3037edc09abbd23a544d6d';

/// Every step of an order and its add-ons, oldest first.

final class RentalOrderHistoryFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<RentalOrderEvent>>,
          (String, RentalAudience)
        > {
  RentalOrderHistoryFamily._()
    : super(
        retry: null,
        name: r'rentalOrderHistoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Every step of an order and its add-ons, oldest first.

  RentalOrderHistoryProvider call(
    String id, [
    RentalAudience audience = RentalAudience.business,
  ]) => RentalOrderHistoryProvider._(argument: (id, audience), from: this);

  @override
  String toString() => r'rentalOrderHistoryProvider';
}

/// How many of an item a new order for these dates can take. Fetched when the item or the dates
/// change; the quantity typed is compared in the app, so typing does not call the server.

@ProviderFor(rentalAvailability)
final rentalAvailabilityProvider = RentalAvailabilityFamily._();

/// How many of an item a new order for these dates can take. Fetched when the item or the dates
/// change; the quantity typed is compared in the app, so typing does not call the server.

final class RentalAvailabilityProvider
    extends
        $FunctionalProvider<
          AsyncValue<RentalAvailability>,
          RentalAvailability,
          FutureOr<RentalAvailability>
        >
    with
        $FutureModifier<RentalAvailability>,
        $FutureProvider<RentalAvailability> {
  /// How many of an item a new order for these dates can take. Fetched when the item or the dates
  /// change; the quantity typed is compared in the app, so typing does not call the server.
  RentalAvailabilityProvider._({
    required RentalAvailabilityFamily super.from,
    required (String, DateTime, DateTime, RentalAudience) super.argument,
  }) : super(
         retry: null,
         name: r'rentalAvailabilityProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$rentalAvailabilityHash();

  @override
  String toString() {
    return r'rentalAvailabilityProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<RentalAvailability> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<RentalAvailability> create(Ref ref) {
    final argument =
        this.argument as (String, DateTime, DateTime, RentalAudience);
    return rentalAvailability(
      ref,
      argument.$1,
      argument.$2,
      argument.$3,
      argument.$4,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RentalAvailabilityProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$rentalAvailabilityHash() =>
    r'ab132e953802130302f26f5fa0b52bc23ede904b';

/// How many of an item a new order for these dates can take. Fetched when the item or the dates
/// change; the quantity typed is compared in the app, so typing does not call the server.

final class RentalAvailabilityFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<RentalAvailability>,
          (String, DateTime, DateTime, RentalAudience)
        > {
  RentalAvailabilityFamily._()
    : super(
        retry: null,
        name: r'rentalAvailabilityProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// How many of an item a new order for these dates can take. Fetched when the item or the dates
  /// change; the quantity typed is compared in the app, so typing does not call the server.

  RentalAvailabilityProvider call(
    String itemId,
    DateTime start,
    DateTime end, [
    RentalAudience audience = RentalAudience.business,
  ]) => RentalAvailabilityProvider._(
    argument: (itemId, start, end, audience),
    from: this,
  );

  @override
  String toString() => r'rentalAvailabilityProvider';
}

/// One side's rent conversations, latest first, checked every 15 seconds while anything shows them
/// — the same rhythm as service chats.

@ProviderFor(RentalOrderThreads)
final rentalOrderThreadsProvider = RentalOrderThreadsFamily._();

/// One side's rent conversations, latest first, checked every 15 seconds while anything shows them
/// — the same rhythm as service chats.
final class RentalOrderThreadsProvider
    extends
        $AsyncNotifierProvider<RentalOrderThreads, List<RentalOrderThread>> {
  /// One side's rent conversations, latest first, checked every 15 seconds while anything shows them
  /// — the same rhythm as service chats.
  RentalOrderThreadsProvider._({
    required RentalOrderThreadsFamily super.from,
    required RentalAudience super.argument,
  }) : super(
         retry: null,
         name: r'rentalOrderThreadsProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$rentalOrderThreadsHash();

  @override
  String toString() {
    return r'rentalOrderThreadsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  RentalOrderThreads create() => RentalOrderThreads();

  @override
  bool operator ==(Object other) {
    return other is RentalOrderThreadsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$rentalOrderThreadsHash() =>
    r'31724ccff30334b115b0a5650a24ce123548c1ff';

/// One side's rent conversations, latest first, checked every 15 seconds while anything shows them
/// — the same rhythm as service chats.

final class RentalOrderThreadsFamily extends $Family
    with
        $ClassFamilyOverride<
          RentalOrderThreads,
          AsyncValue<List<RentalOrderThread>>,
          List<RentalOrderThread>,
          FutureOr<List<RentalOrderThread>>,
          RentalAudience
        > {
  RentalOrderThreadsFamily._()
    : super(
        retry: null,
        name: r'rentalOrderThreadsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// One side's rent conversations, latest first, checked every 15 seconds while anything shows them
  /// — the same rhythm as service chats.

  RentalOrderThreadsProvider call([
    RentalAudience audience = RentalAudience.business,
  ]) => RentalOrderThreadsProvider._(argument: audience, from: this);

  @override
  String toString() => r'rentalOrderThreadsProvider';
}

/// One side's rent conversations, latest first, checked every 15 seconds while anything shows them
/// — the same rhythm as service chats.

abstract class _$RentalOrderThreads
    extends $AsyncNotifier<List<RentalOrderThread>> {
  late final _$args = ref.$arg as RentalAudience;
  RentalAudience get audience => _$args;

  FutureOr<List<RentalOrderThread>> build([
    RentalAudience audience = RentalAudience.business,
  ]);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<RentalOrderThread>>,
              List<RentalOrderThread>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<RentalOrderThread>>,
                List<RentalOrderThread>
              >,
              AsyncValue<List<RentalOrderThread>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// Messages from the other side about rent orders not opened yet.

@ProviderFor(rentalUnreadMessageCount)
final rentalUnreadMessageCountProvider = RentalUnreadMessageCountFamily._();

/// Messages from the other side about rent orders not opened yet.

final class RentalUnreadMessageCountProvider
    extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// Messages from the other side about rent orders not opened yet.
  RentalUnreadMessageCountProvider._({
    required RentalUnreadMessageCountFamily super.from,
    required RentalAudience super.argument,
  }) : super(
         retry: null,
         name: r'rentalUnreadMessageCountProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$rentalUnreadMessageCountHash();

  @override
  String toString() {
    return r'rentalUnreadMessageCountProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    final argument = this.argument as RentalAudience;
    return rentalUnreadMessageCount(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RentalUnreadMessageCountProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$rentalUnreadMessageCountHash() =>
    r'f7da0321763eee99ce2bdb43f6f22af2621fcf13';

/// Messages from the other side about rent orders not opened yet.

final class RentalUnreadMessageCountFamily extends $Family
    with $FunctionalFamilyOverride<int, RentalAudience> {
  RentalUnreadMessageCountFamily._()
    : super(
        retry: null,
        name: r'rentalUnreadMessageCountProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Messages from the other side about rent orders not opened yet.

  RentalUnreadMessageCountProvider call([
    RentalAudience audience = RentalAudience.business,
  ]) => RentalUnreadMessageCountProvider._(argument: audience, from: this);

  @override
  String toString() => r'rentalUnreadMessageCountProvider';
}

/// One rent order's conversation, checked every 6 seconds while it is open.

@ProviderFor(RentalOrderConversation)
final rentalOrderConversationProvider = RentalOrderConversationFamily._();

/// One rent order's conversation, checked every 6 seconds while it is open.
final class RentalOrderConversationProvider
    extends
        $AsyncNotifierProvider<RentalOrderConversation, List<BookingMessage>> {
  /// One rent order's conversation, checked every 6 seconds while it is open.
  RentalOrderConversationProvider._({
    required RentalOrderConversationFamily super.from,
    required (String, RentalAudience) super.argument,
  }) : super(
         retry: null,
         name: r'rentalOrderConversationProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$rentalOrderConversationHash();

  @override
  String toString() {
    return r'rentalOrderConversationProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  RentalOrderConversation create() => RentalOrderConversation();

  @override
  bool operator ==(Object other) {
    return other is RentalOrderConversationProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$rentalOrderConversationHash() =>
    r'6b1cd8eee88d27176988910cd41ef0d277f98bc7';

/// One rent order's conversation, checked every 6 seconds while it is open.

final class RentalOrderConversationFamily extends $Family
    with
        $ClassFamilyOverride<
          RentalOrderConversation,
          AsyncValue<List<BookingMessage>>,
          List<BookingMessage>,
          FutureOr<List<BookingMessage>>,
          (String, RentalAudience)
        > {
  RentalOrderConversationFamily._()
    : super(
        retry: null,
        name: r'rentalOrderConversationProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One rent order's conversation, checked every 6 seconds while it is open.

  RentalOrderConversationProvider call(
    String rentalOrderId, [
    RentalAudience audience = RentalAudience.business,
  ]) => RentalOrderConversationProvider._(
    argument: (rentalOrderId, audience),
    from: this,
  );

  @override
  String toString() => r'rentalOrderConversationProvider';
}

/// One rent order's conversation, checked every 6 seconds while it is open.

abstract class _$RentalOrderConversation
    extends $AsyncNotifier<List<BookingMessage>> {
  late final _$args = ref.$arg as (String, RentalAudience);
  String get rentalOrderId => _$args.$1;
  RentalAudience get audience => _$args.$2;

  FutureOr<List<BookingMessage>> build(
    String rentalOrderId, [
    RentalAudience audience = RentalAudience.business,
  ]);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<BookingMessage>>, List<BookingMessage>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<BookingMessage>>,
                List<BookingMessage>
              >,
              AsyncValue<List<BookingMessage>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}
