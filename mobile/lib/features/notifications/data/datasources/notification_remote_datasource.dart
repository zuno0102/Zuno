import 'package:dio/dio.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/network/dio_error_mapper.dart';
import 'package:zuno/features/notifications/data/models/notification_model.dart';

/// What the signed-in person has been told, and whether they have seen it.
class NotificationRemoteDataSource {
  NotificationRemoteDataSource(this._dio);

  final Dio _dio;

  /// What this person was told, newest first.
  ///
  /// Chat is left out unless asked for: a new message already puts a number on the Chat tab, and
  /// carrying it on the bell as well counts one message in two places. The banners drawn in the
  /// phone's own tray do ask for it — announcing a message is the tray's job, and it marks nothing
  /// read.
  Future<List<NotificationModel>> getMine({
    int take = 50,
    bool includeChat = false,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiConstants.notificationsPath,
        queryParameters: {'take': take, 'includeChat': includeChat},
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

  /// Marks read whatever this person was told about one thing — a booking they have just opened.
  Future<void> markTargetRead(String target, String targetId) async {
    try {
      await _dio.post<void>(
        ApiConstants.markTargetNotificationsReadPath(target, targetId),
      );
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
