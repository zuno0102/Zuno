import 'dart:typed_data';

import 'package:zuno/features/hiring_post/data/datasources/hiring_post_remote_datasource.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/domain/entities/payout_batch.dart';
import 'package:zuno/features/hiring_post/domain/repositories/hiring_post_repository.dart';

class HiringPostRepositoryImpl implements HiringPostRepository {
  HiringPostRepositoryImpl({
    required HiringPostRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final HiringPostRemoteDataSource _remoteDataSource;

  @override
  Future<List<HiringPost>> getMyPosts() async =>
      (await _remoteDataSource.getMyPosts()).map((m) => m.toEntity()).toList();

  @override
  Future<HiringPost> createPost({
    String? bookingId,
    required String title,
    String? description,
    required DateTime eventDate,
    required int durationMinutes,
    String? location,
    double? latitude,
    double? longitude,
    String? locationPrecision,
    String? serviceSubCategoryId,
    required int workersNeeded,
    required double salaryAmount,
    required String salaryUnit,
  }) async {
    final model = await _remoteDataSource.createPost(
      _postBody(
        bookingId: bookingId,
        title: title,
        description: description,
        eventDate: eventDate,
        durationMinutes: durationMinutes,
        location: location,
        latitude: latitude,
        longitude: longitude,
        locationPrecision: locationPrecision,
        serviceSubCategoryId: serviceSubCategoryId,
        workersNeeded: workersNeeded,
        salaryAmount: salaryAmount,
        salaryUnit: salaryUnit,
      ),
    );
    return model.toEntity();
  }

  @override
  Future<HiringPost> updatePost({
    required String id,
    required String title,
    String? description,
    required DateTime eventDate,
    required int durationMinutes,
    String? location,
    double? latitude,
    double? longitude,
    String? locationPrecision,
    String? serviceSubCategoryId,
    required int workersNeeded,
    required double salaryAmount,
    required String salaryUnit,
  }) async {
    final model = await _remoteDataSource.updatePost(
      id,
      _postBody(
        title: title,
        description: description,
        eventDate: eventDate,
        durationMinutes: durationMinutes,
        location: location,
        latitude: latitude,
        longitude: longitude,
        locationPrecision: locationPrecision,
        serviceSubCategoryId: serviceSubCategoryId,
        workersNeeded: workersNeeded,
        salaryAmount: salaryAmount,
        salaryUnit: salaryUnit,
      ),
    );
    return model.toEntity();
  }

  @override
  Future<void> deletePost(String id) => _remoteDataSource.deletePost(id);

  @override
  Future<HiringPost> inviteWorker({
    required String postId,
    required String workerIdentifier,
  }) async => (await _remoteDataSource.inviteWorker(
    postId,
    workerIdentifier,
  )).toEntity();

  @override
  Future<HiringPost> inviteWorkerForDate({
    required String workerIdentifier,
    required DateTime eventDate,
    required double salaryAmount,
  }) async => (await _remoteDataSource.inviteWorkerForDate(
    workerIdentifier: workerIdentifier,
    eventDate: eventDate,
    salaryAmount: salaryAmount,
  )).toEntity();

  @override
  Future<HiringPost> completeWork(String id) async =>
      (await _remoteDataSource.completeWork(id)).toEntity();

  @override
  Future<HiringPost> stopHiring(String id) async =>
      (await _remoteDataSource.stopHiring(id)).toEntity();

  @override
  Future<HiringPost> uploadPostImage(String id, Uint8List imageBytes) async =>
      (await _remoteDataSource.uploadPostImage(id, imageBytes)).toEntity();

  @override
  Future<HiringPost> confirmApplication(String applicationId) async =>
      (await _remoteDataSource.confirmApplication(applicationId)).toEntity();

  @override
  Future<HiringPost> rejectApplication(String applicationId) async =>
      (await _remoteDataSource.rejectApplication(applicationId)).toEntity();

  @override
  Future<HiringPost> raiseAgreedSalary({
    required String applicationId,
    required double newAmount,
    String? reason,
  }) async {
    final model = await _remoteDataSource.raiseAgreedSalary(applicationId, {
      'newAmount': newAmount,
      'reason': reason,
    });
    return model.toEntity();
  }

  @override
  Future<HiringPost> raiseCrewSalary(
    String postId, {
    required double increase,
    String? reason,
  }) async => (await _remoteDataSource.raiseCrewSalary(
    postId,
    increase: increase,
    reason: reason,
  )).toEntity();

  @override
  Future<List<HiringPost>> getOpenPosts({
    double? latitude,
    double? longitude,
    int? radiusKm,
  }) async => (await _remoteDataSource.getOpenPosts(
    latitude: latitude,
    longitude: longitude,
    radiusKm: radiusKm,
  )).map((m) => m.toEntity()).toList();

  @override
  Future<List<HiringPost>> getMyOffers() async =>
      (await _remoteDataSource.getMyOffers()).map((m) => m.toEntity()).toList();

  @override
  Future<List<HiringPost>> getMyPostJobs() async =>
      (await _remoteDataSource.getMyPostJobs())
          .map((m) => m.toEntity())
          .toList();

  @override
  Future<HiringPost> apply(String id) async =>
      (await _remoteDataSource.apply(id)).toEntity();

  @override
  Future<HiringPost> respondToOffer({
    required String applicationId,
    required bool accept,
  }) async => (await _remoteDataSource.respondToOffer(
    applicationId,
    accept: accept,
  )).toEntity();

  @override
  Future<HiringPost> startWork(String id) async =>
      (await _remoteDataSource.startWork(id)).toEntity();

  @override
  Future<void> respondToPayment({
    required String applicationId,
    required bool received,
    String? disputeReason,
  }) => _remoteDataSource.respondToPayment(
    applicationId,
    received: received,
    disputeReason: disputeReason,
  );

  @override
  Future<PayoutBatch> createPayoutBatch({
    required String postId,
    required double expectedTotal,
  }) async => (await _remoteDataSource.createPayoutBatch(
    postId,
    expectedTotal,
  )).toEntity();

  @override
  Future<PayoutBatch> confirmPayoutCollection({
    required String batchId,
    required String providerPaymentId,
    String? signature,
  }) async => (await _remoteDataSource.confirmPayoutCollection(
    batchId,
    providerPaymentId,
    signature,
  )).toEntity();

  /// Create and update take the same payload — the server distinguishes them by verb.
  static Map<String, dynamic> _postBody({
    String? bookingId,
    required String title,
    String? description,
    required DateTime eventDate,
    required int durationMinutes,
    String? location,
    double? latitude,
    double? longitude,
    String? locationPrecision,
    String? serviceSubCategoryId,
    required int workersNeeded,
    required double salaryAmount,
    required String salaryUnit,
  }) => {
    // Only sent when hiring against an order; update never carries it.
    'bookingId': ?bookingId,
    'title': title,
    'description': description,
    'eventDate': eventDate.toUtc().toIso8601String(),
    'durationMinutes': durationMinutes,
    'location': location,
    'latitude': ?latitude,
    'longitude': ?longitude,
    'locationPrecision': ?locationPrecision,
    'serviceSubCategoryId': ?serviceSubCategoryId,
    'workersNeeded': workersNeeded,
    'salaryAmount': salaryAmount,
    'salaryUnit': salaryUnit,
  };
}
