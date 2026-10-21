import 'package:dio/dio.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/network/dio_error_mapper.dart';
import 'package:zuno/features/work_chat/data/models/work_message_model.dart';

/// Messages between a business and a worker on its team, for whichever side is signed in.
class WorkMessageRemoteDataSource {
  WorkMessageRemoteDataSource(this._dio);

  final Dio _dio;

  /// Every business–worker conversation the signed-in user has.
  Future<List<WorkThreadModel>> getThreads() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiConstants.workThreadsPath,
      );
      return (response.data ?? [])
          .map((e) => WorkThreadModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  /// One conversation, oldest first. Fetching it marks the other side's messages read.
  Future<List<WorkMessageModel>> getMessages(String counterpartId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiConstants.workMessagesPath(counterpartId),
      );
      return (response.data ?? [])
          .map((e) => WorkMessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<WorkMessageModel> send({
    required String counterpartId,
    required String body,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.workMessagesPath(counterpartId),
        data: {'body': body},
      );
      return WorkMessageModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
