import 'dart:typed_data';

import 'package:zuno/features/booking/domain/entities/booking_message.dart';

import 'package:zuno/features/rental/domain/entities/rental_item.dart';
import 'package:zuno/features/rental/domain/entities/rental_payment.dart';
import 'package:zuno/features/rental/domain/entities/rental_stock.dart';

/// The business's rent items and the rent catalogue, as the screens use them.
abstract class RentalRepository {
  Future<List<RentalCategory>> getCategories();

  /// The ways of charging the form offers, in display order.
  Future<List<RentalPriceTypeOption>> getPriceTypes();

  /// Newest first; [isAvailable] narrows to items on (true) or switched off (false).
  Future<List<RentalItem>> getMyItems({bool? isAvailable});

  /// Each item with how many are in, out with customers, and in total.
  Future<List<RentalStockLine>> getStock();

  /// One item's orders, newest first: who has how many, when, and where.
  Future<List<RentalOrder>> getItemOrders(String id);

  /// Every rent order of the business's, newest first; one status only when [status] is given.
  Future<List<RentalOrder>> getOrders({String? status});

  /// How many orders sit in each status, in the status table's order.
  Future<List<RentalOrderStatusCount>> getOrderCounts();

  Future<RentalOrder> getOrder(String id);

  /// Every step of the order and its add-ons, oldest first.
  Future<List<RentalOrderEvent>> getOrderHistory(String id);

  /// How many of an item a new order for these dates can still take.
  Future<RentalAvailability> getAvailability(
    String itemId,
    DateTime start,
    DateTime end,
  );

  /// Books pieces for a customer who phoned or came in. Refused by the server when the dates do not
  /// leave enough, even if the form thought they did.
  Future<RentalOrder> createOrder(RentalOrderInput input);

  /// More pieces for a running order — a new order linked to it.
  Future<RentalOrder> addPieces(
    String orderId,
    int quantity, {
    DateTime? endDate,
  });

  /// Takes one step from the order's actions, e.g. to `OnRent` ("Send out").
  /// [refundMode] — `Online` or `InHand` — is required when cancelling an order the customer paid for.
  Future<RentalOrder> changeOrderStatus(
    String id,
    String toStatus, {
    String? refundMode,
  });

  /// Rent orders with a conversation, latest first.
  Future<List<RentalOrderThread>> getOrderThreads();

  /// One order's conversation, oldest first; reading it marks the customer's messages read.
  Future<List<BookingMessage>> getOrderMessages(String id);

  Future<BookingMessage> sendOrderMessage(String id, String body);

  /// Refreshes how customers see this business — its name, logo and verification — from its Service
  /// profile. Only verified businesses' items are shown to customers.
  Future<void> syncProfile();

  /// The words for the item form's advance and the collect sheet's methods.
  Future<RentalPaymentOptions> getPaymentOptions();

  /// The UPI ID the order QR is made from; null until the business sets it.
  Future<String?> getUpiId();

  /// Sets it, or clears it with null. Refused by the server unless it looks like name@bank.
  Future<String?> setUpiId(String? upiId);

  /// Money taken for an order, or given back on a cancelled one — never more than is due or was paid.
  Future<RentalOrder> recordPayment(String id, RentalPaymentInput input);

  /// What cancelling now gives back — everything, as the business is the one cancelling.
  Future<RentalCancelQuote> getCancelQuote(String id);

  /// How a cancelled order's refund goes back: [RentalRefundMode.online] or [RentalRefundMode.inHand].
  Future<RentalOrder> setRefundMode(String id, String mode);

  /// The counts behind the Rent tiles on the business home screen.
  Future<RentalSummary> getSummary();

  Future<RentalItem> create(RentalItemInput input);

  Future<RentalItem> update(String id, RentalItemInput input);

  /// The Stock page's quick change: how many the business has, and whether it can be rented now.
  Future<RentalItem> updateStock(
    String id, {
    required int quantityOwned,
    required bool isAvailable,
  });

  Future<void> delete(String id);

  Future<void> uploadImage(String id, int slot, Uint8List bytes);

  Future<void> removeImage(String id, int slot);

  Future<void> uploadVideo(String id, Uint8List bytes, String mimeSubtype);

  Future<void> removeVideo(String id);
}
