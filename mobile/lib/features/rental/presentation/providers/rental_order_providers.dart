import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/booking/domain/entities/booking_message.dart';
import 'package:zuno/features/rental/data/rental_customer_remote_datasource.dart';
import 'package:zuno/features/rental/data/rental_customer_repository_impl.dart';
import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/features/rental/domain/entities/rental_stock.dart';
import 'package:zuno/features/rental/domain/rental_customer_repository.dart';
import 'package:zuno/features/rental/domain/rental_orders_gateway.dart';
import 'package:zuno/features/rental/presentation/providers/rental_providers.dart';

part 'rental_order_providers.g.dart';

/// The customer's side of the Rent server, on the same client and login as the business side.
@Riverpod(keepAlive: true)
RentalCustomerRemoteDataSource rentalCustomerDataSource(Ref ref) =>
    RentalCustomerRemoteDataSource(ref.watch(rentDioProvider));

@Riverpod(keepAlive: true)
RentalCustomerRepository rentalCustomerRepository(Ref ref) =>
    RentalCustomerRepositoryImpl(ref.watch(rentalCustomerDataSourceProvider));

/// The order screens' data for one side — the business's orders, or the customer's.
@Riverpod(keepAlive: true)
RentalOrdersGateway rentalOrdersGateway(Ref ref, RentalAudience audience) =>
    switch (audience) {
      RentalAudience.business => BusinessRentalOrdersGateway(
        ref.watch(rentalRepositoryProvider),
      ),
      RentalAudience.customer => CustomerRentalOrdersGateway(
        ref.watch(rentalCustomerDataSourceProvider),
      ),
    };

/// One side's rent orders, newest first; one status only when [status] is given.
@riverpod
Future<List<RentalOrder>> rentalOrders(
  Ref ref,
  String? status, [
  RentalAudience audience = RentalAudience.business,
]) => ref.watch(rentalOrdersGatewayProvider(audience)).orders(status: status);

/// How many of the business's rent orders sit in each status — the filter chips.
@riverpod
Future<List<RentalOrderStatusCount>> rentalOrderCounts(Ref ref) =>
    ref.watch(rentalRepositoryProvider).getOrderCounts();

/// One rent order, with what this side can do to it next.
@riverpod
Future<RentalOrder> rentalOrder(
  Ref ref,
  String id, [
  RentalAudience audience = RentalAudience.business,
]) => ref.watch(rentalOrdersGatewayProvider(audience)).order(id);

/// Every step of an order and its add-ons, oldest first.
@riverpod
Future<List<RentalOrderEvent>> rentalOrderHistory(
  Ref ref,
  String id, [
  RentalAudience audience = RentalAudience.business,
]) => ref.watch(rentalOrdersGatewayProvider(audience)).history(id);

/// How many of an item a new order for these dates can take. Fetched when the item or the dates
/// change; the quantity typed is compared in the app, so typing does not call the server.
@riverpod
Future<RentalAvailability> rentalAvailability(
  Ref ref,
  String itemId,
  DateTime start,
  DateTime end, [
  RentalAudience audience = RentalAudience.business,
]) => switch (audience) {
  RentalAudience.business =>
    ref.watch(rentalRepositoryProvider).getAvailability(itemId, start, end),
  RentalAudience.customer =>
    ref
        .watch(rentalCustomerRepositoryProvider)
        .availability(itemId, start, end),
};

/// One side's rent conversations, latest first, checked every 15 seconds while anything shows them
/// — the same rhythm as service chats.
@Riverpod(keepAlive: true)
class RentalOrderThreads extends _$RentalOrderThreads {
  Timer? _poll;

  static const _pollEvery = Duration(seconds: 15);

  @override
  Future<List<RentalOrderThread>> build([
    RentalAudience audience = RentalAudience.business,
  ]) async {
    ref.onDispose(() {
      _poll?.cancel();
      _poll = null;
    });
    _poll ??= Timer.periodic(_pollEvery, (_) => _refresh());
    return ref.read(rentalOrdersGatewayProvider(audience)).threads();
  }

  Future<void> _refresh() async {
    if (!ref.mounted) return;
    final next = await AsyncValue.guard(
      () => ref.read(rentalOrdersGatewayProvider(audience)).threads(),
    );
    // A failed poll keeps what is on screen rather than blanking the list.
    if (!ref.mounted || next.hasError) return;
    state = next;
  }
}

/// Messages from the other side about rent orders not opened yet.
@riverpod
int rentalUnreadMessageCount(
  Ref ref, [
  RentalAudience audience = RentalAudience.business,
]) =>
    ref
        .watch(rentalOrderThreadsProvider(audience))
        .value
        ?.fold<int>(0, (sum, t) => sum + t.unreadCount) ??
    0;

/// One rent order's conversation, checked every 6 seconds while it is open.
@riverpod
class RentalOrderConversation extends _$RentalOrderConversation {
  Timer? _poll;

  static const _pollEvery = Duration(seconds: 6);

  @override
  Future<List<BookingMessage>> build(
    String rentalOrderId, [
    RentalAudience audience = RentalAudience.business,
  ]) async {
    // Stopped when the chat closes, so nothing keeps asking for a conversation nobody reads.
    ref.onDispose(() => _poll?.cancel());
    _poll ??= Timer.periodic(_pollEvery, (_) => _refresh());

    final messages = await ref
        .read(rentalOrdersGatewayProvider(audience))
        .messages(rentalOrderId);
    // Opening it read the other side's messages: the list's badges catch up.
    ref.invalidate(rentalOrderThreadsProvider(audience));
    return messages;
  }

  Future<void> _refresh() async {
    if (!ref.mounted) return;
    final next = await AsyncValue.guard(
      () => ref
          .read(rentalOrdersGatewayProvider(audience))
          .messages(rentalOrderId),
    );
    if (!ref.mounted || next.hasError) return;
    state = next;
  }

  Future<void> send(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;

    final sent = await ref
        .read(rentalOrdersGatewayProvider(audience))
        .send(rentalOrderId, trimmed);
    if (!ref.mounted) return;

    state = AsyncData([...?state.value, sent]);
    ref.invalidate(rentalOrderThreadsProvider(audience));
  }
}
