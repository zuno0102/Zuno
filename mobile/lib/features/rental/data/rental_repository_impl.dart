import 'dart:typed_data';

import 'package:zuno/features/booking/domain/entities/booking_message.dart';

import 'package:zuno/features/rental/data/rental_remote_datasource.dart';
import 'package:zuno/features/rental/domain/entities/rental_item.dart';
import 'package:zuno/features/rental/domain/entities/rental_payment.dart';
import 'package:zuno/features/rental/domain/entities/rental_stock.dart';
import 'package:zuno/features/rental/domain/rental_repository.dart';

class RentalRepositoryImpl implements RentalRepository {
  RentalRepositoryImpl(this._remote);

  final RentalRemoteDataSource _remote;

  /// The page asked for when listing a business's items — the server caps it too.
  static const listPageSize = 100;

  @override
  Future<List<RentalCategory>> getCategories() async =>
      (await _remote.getCategories()).map((c) => c.toEntity()).toList();

  @override
  Future<List<RentalPriceTypeOption>> getPriceTypes() async =>
      (await _remote.getPriceTypes()).map((p) => p.toEntity()).toList();

  @override
  Future<List<RentalItem>> getMyItems({bool? isAvailable}) async =>
      (await _remote.getMyItems(
        pageSize: listPageSize,
        isAvailable: isAvailable,
      )).items.map((i) => i.toEntity()).toList();

  @override
  Future<List<RentalStockLine>> getStock() async => (await _remote.getStock(
    pageSize: listPageSize,
  )).items.map((s) => s.toEntity()).toList();

  @override
  Future<List<RentalOrder>> getItemOrders(String id) async =>
      (await _remote.getItemOrders(
        id,
        pageSize: listPageSize,
      )).items.map((o) => o.toEntity()).toList();

  @override
  Future<List<RentalOrder>> getOrders({String? status}) async =>
      (await _remote.getOrders(
        status: status,
        pageSize: listPageSize,
      )).items.map((o) => o.toEntity()).toList();

  @override
  Future<List<RentalOrderStatusCount>> getOrderCounts() async =>
      (await _remote.getOrderCounts()).map((c) => c.toEntity()).toList();

  @override
  Future<RentalAvailability> getAvailability(
    String itemId,
    DateTime start,
    DateTime end,
  ) async => (await _remote.getAvailability(itemId, start, end)).toEntity();

  @override
  Future<RentalOrder> createOrder(RentalOrderInput input) async =>
      (await _remote.createOrder(input)).toEntity();

  @override
  Future<RentalOrder> addPieces(
    String orderId,
    int quantity, {
    DateTime? endDate,
  }) async =>
      (await _remote.addPieces(orderId, quantity, endDate: endDate)).toEntity();

  @override
  Future<List<RentalOrderEvent>> getOrderHistory(String id) async =>
      (await _remote.getOrderHistory(id)).map((e) => e.toEntity()).toList();

  @override
  Future<RentalOrder> getOrder(String id) async =>
      (await _remote.getOrder(id)).toEntity();

  @override
  Future<RentalOrder> changeOrderStatus(String id, String toStatus) async =>
      (await _remote.changeOrderStatus(id, toStatus)).toEntity();

  @override
  Future<List<RentalOrderThread>> getOrderThreads() async =>
      (await _remote.getOrderThreads()).map((t) => t.toEntity()).toList();

  @override
  Future<List<BookingMessage>> getOrderMessages(String id) async =>
      (await _remote.getOrderMessages(id)).map((m) => m.toEntity()).toList();

  @override
  Future<BookingMessage> sendOrderMessage(String id, String body) async =>
      (await _remote.sendOrderMessage(id, body)).toEntity();

  @override
  Future<void> syncProfile() => _remote.syncProfile();

  @override
  Future<RentalPaymentOptions> getPaymentOptions() async =>
      (await _remote.getPaymentOptions()).toEntity();

  @override
  Future<String?> getUpiId() => _remote.getUpiId();

  @override
  Future<String?> setUpiId(String? upiId) => _remote.setUpiId(upiId);

  @override
  Future<RentalOrder> recordPayment(
    String id,
    RentalPaymentInput input,
  ) async => (await _remote.recordPayment(id, input)).toEntity();

  @override
  Future<RentalSummary> getSummary() async =>
      (await _remote.getSummary()).toEntity();

  @override
  Future<RentalItem> create(RentalItemInput input) async =>
      (await _remote.create(input)).toEntity();

  @override
  Future<RentalItem> update(String id, RentalItemInput input) async =>
      (await _remote.update(id, input)).toEntity();

  @override
  Future<RentalItem> updateStock(
    String id, {
    required int quantityOwned,
    required bool isAvailable,
  }) async => (await _remote.updateStock(
    id,
    quantityOwned: quantityOwned,
    isAvailable: isAvailable,
  )).toEntity();

  @override
  Future<void> delete(String id) => _remote.delete(id);

  @override
  Future<void> uploadImage(String id, int slot, Uint8List bytes) =>
      _remote.uploadImage(id, slot, bytes);

  @override
  Future<void> removeImage(String id, int slot) =>
      _remote.removeImage(id, slot);

  @override
  Future<void> uploadVideo(String id, Uint8List bytes, String mimeSubtype) =>
      _remote.uploadVideo(id, bytes, mimeSubtype);

  @override
  Future<void> removeVideo(String id) => _remote.removeVideo(id);
}
