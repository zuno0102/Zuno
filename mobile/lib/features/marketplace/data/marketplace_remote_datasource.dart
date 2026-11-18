import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:zuno/core/network/dio_error_mapper.dart';
import 'package:zuno/features/marketplace/data/marketplace_api.dart';
import 'package:zuno/features/marketplace/data/models/marketplace_models.dart';
import 'package:zuno/features/marketplace/data/models/marketplace_order_models.dart';

/// Talks to the Marketplace service. The [Dio] it is given already points at Marketplace and
/// carries the shared login, so a token refresh here is the same refresh as everywhere else.
class MarketplaceRemoteDataSource {
  MarketplaceRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<MarketplaceCategoryModel>> getCategories({bool all = false}) =>
      _run(() async {
        final response = await _dio.get<List<dynamic>>(
          all
              ? MarketplaceApi.adminCategoriesPath
              : MarketplaceApi.categoriesPath,
        );
        return [
          for (final json in response.data!)
            MarketplaceCategoryModel.fromJson(json as Map<String, dynamic>),
        ];
      });

  Future<MarketplaceOptionsModel> getOptions() => _run(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      MarketplaceApi.optionsPath,
    );
    return MarketplaceOptionsModel.fromJson(response.data!);
  });

  Future<MarketplaceSummaryModel> getSummary() => _run(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      MarketplaceApi.summaryPath,
    );
    return MarketplaceSummaryModel.fromJson(response.data!);
  });

  Future<MarketplacePostPageModel> getMyPosts({
    String? categoryId,
    String? status,
    String? kind,
    bool keepsStock = false,
    bool wholesale = false,
    bool products = false,
    bool inactive = false,
    int? pageSize,
  }) => _run(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      MarketplaceApi.myPostsPath,
      queryParameters: {
        'categoryId': ?categoryId,
        'status': ?status,
        'kind': ?kind,
        if (keepsStock) 'keepsStock': true,
        if (wholesale) 'wholesale': true,
        if (products) 'products': true,
        if (inactive) 'inactive': true,
        'pageSize': ?pageSize,
      },
    );
    return MarketplacePostPageModel.fromJson(response.data!);
  });

  Future<MarketplacePostModel> create(Map<String, dynamic> body) =>
      _post(() => _dio.post(MarketplaceApi.myPostsPath, data: body));

  Future<MarketplacePostModel> update(String id, Map<String, dynamic> body) =>
      _post(() => _dio.put(MarketplaceApi.postPath(id), data: body));

  Future<MarketplacePostModel> changeStatus(String id, String status) => _post(
    () =>
        _dio.patch(MarketplaceApi.postStatusPath(id), data: {'status': status}),
  );

  /// How many of a new item are left; 0 is out of stock.
  Future<MarketplacePostModel> updateStock(
    String id,
    int quantity, {
    String? variantId,
  }) => _post(
    () => _dio.patch(
      MarketplaceApi.postStockPath(id),
      data: {'quantity': quantity, 'variantId': ?variantId},
    ),
  );

  Future<MarketplacePostModel> replaceVariants(
    String id,
    List<Map<String, dynamic>> variants,
  ) => _post(
    () => _dio.put(
      MarketplaceApi.postVariantsPath(id),
      data: {'variants': variants},
    ),
  );

  Future<void> delete(String id) =>
      _run(() => _dio.delete<void>(MarketplaceApi.postPath(id)));

  Future<MarketplacePostModel> uploadImage(
    String id,
    int slot,
    Uint8List bytes, {
    String? variantId,
  }) => _post(
    () => _dio.post(
      variantId == null
          ? MarketplaceApi.postImagePath(id, slot)
          : MarketplaceApi.postVariantImagePath(id, variantId, slot),
      // Pictures are compressed to JPEG as they are picked; said explicitly because the server
      // accepts only real images and Dio would otherwise send application/octet-stream.
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: 'marketplace.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      }),
    ),
  );

  Future<MarketplacePostModel> removeImage(
    String id,
    int slot, {
    String? variantId,
  }) => _post(
    () => _dio.delete(
      variantId == null
          ? MarketplaceApi.postImagePath(id, slot)
          : MarketplaceApi.postVariantImagePath(id, variantId, slot),
    ),
  );

  Future<MarketplaceBusinessModel> syncProfile() => _run(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      MarketplaceApi.profileSyncPath,
    );
    return MarketplaceBusinessModel.fromJson(response.data!);
  });

  /// The business's product orders, one page, narrowed to [status]; with a count per status.
  Future<MarketplaceOrderPageModel> getOrders({
    String? status,
    int? pageSize,
  }) => _run(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      MarketplaceApi.ordersPath,
      queryParameters: {'status': ?status, 'pageSize': ?pageSize},
    );
    return MarketplaceOrderPageModel.fromJson(response.data!);
  });

  Future<MarketplaceOrderModel> getOrder(String id) =>
      _order(() => _dio.get(MarketplaceApi.orderPath(id)));

  Future<MarketplaceOrderModel> changeOrderStatus(String id, String status) =>
      _order(
        () => _dio.patch(
          MarketplaceApi.orderStatusPath(id),
          data: {'status': status},
        ),
      );

  Future<MarketplaceOrderModel> shipOrder(
    String id, {
    required String courierCode,
    required String trackingNumber,
    String? courierName,
  }) => _order(
    () => _dio.post(
      MarketplaceApi.orderShipPath(id),
      data: {
        'courierCode': courierCode,
        'courierName': ?courierName,
        'trackingNumber': trackingNumber,
      },
    ),
  );

  /// A photo of the courier's receipt, compressed to JPEG as it was picked.
  Future<MarketplaceOrderModel> uploadOrderReceipt(
    String id,
    Uint8List bytes,
  ) => _order(
    () => _dio.post(
      MarketplaceApi.orderReceiptPath(id),
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: 'receipt.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      }),
    ),
  );

  Future<MarketplacePaymentSettingsModel> getPaymentSettings() =>
      _run(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          MarketplaceApi.paymentSettingsPath,
        );
        return MarketplacePaymentSettingsModel.fromJson(response.data!);
      });

  Future<MarketplacePaymentSettingsModel> updatePaymentSettings({
    required bool acceptsCashOnDelivery,
    required bool acceptsOnlinePay,
  }) => _run(() async {
    final response = await _dio.put<Map<String, dynamic>>(
      MarketplaceApi.paymentSettingsPath,
      data: {
        'acceptsCashOnDelivery': acceptsCashOnDelivery,
        'acceptsOnlinePay': acceptsOnlinePay,
      },
    );
    return MarketplacePaymentSettingsModel.fromJson(response.data!);
  });

  Future<MarketplaceB2BRequestPageModel> getB2BRequests({
    String? status,
    int? pageSize,
  }) => _run(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      MarketplaceApi.b2bRequestsPath,
      queryParameters: {'status': ?status, 'pageSize': ?pageSize},
    );
    return MarketplaceB2BRequestPageModel.fromJson(response.data!);
  });

  Future<MarketplaceB2BRequestModel> answerB2BRequest(
    String id, {
    required bool accept,
  }) => _run(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      MarketplaceApi.b2bRequestAnswerPath(id, accept: accept),
    );
    return MarketplaceB2BRequestModel.fromJson(response.data!);
  });

  Future<MarketplaceCategoryModel> saveCategory(
    Map<String, dynamic> body, {
    String? id,
  }) => _category(
    () => id == null
        ? _dio.post(MarketplaceApi.adminCategoriesPath, data: body)
        : _dio.put(MarketplaceApi.adminCategoryPath(id), data: body),
  );

  Future<MarketplaceCategoryModel> saveSubCategory(
    String categoryId,
    Map<String, dynamic> body, {
    String? subId,
  }) => _category(
    () => subId == null
        ? _dio.post(
            MarketplaceApi.adminSubCategoriesPath(categoryId),
            data: body,
          )
        : _dio.put(
            MarketplaceApi.adminSubCategoryPath(categoryId, subId),
            data: body,
          ),
  );

  Future<MarketplaceCategoryModel> saveField(
    String categoryId,
    Map<String, dynamic> body, {
    String? fieldId,
  }) => _category(
    () => fieldId == null
        ? _dio.post(MarketplaceApi.adminFieldsPath(categoryId), data: body)
        : _dio.put(
            MarketplaceApi.adminFieldPath(categoryId, fieldId),
            data: body,
          ),
  );

  Future<MarketplacePostModel> _post(
    Future<Response<dynamic>> Function() call,
  ) => _run(() async {
    final response = await call();
    return MarketplacePostModel.fromJson(response.data as Map<String, dynamic>);
  });

  Future<MarketplaceCategoryModel> _category(
    Future<Response<dynamic>> Function() call,
  ) => _run(() async {
    final response = await call();
    return MarketplaceCategoryModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  });

  Future<MarketplaceOrderModel> _order(
    Future<Response<dynamic>> Function() call,
  ) => _run(() async {
    final response = await call();
    return MarketplaceOrderModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  });

  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
