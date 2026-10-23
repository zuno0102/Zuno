import 'dart:typed_data';

import 'package:zuno/features/business_owner/data/datasources/business_remote_datasource.dart';
import 'package:zuno/features/business_owner/domain/entities/business_profile.dart';
import 'package:zuno/features/business_owner/domain/entities/business_service.dart';
import 'package:zuno/features/business_owner/domain/entities/business_worker.dart';
import 'package:zuno/features/business_owner/domain/entities/worker_busy_period.dart';
import 'package:zuno/features/business_owner/domain/repositories/business_repository.dart';

class BusinessRepositoryImpl implements BusinessRepository {
  BusinessRepositoryImpl({required BusinessRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  final BusinessRemoteDataSource _remoteDataSource;

  @override
  Future<BusinessProfile> getMyProfile() async =>
      (await _remoteDataSource.getMyProfile()).toEntity();

  @override
  Future<BusinessProfile> updateMyProfile({
    required String businessName,
    String? businessType,
    String? gstNumber,
    String? description,
    String? logoUrl,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? postalCode,
    String? country,
  }) async {
    final model = await _remoteDataSource.updateMyProfile({
      'businessName': businessName,
      'businessType': businessType,
      'gstNumber': gstNumber,
      'description': description,
      'logoUrl': logoUrl,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'city': city,
      'state': state,
      'postalCode': postalCode,
      'country': country,
    });
    return model.toEntity();
  }

  @override
  Future<BusinessProfile> uploadLogo(Uint8List imageBytes) async =>
      (await _remoteDataSource.uploadLogo(imageBytes)).toEntity();

  @override
  Future<BusinessProfile> removeLogo() async =>
      (await _remoteDataSource.removeLogo()).toEntity();

  @override
  Future<List<BusinessService>> getServices() async =>
      (await _remoteDataSource.getServices()).map((m) => m.toEntity()).toList();

  @override
  Future<BusinessService> createService({
    required String serviceCategoryId,
    String? serviceSubCategoryId,
    required String name,
    String? itemName,
    String? description,
    required String priceType,
    required double price,
    int? estimatedDurationMinutes,
    int requiredWorkerCount = 1,
    required List<String> districtIds,
  }) async {
    final model = await _remoteDataSource.createService({
      'serviceCategoryId': serviceCategoryId,
      'name': name,
      'itemName': itemName,
      'description': description,
      'priceType': priceType,
      'price': price,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'requiredWorkerCount': requiredWorkerCount,
      'districtIds': districtIds,
    });
    return model.toEntity();
  }

  @override
  Future<BusinessService> updateService({
    required String id,
    required String serviceCategoryId,
    String? serviceSubCategoryId,
    required String name,
    String? itemName,
    String? description,
    required String priceType,
    required double price,
    int? estimatedDurationMinutes,
    int requiredWorkerCount = 1,
    required bool isActive,
    required List<String> districtIds,
  }) async {
    final model = await _remoteDataSource.updateService(id, {
      'serviceCategoryId': serviceCategoryId,
      'name': name,
      'itemName': itemName,
      'description': description,
      'priceType': priceType,
      'price': price,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'requiredWorkerCount': requiredWorkerCount,
      'isActive': isActive,
      'districtIds': districtIds,
    });
    return model.toEntity();
  }

  @override
  Future<void> deleteService(String id) => _remoteDataSource.deleteService(id);

  @override
  Future<BusinessService> setServiceQuestions(
    String serviceId,
    List<Map<String, dynamic>> questions,
  ) async =>
      (await _remoteDataSource.setServiceQuestions(serviceId, questions)).toEntity();

  @override
  Future<BusinessService> uploadServiceImage(
    String serviceId,
    int slot,
    Uint8List imageBytes,
  ) async => (await _remoteDataSource.uploadServiceImage(
    serviceId,
    slot,
    imageBytes,
  )).toEntity();

  @override
  Future<void> removeServiceImage(String serviceId, int slot) =>
      _remoteDataSource.removeServiceImage(serviceId, slot);

  @override
  Future<BusinessService> uploadServiceVideo(
    String serviceId,
    Uint8List videoBytes,
    String mimeSubtype,
  ) async => (await _remoteDataSource.uploadServiceVideo(
    serviceId,
    videoBytes,
    mimeSubtype,
  )).toEntity();

  @override
  Future<void> removeServiceVideo(String serviceId) =>
      _remoteDataSource.removeServiceVideo(serviceId);

  @override
  Future<BusinessService> createServiceVariant({
    required String serviceId,
    required String name,
    String? serviceSubCategoryId,
    String? description,
    required String priceType,
    required double price,
    int? estimatedDurationMinutes,
  }) async {
    final model = await _remoteDataSource.createServiceVariant(serviceId, {
      'name': name,
      'serviceSubCategoryId': serviceSubCategoryId,
      'description': description,
      'priceType': priceType,
      'price': price,
      'estimatedDurationMinutes': estimatedDurationMinutes,
    });
    return model.toEntity();
  }

  @override
  Future<BusinessService> updateServiceVariant({
    required String serviceId,
    required String variantId,
    required String name,
    String? serviceSubCategoryId,
    String? description,
    required String priceType,
    required double price,
    int? estimatedDurationMinutes,
    required bool isActive,
  }) async {
    final model = await _remoteDataSource
        .updateServiceVariant(serviceId, variantId, {
          'name': name,
          'serviceSubCategoryId': serviceSubCategoryId,
          'description': description,
          'priceType': priceType,
          'price': price,
          'estimatedDurationMinutes': estimatedDurationMinutes,
          'isActive': isActive,
        });
    return model.toEntity();
  }

  @override
  Future<void> deleteServiceVariant(String serviceId, String variantId) =>
      _remoteDataSource.deleteServiceVariant(serviceId, variantId);

  @override
  Future<BusinessService> uploadServiceVariantImage(
    String serviceId,
    String variantId,
    int slot,
    Uint8List imageBytes,
  ) async => (await _remoteDataSource.uploadServiceVariantImage(
    serviceId,
    variantId,
    slot,
    imageBytes,
  )).toEntity();

  @override
  Future<void> removeServiceVariantImage(
    String serviceId,
    String variantId,
    int slot,
  ) => _remoteDataSource.removeServiceVariantImage(serviceId, variantId, slot);

  @override
  Future<BusinessService> uploadServiceVariantVideo(
    String serviceId,
    String variantId,
    Uint8List videoBytes,
    String mimeSubtype,
  ) async => (await _remoteDataSource.uploadServiceVariantVideo(
    serviceId,
    variantId,
    videoBytes,
    mimeSubtype,
  )).toEntity();

  @override
  Future<void> removeServiceVariantVideo(String serviceId, String variantId) =>
      _remoteDataSource.removeServiceVariantVideo(serviceId, variantId);

  @override
  Future<List<BusinessWorker>> getWorkers() async =>
      (await _remoteDataSource.getWorkers()).map((m) => m.toEntity()).toList();

  @override
  Future<List<WorkerBusyPeriod>> getWorkerBusyDates(String workerProfileId) async =>
      (await _remoteDataSource.getWorkerBusyDates(workerProfileId))
          .map((p) => p.toEntity())
          .toList();

  @override
  Future<BusinessWorker> inviteWorker(String workerIdentifier) async =>
      (await _remoteDataSource.inviteWorker(workerIdentifier)).toEntity();

  @override
  Future<void> removeWorker(String id) => _remoteDataSource.removeWorker(id);
}
