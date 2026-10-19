import 'package:dio/dio.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/network/dio_error_mapper.dart';
import 'package:zuno/features/customer/data/models/business_detail_model.dart';
import 'package:zuno/features/customer/data/models/home_sections_model.dart';
import 'package:zuno/features/customer/data/models/service_detail_model.dart';
import 'package:zuno/features/customer/data/models/service_listing_model.dart';
import 'package:zuno/features/customer/domain/entities/service_coverage.dart';

class CustomerRemoteDataSource {
  CustomerRemoteDataSource(this._dio);

  final Dio _dio;

  /// How many services the home grid asks for: twenty, which is ten rows of two.
  ///
  /// Forty came back before, and twenty rows of cards is a scroll nobody reaches the end of — the
  /// search box and the categories are how somebody narrows it down, not persistence.
  static const _homeGridSize = 20;

  /// Browses services across every business, which is how a customer starts looking.
  Future<List<ServiceListingModel>> searchServices({
    String? categoryId,
    String? keyword,
    List<String>? districtIds,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiConstants.customerServicesPath,
        queryParameters: {
          'categoryId': ?categoryId,
          if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
          if (districtIds != null && districtIds.isNotEmpty) 'districtIds': districtIds,
          'take': _homeGridSize,
        },
      );
      return response.data!
          .map((e) => ServiceListingModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  /// Every section of the home screen. Composed server-side so the sections do not repeat.
  Future<HomeSectionsModel> getHomeSections({int? seed}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.customerHomeSectionsPath,
        queryParameters: {'seed': ?seed},
      );
      return HomeSectionsModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  /// Today's banner services. The server decides which seven and changes them daily.
  Future<List<ServiceListingModel>> getBanners() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiConstants.customerBannersPath,
      );
      return response.data!
          .map((e) => ServiceListingModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  /// One service on its own, with every package it is sold in.
  Future<ServiceDetailModel> getServiceDetail(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.customerServiceDetailPath(id),
      );
      return ServiceDetailModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  /// Whether the service is offered at the pinned location — asked as soon as the customer pins it.
  Future<ServiceCoverage> checkServiceCoverage(
    String serviceId, {
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.customerServiceCoveragePath(serviceId),
        queryParameters: {'latitude': latitude, 'longitude': longitude},
      );
      return ServiceCoverage.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<BusinessDetailModel> getBusinessDetail(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.customerBusinessDetailPath(id),
      );
      return BusinessDetailModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
