import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:zuno/core/network/dio_error_mapper.dart';
import 'package:zuno/features/rental/data/models/rental_models.dart';
import 'package:zuno/features/rental/data/models/rental_stock_models.dart';
import 'package:zuno/features/rental/data/rental_api.dart';
import 'package:zuno/features/rental/domain/entities/rental_item.dart';
import 'package:zuno/features/rental/domain/entities/rental_payment.dart';
import 'package:zuno/features/rental/domain/entities/rental_stock.dart';

/// Talks to the Rent service. The [Dio] it is given already points at Rent and carries the shared
/// login, so a token refresh here is the same refresh as everywhere else in the app.
class RentalRemoteDataSource {
  RentalRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<RentalCategoryModel>> getCategories() => _run(() async {
    final response = await _dio.get<List<dynamic>>(RentApi.categoriesPath);
    return response.data!
        .map(
          (json) => RentalCategoryModel.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  });

  Future<List<RentalPriceTypeModel>> getPriceTypes() => _run(() async {
    final response = await _dio.get<List<dynamic>>(RentApi.priceTypesPath);
    return response.data!
        .map(
          (json) => RentalPriceTypeModel.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  });

  Future<RentalItemPageModel> getMyItems({
    int page = 1,
    int? pageSize,
    bool? isAvailable,
  }) => _run(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      RentApi.myItemsPath,
      queryParameters: {
        'page': page,
        'pageSize': ?pageSize,
        'isAvailable': ?isAvailable,
      },
    );
    return RentalItemPageModel.fromJson(response.data!);
  });

  Future<RentalStockPageModel> getStock({int? pageSize}) => _run(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      RentApi.stockPath,
      queryParameters: {'pageSize': ?pageSize},
    );
    return RentalStockPageModel.fromJson(response.data!);
  });

  Future<RentalOrderPageModel> getItemOrders(String id, {int? pageSize}) =>
      _run(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          RentApi.itemOrdersPath(id),
          queryParameters: {'pageSize': ?pageSize},
        );
        return RentalOrderPageModel.fromJson(response.data!);
      });

  Future<RentalOrderPageModel> getOrders({String? status, int? pageSize}) =>
      _run(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          RentApi.ordersPath,
          queryParameters: {'status': ?status, 'pageSize': ?pageSize},
        );
        return RentalOrderPageModel.fromJson(response.data!);
      });

  Future<List<RentalOrderStatusCountModel>> getOrderCounts() => _run(() async {
    final response = await _dio.get<List<dynamic>>(RentApi.orderCountsPath);
    return response.data!
        .map(
          (json) => RentalOrderStatusCountModel.fromJson(
            json as Map<String, dynamic>,
          ),
        )
        .toList();
  });

  Future<RentalAvailabilityModel> getAvailability(
    String itemId,
    DateTime start,
    DateTime end,
  ) => _run(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      RentApi.itemAvailabilityPath(itemId),
      queryParameters: {
        'start': rentalApiDate(start),
        'end': rentalApiDate(end),
      },
    );
    return RentalAvailabilityModel.fromJson(response.data!);
  });

  Future<RentalOrderModel> createOrder(RentalOrderInput input) =>
      _run(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          RentApi.ordersPath,
          data: input.toJson(),
        );
        return RentalOrderModel.fromJson(response.data!);
      });

  Future<RentalOrderModel> addPieces(
    String orderId,
    int quantity, {
    DateTime? endDate,
  }) => _run(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      RentApi.orderAddOnPath(orderId),
      data: {
        'quantity': quantity,
        if (endDate != null) 'endDate': rentalApiDate(endDate),
      },
    );
    return RentalOrderModel.fromJson(response.data!);
  });

  Future<List<RentalOrderEventModel>> getOrderHistory(String id) =>
      _run(() async {
        final response = await _dio.get<List<dynamic>>(
          RentApi.orderHistoryPath(id),
        );
        return response.data!
            .map(
              (json) =>
                  RentalOrderEventModel.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      });

  Future<RentalOrderModel> getOrder(String id) => _run(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      RentApi.orderPath(id),
    );
    return RentalOrderModel.fromJson(response.data!);
  });

  Future<RentalOrderModel> changeOrderStatus(
    String id,
    String toStatus, {
    String? refundMode,
  }) => _run(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      RentApi.orderStatusPath(id),
      data: {'toStatus': toStatus, 'refundMode': ?refundMode},
    );
    return RentalOrderModel.fromJson(response.data!);
  });

  Future<List<RentalOrderThreadModel>> getOrderThreads() => _run(() async {
    final response = await _dio.get<List<dynamic>>(RentApi.orderThreadsPath);
    return response.data!
        .map(
          (json) =>
              RentalOrderThreadModel.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  });

  Future<List<RentalOrderMessageModel>> getOrderMessages(String id) => _run(
    () async {
      final response = await _dio.get<List<dynamic>>(
        RentApi.orderMessagesPath(id),
      );
      return response.data!
          .map(
            (json) =>
                RentalOrderMessageModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    },
  );

  Future<RentalOrderMessageModel> sendOrderMessage(String id, String body) =>
      _run(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          RentApi.orderMessagesPath(id),
          data: {'body': body},
        );
        return RentalOrderMessageModel.fromJson(response.data!);
      });

  /// Refreshes how customers see this business — name, logo, verified — from its Service profile.
  Future<void> syncProfile() =>
      _run(() => _dio.post<void>(RentApi.profileSyncPath));

  Future<RentalPaymentOptionsModel> getPaymentOptions() => _run(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      RentApi.paymentOptionsPath,
    );
    return RentalPaymentOptionsModel.fromJson(response.data!);
  });

  /// The business's UPI ID; null until it is set.
  Future<String?> getUpiId() => _run(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      RentApi.paymentSettingsPath,
    );
    return response.data!['upiId'] as String?;
  });

  Future<RentalCancelQuoteModel> getCancelQuote(String id) => _run(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      RentApi.orderCancelQuotePath(id),
    );
    return RentalCancelQuoteModel.fromJson(response.data!);
  });

  Future<RentalOrderModel> setRefundMode(String id, String mode) =>
      _run(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          RentApi.orderRefundModePath(id),
          data: {'mode': mode},
        );
        return RentalOrderModel.fromJson(response.data!);
      });

  Future<RentalOrderModel> recordPayment(String id, RentalPaymentInput input) =>
      _run(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          RentApi.orderPaymentsPath(id),
          data: input.toJson(),
        );
        return RentalOrderModel.fromJson(response.data!);
      });

  Future<RentalSummaryModel> getSummary() => _run(() async {
    final response = await _dio.get<Map<String, dynamic>>(RentApi.summaryPath);
    return RentalSummaryModel.fromJson(response.data!);
  });

  Future<RentalItemModel> create(RentalItemInput input) => _run(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      RentApi.myItemsPath,
      data: input.toJson(),
    );
    return RentalItemModel.fromJson(response.data!);
  });

  Future<RentalItemModel> update(String id, RentalItemInput input) =>
      _run(() async {
        final response = await _dio.put<Map<String, dynamic>>(
          RentApi.itemPath(id),
          data: input.toJson(),
        );
        return RentalItemModel.fromJson(response.data!);
      });

  Future<RentalItemModel> updateStock(
    String id, {
    required int quantityOwned,
    required bool isAvailable,
  }) => _run(() async {
    final response = await _dio.patch<Map<String, dynamic>>(
      RentApi.itemStockPath(id),
      data: {'quantityOwned': quantityOwned, 'isAvailable': isAvailable},
    );
    return RentalItemModel.fromJson(response.data!);
  });

  Future<void> delete(String id) =>
      _run(() => _dio.delete<void>(RentApi.itemPath(id)));

  Future<RentalItemModel> uploadImage(
    String id,
    int slot,
    Uint8List bytes,
  ) => _upload(
    RentApi.itemImagePath(id, slot),
    // Pictures are compressed to JPEG as they are picked; said explicitly because the server
    // accepts only real images and Dio would otherwise send application/octet-stream.
    MultipartFile.fromBytes(
      bytes,
      filename: 'rent.jpg',
      contentType: MediaType('image', 'jpeg'),
    ),
  );

  Future<RentalItemModel> uploadVideo(
    String id,
    Uint8List bytes,
    String mimeSubtype,
  ) => _upload(
    RentApi.itemVideoPath(id),
    MultipartFile.fromBytes(
      bytes,
      filename: 'rent.$mimeSubtype',
      contentType: MediaType('video', mimeSubtype),
    ),
  );

  Future<RentalItemModel> removeImage(String id, int slot) => _run(() async {
    final response = await _dio.delete<Map<String, dynamic>>(
      RentApi.itemImagePath(id, slot),
    );
    return RentalItemModel.fromJson(response.data!);
  });

  Future<RentalItemModel> removeVideo(String id) => _run(() async {
    final response = await _dio.delete<Map<String, dynamic>>(
      RentApi.itemVideoPath(id),
    );
    return RentalItemModel.fromJson(response.data!);
  });

  Future<RentalItemModel> _upload(String path, MultipartFile file) =>
      _run(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          path,
          data: FormData.fromMap({'file': file}),
        );
        return RentalItemModel.fromJson(response.data!);
      });

  /// Every call fails the same way the rest of the app does: as an app exception with the
  /// server's own message.
  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
