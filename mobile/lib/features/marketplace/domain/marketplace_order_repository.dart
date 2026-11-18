import 'dart:typed_data';

import 'package:zuno/features/marketplace/data/marketplace_remote_datasource.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_order.dart';

/// The business's Marketplace orders, B2B requests and payment choices — the Orders tab's data.
abstract interface class MarketplaceOrderRepository {
  /// The product orders, newest first, narrowed to [status]; with a count per status.
  Future<MarketplaceOrderPage> getOrders({String? status});

  Future<MarketplaceOrder> getOrder(String id);

  /// A one-tap step: Confirm order, Out for delivery, Mark delivered.
  Future<MarketplaceOrder> changeStatus(String id, String status);

  /// Mark shipped, with the courier it went with and its tracking number.
  Future<MarketplaceOrder> ship(
    String id, {
    required String courierCode,
    required String trackingNumber,
    String? courierName,
  });

  Future<MarketplaceOrder> uploadReceipt(String id, Uint8List bytes);

  Future<MarketplacePaymentSettings> getPaymentSettings();

  Future<MarketplacePaymentSettings> updatePaymentSettings({
    required bool acceptsCashOnDelivery,
    required bool acceptsOnlinePay,
  });

  /// The B2B requests on the business's lots, narrowed to [status]; with a count per status.
  Future<MarketplaceB2BRequestPage> getB2BRequests({String? status});

  /// Accept (contacts are shared) or decline.
  Future<MarketplaceB2BRequest> answerB2BRequest(
    String id, {
    required bool accept,
  });
}

class MarketplaceOrderRepositoryImpl implements MarketplaceOrderRepository {
  MarketplaceOrderRepositoryImpl(this._remote);

  final MarketplaceRemoteDataSource _remote;

  @override
  Future<MarketplaceOrderPage> getOrders({String? status}) async =>
      (await _remote.getOrders(status: status)).toEntity();

  @override
  Future<MarketplaceOrder> getOrder(String id) async =>
      (await _remote.getOrder(id)).toEntity();

  @override
  Future<MarketplaceOrder> changeStatus(String id, String status) async =>
      (await _remote.changeOrderStatus(id, status)).toEntity();

  @override
  Future<MarketplaceOrder> ship(
    String id, {
    required String courierCode,
    required String trackingNumber,
    String? courierName,
  }) async => (await _remote.shipOrder(
    id,
    courierCode: courierCode,
    trackingNumber: trackingNumber,
    courierName: courierName,
  )).toEntity();

  @override
  Future<MarketplaceOrder> uploadReceipt(String id, Uint8List bytes) async =>
      (await _remote.uploadOrderReceipt(id, bytes)).toEntity();

  @override
  Future<MarketplacePaymentSettings> getPaymentSettings() async =>
      (await _remote.getPaymentSettings()).toEntity();

  @override
  Future<MarketplacePaymentSettings> updatePaymentSettings({
    required bool acceptsCashOnDelivery,
    required bool acceptsOnlinePay,
  }) async => (await _remote.updatePaymentSettings(
    acceptsCashOnDelivery: acceptsCashOnDelivery,
    acceptsOnlinePay: acceptsOnlinePay,
  )).toEntity();

  @override
  Future<MarketplaceB2BRequestPage> getB2BRequests({String? status}) async =>
      (await _remote.getB2BRequests(status: status)).toEntity();

  @override
  Future<MarketplaceB2BRequest> answerB2BRequest(
    String id, {
    required bool accept,
  }) async => (await _remote.answerB2BRequest(id, accept: accept)).toEntity();
}
