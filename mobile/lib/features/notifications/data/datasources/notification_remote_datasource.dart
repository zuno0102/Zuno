import 'package:dio/dio.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/network/dio_error_mapper.dart';
import 'package:zuno/features/notifications/data/models/notification_model.dart';

/// What the signed-in person has been told, and whether they have seen it.
class NotificationRemoteDataSource {
  NotificationRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<NotificationModel>> getMine({int take = 50}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiConstants.notificationsPath,
        queryParameters: {'take': take},
      );
      return (response.data ?? [])
          .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.unreadNotificationCountPath,
      );
      return NotificationCountModel.fromJson(response.data!).unreadCount;
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _dio.post<void>(ApiConstants.markNotificationReadPath(id));
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<void> markAllRead() async {
    try {
      await _dio.post<void>(ApiConstants.markAllNotificationsReadPath);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
