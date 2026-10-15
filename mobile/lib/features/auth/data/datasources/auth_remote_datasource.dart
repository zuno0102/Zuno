import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/network/dio_error_mapper.dart';
import 'package:zuno/features/auth/data/models/auth_response_model.dart';
import 'package:zuno/features/auth/data/models/login_request_model.dart';
import 'package:zuno/features/auth/data/models/register_request_model.dart';
import 'package:zuno/features/auth/data/models/user_model.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<AuthResponseModel> register(RegisterRequestModel request) =>
      _post(ApiConstants.registerPath, request.toJson());

  Future<AuthResponseModel> login(LoginRequestModel request) =>
      _post(ApiConstants.loginPath, request.toJson());

  Future<AuthResponseModel> refreshToken(String refreshToken) =>
      _post(ApiConstants.refreshTokenPath, {'refreshToken': refreshToken});

  Future<void> revokeToken(String refreshToken) async {
    try {
      await _dio.post<void>(
        ApiConstants.revokeTokenPath,
        data: {'refreshToken': refreshToken},
      );
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      await _dio.post<void>(
        ApiConstants.forgotPasswordPath,
        data: {'email': email},
      );
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      await _dio.post<void>(
        ApiConstants.resetPasswordPath,
        data: {'token': token, 'newPassword': newPassword},
      );
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post<void>(
        ApiConstants.changePasswordPath,
        data: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  /// Corrects the signed-in account's own name and phone number.
  Future<UserModel> updateMyAccount({
    required String firstName,
    required String lastName,
    String? phoneNumber,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        ApiConstants.currentUserPath,
        data: {
          'firstName': firstName,
          'lastName': lastName,
          'phoneNumber': phoneNumber,
        },
      );
      return UserModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  /// Uploads or replaces the signed-in account's own picture.
  Future<UserModel> updateMyPhoto({
    required String filePath,
    required String contentType,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          contentType: MediaType.parse(contentType),
        ),
      });

      final response = await _dio.put<Map<String, dynamic>>(
        ApiConstants.currentUserPhotoPath,
        data: form,
      );
      return UserModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<UserModel> getCurrentUser() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.currentUserPath,
      );
      return UserModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<AuthResponseModel> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: body);
      return AuthResponseModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
