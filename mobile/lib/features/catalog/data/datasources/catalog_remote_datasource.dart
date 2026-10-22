import 'package:dio/dio.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/network/dio_error_mapper.dart';
import 'package:zuno/features/catalog/data/models/district_model.dart';
import 'package:zuno/features/catalog/data/models/location_state_model.dart';
import 'package:zuno/features/catalog/data/models/order_stage_model.dart';
import 'package:zuno/features/catalog/data/models/service_category_model.dart';

class CatalogRemoteDataSource {
  CatalogRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<OrderStageModel>> getOrderStages() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiConstants.orderStagesPath,
      );
      return response.data!
          .map((e) => OrderStageModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<List<ServiceCategoryModel>> getServiceCategories() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiConstants.serviceCategoriesPath,
      );
      return response.data!
          .map((e) => ServiceCategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<List<LocationStateModel>> getStates() async {
    try {
      final response = await _dio.get<List<dynamic>>(ApiConstants.statesPath);
      return response.data!
          .map((e) => LocationStateModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<List<DistrictModel>> getDistricts({List<String>? stateIds}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiConstants.districtsPath,
        queryParameters: stateIds != null && stateIds.isNotEmpty
            ? {'stateIds': stateIds}
            : null,
      );
      return response.data!
          .map((e) => DistrictModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
