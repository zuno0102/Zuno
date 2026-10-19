import 'package:zuno/features/customer/data/datasources/customer_remote_datasource.dart';
import 'package:zuno/features/customer/domain/entities/business_detail.dart';
import 'package:zuno/features/customer/domain/entities/home_sections.dart';
import 'package:zuno/features/customer/domain/entities/service_coverage.dart';
import 'package:zuno/features/customer/domain/entities/service_detail.dart';
import 'package:zuno/features/customer/domain/entities/service_listing.dart';
import 'package:zuno/features/customer/domain/repositories/customer_repository.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  CustomerRepositoryImpl({required CustomerRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  final CustomerRemoteDataSource _remoteDataSource;

  @override
  Future<List<ServiceListing>> searchServices({
    String? categoryId,
    String? keyword,
    List<String>? districtIds,
  }) async => (await _remoteDataSource.searchServices(
    categoryId: categoryId,
    keyword: keyword,
    districtIds: districtIds,
  )).map((m) => m.toEntity()).toList();

  @override
  Future<HomeSections> getHomeSections({int? seed}) async =>
      (await _remoteDataSource.getHomeSections(seed: seed)).toEntity();

  @override
  Future<List<ServiceListing>> getBanners() async =>
      (await _remoteDataSource.getBanners()).map((m) => m.toEntity()).toList();

  @override
  Future<ServiceDetail> getServiceDetail(String id) async =>
      (await _remoteDataSource.getServiceDetail(id)).toEntity();

  @override
  Future<ServiceCoverage> checkServiceCoverage(
    String serviceId, {
    required double latitude,
    required double longitude,
  }) => _remoteDataSource.checkServiceCoverage(
    serviceId,
    latitude: latitude,
    longitude: longitude,
  );

  @override
  Future<BusinessDetail> getBusinessDetail(String id) async =>
      (await _remoteDataSource.getBusinessDetail(id)).toEntity();
}
