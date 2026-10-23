import 'dart:typed_data';

import 'package:zuno/features/business_owner/domain/entities/business_profile.dart';
import 'package:zuno/features/business_owner/domain/entities/business_service.dart';
import 'package:zuno/features/business_owner/domain/entities/business_worker.dart';
import 'package:zuno/features/business_owner/domain/entities/worker_busy_period.dart';

abstract interface class BusinessRepository {
  Future<BusinessProfile> getMyProfile();

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
  });

  /// Sets the business's profile picture, returning the updated profile.
  Future<BusinessProfile> uploadLogo(Uint8List imageBytes);

  /// Removes the business's profile picture, returning the updated profile.
  Future<BusinessProfile> removeLogo();

  Future<List<BusinessService>> getServices();

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
  });

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
  });

  Future<void> deleteService(String id);

  /// Replaces the whole set of questions this service asks, in the order given.
  Future<BusinessService> setServiceQuestions(
    String serviceId,
    List<Map<String, dynamic>> questions,
  );

  Future<BusinessService> uploadServiceImage(
    String serviceId,
    int slot,
    Uint8List imageBytes,
  );

  Future<void> removeServiceImage(String serviceId, int slot);

  Future<BusinessService> uploadServiceVideo(
    String serviceId,
    Uint8List videoBytes,
    String mimeSubtype,
  );

  Future<void> removeServiceVideo(String serviceId);

  Future<BusinessService> createServiceVariant({
    required String serviceId,
    required String name,
    String? serviceSubCategoryId,
    String? description,
    required String priceType,
    required double price,
    int? estimatedDurationMinutes,
  });

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
  });

  Future<void> deleteServiceVariant(String serviceId, String variantId);

  Future<BusinessService> uploadServiceVariantImage(
    String serviceId,
    String variantId,
    int slot,
    Uint8List imageBytes,
  );

  Future<void> removeServiceVariantImage(
    String serviceId,
    String variantId,
    int slot,
  );

  Future<BusinessService> uploadServiceVariantVideo(
    String serviceId,
    String variantId,
    Uint8List videoBytes,
    String mimeSubtype,
  );

  Future<void> removeServiceVariantVideo(String serviceId, String variantId);

  Future<List<BusinessWorker>> getWorkers();

  /// One worker's diary: every job holding them, soonest first.
  Future<List<WorkerBusyPeriod>> getWorkerBusyDates(String workerProfileId);

  Future<BusinessWorker> inviteWorker(String workerIdentifier);

  Future<void> removeWorker(String id);
}
