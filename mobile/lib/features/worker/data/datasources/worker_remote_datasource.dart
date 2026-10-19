import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/network/dio_error_mapper.dart';
import 'package:zuno/features/worker/data/models/worker_invitation_model.dart';
import 'package:zuno/features/worker/data/models/hiring_business_model.dart';
import 'package:zuno/features/worker/data/models/worker_dashboard_model.dart';
import 'package:zuno/features/worker/data/models/worker_profile_model.dart';

class WorkerRemoteDataSource {
  WorkerRemoteDataSource(this._dio);

  final Dio _dio;

  /// A hiring business as a worker sees it: what it pays, and whether it pays.
  ///
  /// The worker's position, when they have set one, so each open job can say how far away it is.
  /// Sent coarse — three decimal places, about 110 metres — because request URLs are logged on both
  /// sides and a worker's exact position does not belong in either.
  Future<HiringBusinessModel> getHiringBusiness(
    String id, {
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.hiringBusinessPath(id),
        queryParameters: {
          if (latitude != null && longitude != null) ...{
            'latitude': latitude,
            'longitude': longitude,
          },
        },
      );
      return HiringBusinessModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  /// The worker's own profile: earnings, work record and payout setup.
  Future<WorkerProfileModel> getMyProfile() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.workerProfilePath,
      );
      return WorkerProfileModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  /// The worker's home screen: the profile plus what is running, coming, and owed.
  Future<WorkerDashboardModel> getDashboard() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.workerDashboardPath,
      );
      return WorkerDashboardModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  /// Changes what a worker is allowed to change about themselves.
  ///
  /// Every argument is optional and an omitted one is left alone, which is why nulls are stripped
  /// before sending: a null in the body would be indistinguishable from "clear this", and clearing
  /// a UPI by accident costs a worker the only way they have of being paid.
  Future<WorkerProfileModel> updateMyProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? upiVpa,
    double? hourlyRate,
    int? experienceYears,
  }) async {
    try {
      // Null entries are dropped rather than sent: a null in the body would be indistinguishable
      // from "clear this field".
      final body = <String, dynamic>{
        'firstName': ?firstName,
        'lastName': ?lastName,
        'phoneNumber': ?phoneNumber,
        'upiVpa': ?upiVpa,
        'hourlyRate': ?hourlyRate,
        'experienceYears': ?experienceYears,
      };

      final response = await _dio.put<Map<String, dynamic>>(
        ApiConstants.workerProfilePath,
        data: body,
      );
      return WorkerProfileModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }


  /// Uploads or replaces the worker's own picture.
  ///
  /// Sent as multipart because it is a file. The content type is stated explicitly rather than left
  /// to be guessed from the name, since the server validates on it and rejects anything it does not
  /// recognise.
  ///
  /// Takes bytes, not a path. `MultipartFile.fromFile` reads through `dart:io`, which the web build
  /// does not have, so a path-based upload threw there the moment anybody changed their photo.
  Future<WorkerProfileModel> setPhoto({required Uint8List bytes}) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: 'photo.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      });

      final response = await _dio.put<Map<String, dynamic>>(
        ApiConstants.workerPhotoPath,
        data: form,
      );
      return WorkerProfileModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
  Future<List<WorkerInvitationModel>> getMyInvitations() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiConstants.workerInvitationsPath,
      );
      return response.data!
          .map((e) => WorkerInvitationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<WorkerInvitationModel> respondToInvitation(
    String id, {
    required bool accept,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.respondToWorkerInvitationPath(id),
        data: {'accept': accept},
      );
      return WorkerInvitationModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
