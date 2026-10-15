import 'package:dio/dio.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/network/dio_error_mapper.dart';
import 'package:zuno/features/admin/data/models/catalog_category_model.dart';

/// The app owner's view of the catalogue: every kind of work, hidden ones included.
class AdminCatalogRemoteDataSource {
  AdminCatalogRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<CatalogCategoryModel>> getCatalog() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiConstants.adminCatalogCategoriesPath,
      );
      return response.data!
          .map((e) => CatalogCategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<CatalogCategoryModel> saveCategory({
    String? id,
    required String name,
    String? description,
    required int displayOrder,
    required bool isActive,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'description': description,
      'displayOrder': displayOrder,
      'isActive': isActive,
    };

    try {
      // POST adds, PUT edits. The route decides which, so the body never carries an id.
      final response = id == null
          ? await _dio.post<Map<String, dynamic>>(
              ApiConstants.adminCatalogCategoriesPath,
              data: body,
            )
          : await _dio.put<Map<String, dynamic>>(
              ApiConstants.adminCatalogCategoryPath(id),
              data: body,
            );
      return CatalogCategoryModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<CatalogSubCategoryModel> saveSubCategory({
    String? id,
    required String categoryId,
    required String name,
    required int displayOrder,
    required bool isActive,
  }) async {
    final body = <String, dynamic>{
      'serviceCategoryId': categoryId,
      'name': name,
      'displayOrder': displayOrder,
      'isActive': isActive,
    };

    try {
      final response = id == null
          ? await _dio.post<Map<String, dynamic>>(
              ApiConstants.adminCatalogSubCategoriesPath(categoryId),
              data: body,
            )
          : await _dio.put<Map<String, dynamic>>(
              ApiConstants.adminCatalogSubCategoryPath(id),
              data: body,
            );
      return CatalogSubCategoryModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
