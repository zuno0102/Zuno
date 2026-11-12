import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:zuno/core/network/dio_error_mapper.dart';
import 'package:zuno/features/marketplace/data/marketplace_api.dart';
import 'package:zuno/features/marketplace/data/models/marketplace_models.dart';

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
    int? pageSize,
  }) => _run(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      MarketplaceApi.myPostsPath,
      queryParameters: {
        'categoryId': ?categoryId,
        'status': ?status,
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

  Future<void> delete(String id) =>
      _run(() => _dio.delete<void>(MarketplaceApi.postPath(id)));

  Future<MarketplacePostModel> uploadImage(
    String id,
    int slot,
    Uint8List bytes,
  ) => _post(
    () => _dio.post(
      MarketplaceApi.postImagePath(id, slot),
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

  Future<MarketplacePostModel> removeImage(String id, int slot) =>
      _post(() => _dio.delete(MarketplaceApi.postImagePath(id, slot)));

  Future<MarketplaceBusinessModel> syncProfile() => _run(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      MarketplaceApi.profileSyncPath,
    );
    return MarketplaceBusinessModel.fromJson(response.data!);
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

  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
