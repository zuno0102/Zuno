import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/network/dio_error_mapper.dart';
import 'package:zuno/features/hiring_post/data/models/hiring_post_model.dart';
import 'package:zuno/features/hiring_post/data/models/payout_batch_model.dart';

class HiringPostRemoteDataSource {
  HiringPostRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<HiringPostModel>> getMyPosts() =>
      _list(ApiConstants.businessHiringPostsPath);

  Future<HiringPostModel> createPost(Map<String, dynamic> body) =>
      _post(ApiConstants.businessHiringPostsPath, body);

  Future<HiringPostModel> updatePost(String id, Map<String, dynamic> body) =>
      _put(ApiConstants.updateHiringPostPath(id), body);

  Future<void> deletePost(String id) async {
    try {
      await _dio.delete<void>(ApiConstants.deleteHiringPostPath(id));
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<HiringPostModel> inviteWorker(String id, String workerIdentifier) =>
      _post(ApiConstants.inviteWorkerToHiringPostPath(id), {
        'workerIdentifier': workerIdentifier,
      });

  /// Offers one worker one date. The server raises the job behind it, so there is no post id.
  Future<HiringPostModel> inviteWorkerForDate({
    required String workerIdentifier,
    required DateTime eventDate,
    required double salaryAmount,
  }) => _post(ApiConstants.inviteWorkerForDatePath, {
    'workerIdentifier': workerIdentifier,
    'eventDate': eventDate.toUtc().toIso8601String(),
    'salaryAmount': salaryAmount,
  });

  Future<HiringPostModel> startWork(String id) =>
      _post(ApiConstants.startHiringPostWorkPath(id), const {});

  Future<HiringPostModel> completeWork(String id) =>
      _post(ApiConstants.completeHiringPostWorkPath(id), const {});

  Future<HiringPostModel> stopHiring(String id) =>
      _post(ApiConstants.stopHiringPostPath(id), const {});

  /// The worker's answer on whether their wages arrived.
  Future<void> respondToPayment(
    String applicationId, {
    required bool received,
    String? disputeReason,
  }) async {
    try {
      await _dio.post<dynamic>(
        ApiConstants.respondToPaymentPath(applicationId),
        data: {'received': received, 'disputeReason': disputeReason},
      );
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  /// Opens a pay run. [expectedTotal] is sent as a cross-check only — the server
  /// calculates the real figure and refuses the request if the two disagree.
  Future<PayoutBatchModel> createPayoutBatch(
    String id,
    double expectedTotal,
  ) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiConstants.hiringPostPayoutsPath(id),
        data: {'expectedTotal': expectedTotal},
      );
      return PayoutBatchModel.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  /// Tells the server the business's payment cleared, which sends each worker their share.
  Future<PayoutBatchModel> confirmPayoutCollection(
    String batchId,
    String providerPaymentId,
    String? signature,
  ) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiConstants.confirmHiringPostPayoutPath(batchId),
        data: {'providerPaymentId': providerPaymentId, 'signature': signature},
      );
      return PayoutBatchModel.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<HiringPostModel> raiseAgreedSalary(
    String applicationId,
    Map<String, dynamic> body,
  ) => _post(ApiConstants.raiseHiringPostSalaryPath(applicationId), body);

  /// Adds [increase] to the wage of everyone on this post still to be paid.
  Future<HiringPostModel> raiseCrewSalary(
    String postId, {
    required double increase,
    String? reason,
  }) => _post(ApiConstants.raiseHiringPostCrewSalaryPath(postId), {
    'increase': increase,
    'reason': reason,
  });

  Future<HiringPostModel> uploadPostImage(
    String id,
    Uint8List imageBytes,
  ) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          imageBytes,
          filename: 'post.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.businessHiringPostImagePath(id),
        data: formData,
      );
      return HiringPostModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<HiringPostModel> confirmApplication(String applicationId) => _post(
    ApiConstants.confirmHiringPostApplicationPath(applicationId),
    const {},
  );

  Future<HiringPostModel> rejectApplication(String applicationId) => _post(
    ApiConstants.rejectHiringPostApplicationPath(applicationId),
    const {},
  );

  /// Optional filters. Nulls are dropped so a worker with no location gets the unfiltered feed.
  Future<List<HiringPostModel>> getOpenPosts({
    double? latitude,
    double? longitude,
    int? radiusKm,
  }) => _list(
    ApiConstants.workerHiringPostsPath,
    query: {
      'latitude': ?latitude,
      'longitude': ?longitude,
      'radiusKm': ?radiusKm,
    },
  );

  /// Jobs this worker was invited onto, still waiting on an answer.
  ///
  /// Not a filter over the feed above: that is a search, narrowed by distance and cut to a page, and
  /// an offer must never be the row that fell off the end of one.
  Future<List<HiringPostModel>> getMyOffers() =>
      _list(ApiConstants.workerJobOffersPath);

  /// Work this worker took through a hiring post, past and future.
  ///
  /// My jobs is otherwise fed by the bookings endpoint alone, which knows nothing about posts — so
  /// a job taken this way showed on the dashboard and nowhere a worker could act on it.
  Future<List<HiringPostModel>> getMyPostJobs() =>
      _list(ApiConstants.workerPostJobsPath);

  Future<HiringPostModel> apply(String id) =>
      _post(ApiConstants.applyToHiringPostPath(id), const {});

  Future<HiringPostModel> respondToOffer(
    String applicationId, {
    required bool accept,
  }) => _post(ApiConstants.respondToHiringPostOfferPath(applicationId), {
    'accept': accept,
  });

  Future<List<HiringPostModel>> _list(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        path,
        queryParameters: query,
      );
      return response.data!
          .map((e) => HiringPostModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<HiringPostModel> _post(String path, Map<String, dynamic> body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: body);
      return HiringPostModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<HiringPostModel> _put(String path, Map<String, dynamic> body) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(path, data: body);
      return HiringPostModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
