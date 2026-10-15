import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/business_owner/domain/entities/business_service.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_providers.dart';

part 'business_services_notifier.g.dart';

@riverpod
class BusinessServicesNotifier extends _$BusinessServicesNotifier {
  @override
  Future<List<BusinessService>> build() =>
      ref.watch(businessRepositoryProvider).getServices();

  Future<BusinessService> addService({
    required String serviceCategoryId,
    required String name,
    String? itemName,
    String? description,
    required String priceType,
    required double price,
    int? estimatedDurationMinutes,
    int requiredWorkerCount = 1,
    required List<String> districtIds,
  }) async {
    final repository = ref.read(businessRepositoryProvider);
    final created = await repository.createService(
      serviceCategoryId: serviceCategoryId,
      name: name,
      itemName: itemName,
      description: description,
      priceType: priceType,
      price: price,
      estimatedDurationMinutes: estimatedDurationMinutes,
      requiredWorkerCount: requiredWorkerCount,
      districtIds: districtIds,
    );
    await _refresh();
    return created;
  }

  Future<void> editService({
    required String id,
    required String serviceCategoryId,
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
    final repository = ref.read(businessRepositoryProvider);
    await repository.updateService(
      id: id,
      serviceCategoryId: serviceCategoryId,
      name: name,
      itemName: itemName,
      description: description,
      priceType: priceType,
      price: price,
      estimatedDurationMinutes: estimatedDurationMinutes,
      requiredWorkerCount: requiredWorkerCount,
      isActive: isActive,
      districtIds: districtIds,
    );
    await _refresh();
  }

  Future<void> deleteService(String id) async {
    await ref.read(businessRepositoryProvider).deleteService(id);
    await _refresh();
  }

  /// Replaces the whole set of questions this service asks.
  Future<void> setServiceQuestions(
    String serviceId,
    List<Map<String, dynamic>> questions,
  ) async {
    await ref
        .read(businessRepositoryProvider)
        .setServiceQuestions(serviceId, questions);
    await _refresh();
  }

  Future<void> uploadServiceImage(
    String serviceId,
    int slot,
    Uint8List imageBytes,
  ) async {
    await ref
        .read(businessRepositoryProvider)
        .uploadServiceImage(serviceId, slot, imageBytes);
    await _refresh();
  }

  Future<void> removeServiceImage(String serviceId, int slot) async {
    await ref
        .read(businessRepositoryProvider)
        .removeServiceImage(serviceId, slot);
    await _refresh();
  }

  Future<void> uploadServiceVideo(
    String serviceId,
    Uint8List videoBytes,
    String mimeSubtype,
  ) async {
    await ref
        .read(businessRepositoryProvider)
        .uploadServiceVideo(serviceId, videoBytes, mimeSubtype);
    await _refresh();
  }

  Future<void> removeServiceVideo(String serviceId) async {
    await ref.read(businessRepositoryProvider).removeServiceVideo(serviceId);
    await _refresh();
  }

  Future<BusinessService> addServiceVariant({
    required String serviceId,
    required String name,
    String? serviceSubCategoryId,
    String? description,
    required String priceType,
    required double price,
    int? estimatedDurationMinutes,
  }) async {
    final updated = await ref
        .read(businessRepositoryProvider)
        .createServiceVariant(
          serviceId: serviceId,
          name: name,
          serviceSubCategoryId: serviceSubCategoryId,
          description: description,
          priceType: priceType,
          price: price,
          estimatedDurationMinutes: estimatedDurationMinutes,
        );
    await _refresh();
    return updated;
  }

  Future<void> editServiceVariant({
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
    await ref
        .read(businessRepositoryProvider)
        .updateServiceVariant(
          serviceId: serviceId,
          variantId: variantId,
          name: name,
          serviceSubCategoryId: serviceSubCategoryId,
          description: description,
          priceType: priceType,
          price: price,
          estimatedDurationMinutes: estimatedDurationMinutes,
          isActive: isActive,
        );
    await _refresh();
  }

  Future<void> deleteServiceVariant(String serviceId, String variantId) async {
    await ref
        .read(businessRepositoryProvider)
        .deleteServiceVariant(serviceId, variantId);
    await _refresh();
  }

  Future<void> uploadServiceVariantImage(
    String serviceId,
    String variantId,
    int slot,
    Uint8List imageBytes,
  ) async {
    await ref
        .read(businessRepositoryProvider)
        .uploadServiceVariantImage(serviceId, variantId, slot, imageBytes);
    await _refresh();
  }

  Future<void> removeServiceVariantImage(
    String serviceId,
    String variantId,
    int slot,
  ) async {
    await ref
        .read(businessRepositoryProvider)
        .removeServiceVariantImage(serviceId, variantId, slot);
    await _refresh();
  }

  Future<void> uploadServiceVariantVideo(
    String serviceId,
    String variantId,
    Uint8List videoBytes,
    String mimeSubtype,
  ) async {
    await ref
        .read(businessRepositoryProvider)
        .uploadServiceVariantVideo(serviceId, variantId, videoBytes, mimeSubtype);
    await _refresh();
  }

  Future<void> removeServiceVariantVideo(
    String serviceId,
    String variantId,
  ) async {
    await ref
        .read(businessRepositoryProvider)
        .removeServiceVariantVideo(serviceId, variantId);
    await _refresh();
  }

  Future<void> _refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(businessRepositoryProvider).getServices(),
    );
  }
}
