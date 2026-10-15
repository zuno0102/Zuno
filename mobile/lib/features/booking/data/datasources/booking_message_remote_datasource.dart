import 'package:dio/dio.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/network/dio_error_mapper.dart';
import 'package:zuno/features/booking/data/models/booking_message_model.dart';

/// Messages on a booking, for whichever side is signed in.
class BookingMessageRemoteDataSource {
  BookingMessageRemoteDataSource(this._dio);

  final Dio _dio;

  /// Every booking the signed-in user has a conversation on.
  Future<List<BookingThreadModel>> getThreads() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiConstants.bookingThreadsPath,
      );
      return (response.data ?? [])
          .map((e) => BookingThreadModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  /// One thread, oldest first. Fetching it is what marks the other side's messages read.
  Future<List<BookingMessageModel>> getMessages(String bookingId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiConstants.bookingMessagesPath(bookingId),
      );
      return (response.data ?? [])
          .map((e) => BookingMessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  /// Clears the thread from this user's own list. The other side keeps theirs.
  Future<void> clear(String bookingId) async {
    try {
      await _dio.delete<void>(ApiConstants.bookingMessagesPath(bookingId));
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<BookingMessageModel> send({
    required String bookingId,
    required String body,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.bookingMessagesPath(bookingId),
        data: {'body': body},
      );
      return BookingMessageModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
