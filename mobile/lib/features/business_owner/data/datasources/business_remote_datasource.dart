import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/network/dio_error_mapper.dart';
import 'package:zuno/features/business_owner/data/models/business_dashboard_model.dart';
import 'package:zuno/features/business_owner/data/models/business_profile_model.dart';
import 'package:zuno/features/business_owner/data/models/business_service_model.dart';
import 'package:zuno/features/business_owner/data/models/business_worker_model.dart';
import 'package:zuno/features/business_owner/data/models/worker_busy_period_model.dart';

class BusinessRemoteDataSource {
  BusinessRemoteDataSource(this._dio);

  final Dio _dio;

  /// The home screen: work delivered, split by category, plus the trust record.
  Future<BusinessDashboardModel> getDashboard() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.businessDashboardPath,
      );
      return BusinessDashboardModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<BusinessProfileModel> getMyProfile() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.businessProfilePath,
      );
      return BusinessProfileModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<BusinessProfileModel> updateMyProfile(
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        ApiConstants.businessProfilePath,
        data: body,
      );
      return BusinessProfileModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  /// Sets the business's profile picture and returns the profile the server now holds.
  ///
  /// The part name must be `file` — the endpoint binds by parameter name, so calling it
  /// anything else arrives as no file at all.
  Future<BusinessProfileModel> uploadLogo(Uint8List imageBytes) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          imageBytes,
          filename: 'logo.jpg',
          // Stated explicitly because the server accepts only JPEG, PNG and WebP, and Dio
          // would otherwise send application/octet-stream and be refused.
          contentType: MediaType('image', 'jpeg'),
        ),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.businessProfileLogoPath,
        data: formData,
      );
      return BusinessProfileModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  /// Removes the business's profile picture.
  Future<BusinessProfileModel> removeLogo() async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(
        ApiConstants.businessProfileLogoPath,
      );
      return BusinessProfileModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<List<BusinessServiceModel>> getServices() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiConstants.businessServicesPath,
      );
      return response.data!
          .map((e) => BusinessServiceModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<BusinessServiceModel> createService(Map<String, dynamic> body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.businessServicesPath,
        data: body,
      );
      return BusinessServiceModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<BusinessServiceModel> updateService(
    String id,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        ApiConstants.businessServicePath(id),
        data: body,
      );
      return BusinessServiceModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<void> deleteService(String id) async {
    try {
      await _dio.delete<void>(ApiConstants.businessServicePath(id));
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  /// Replaces the whole set of questions this service asks, in the order given.
  ///
  /// Each entry carries an `id` only when editing one that already exists — keeping the id is
  /// what leaves the answers customers have already given still pointing somewhere.
  Future<BusinessServiceModel> setServiceQuestions(
    String serviceId,
    List<Map<String, dynamic>> questions,
  ) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        ApiConstants.businessServiceQuestionsPath(serviceId),
        data: {'questions': questions},
      );
      return BusinessServiceModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<BusinessServiceModel> uploadServiceImage(
    String serviceId,
    int slot,
    Uint8List imageBytes,
  ) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          imageBytes,
          filename: 'service.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.businessServiceImageSlotPath(serviceId, slot),
        data: formData,
      );
      return BusinessServiceModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<void> removeServiceImage(String serviceId, int slot) async {
    try {
      await _dio.delete<void>(
        ApiConstants.businessServiceImageSlotPath(serviceId, slot),
      );
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<BusinessServiceModel> uploadServiceVideo(
    String serviceId,
    Uint8List videoBytes,
    String mimeSubtype,
  ) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          videoBytes,
          filename: 'service.$mimeSubtype',
          contentType: MediaType('video', mimeSubtype),
        ),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.businessServiceVideoPath(serviceId),
        data: formData,
      );
      return BusinessServiceModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<void> removeServiceVideo(String serviceId) async {
    try {
      await _dio.delete<void>(ApiConstants.businessServiceVideoPath(serviceId));
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<BusinessServiceModel> createServiceVariant(
    String serviceId,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.businessServiceVariantsPath(serviceId),
        data: body,
      );
      return BusinessServiceModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<BusinessServiceModel> updateServiceVariant(
    String serviceId,
    String variantId,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        ApiConstants.businessServiceVariantPath(serviceId, variantId),
        data: body,
      );
      return BusinessServiceModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<void> deleteServiceVariant(String serviceId, String variantId) async {
    try {
      await _dio.delete<void>(
        ApiConstants.businessServiceVariantPath(serviceId, variantId),
      );
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<BusinessServiceModel> uploadServiceVariantImage(
    String serviceId,
    String variantId,
    int slot,
    Uint8List imageBytes,
  ) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          imageBytes,
          filename: 'variant.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.businessServiceVariantImageSlotPath(
          serviceId,
          variantId,
          slot,
        ),
        data: formData,
      );
      return BusinessServiceModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<void> removeServiceVariantImage(
    String serviceId,
    String variantId,
    int slot,
  ) async {
    try {
      await _dio.delete<void>(
        ApiConstants.businessServiceVariantImageSlotPath(
          serviceId,
          variantId,
          slot,
        ),
      );
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<BusinessServiceModel> uploadServiceVariantVideo(
    String serviceId,
    String variantId,
    Uint8List videoBytes,
    String mimeSubtype,
  ) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          videoBytes,
          filename: 'variant.$mimeSubtype',
          contentType: MediaType('video', mimeSubtype),
        ),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.businessServiceVariantVideoPath(serviceId, variantId),
        data: formData,
      );
      return BusinessServiceModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<void> removeServiceVariantVideo(
    String serviceId,
    String variantId,
  ) async {
    try {
      await _dio.delete<void>(
        ApiConstants.businessServiceVariantVideoPath(serviceId, variantId),
      );
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<List<BusinessWorkerModel>> getWorkers() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiConstants.businessWorkersPath,
      );
      return response.data!
          .map((e) => BusinessWorkerModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<List<WorkerBusyPeriodModel>> getWorkerBusyDates(
    String workerProfileId,
  ) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiConstants.businessWorkerBusyDatesPath(workerProfileId),
      );
      return response.data!
          .map((e) => WorkerBusyPeriodModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<BusinessWorkerModel> inviteWorker(String workerIdentifier) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.inviteWorkerPath,
        data: {'workerIdentifier': workerIdentifier},
      );
      return BusinessWorkerModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  /// Takes somebody off the business's team.
  Future<void> removeWorker(String id) async {
    try {
      await _dio.delete<void>(ApiConstants.businessWorkerPath(id));
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
