import 'dart:typed_data';

import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/domain/entities/payout_batch.dart';

abstract interface class HiringPostRepository {
  Future<List<HiringPost>> getMyPosts();

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
  });

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
  });

  Future<void> deletePost(String id);

  /// Invites a known worker straight onto the post, creating a pending offer they answer.
  Future<HiringPost> inviteWorker({
    required String postId,
    required String workerIdentifier,
  });

  /// Offers a worker a single date, raising the job for it in the same step.
  ///
  /// For work there is no post for. Unlike adding someone to the workers list, which holds one
  /// row per worker and so can only be done once, this can be repeated for every date needed.
  Future<HiringPost> inviteWorkerForDate({
    required String workerIdentifier,
    required DateTime eventDate,
    required double salaryAmount,
    String? serviceSubCategoryId,
    String? location,
  });

  /// Marks the work done, releasing the crew for other jobs.
  Future<HiringPost> completeWork(String id);

  /// Closes the vacancy for good; the business will manage with the crew it has.
  Future<HiringPost> stopHiring(String id);

  Future<HiringPost> uploadPostImage(String id, Uint8List imageBytes);

  Future<HiringPost> confirmApplication(String applicationId);

  Future<HiringPost> rejectApplication(String applicationId);

  /// Increases a confirmed worker's agreed salary. The server rejects any amount
  /// that is not strictly greater than the current one.
  Future<HiringPost> raiseAgreedSalary({
    required String applicationId,
    required double newAmount,
    String? reason,
  });

  /// The same extra pay for everyone on the post still to be paid: ₹1,000 + ₹200 each.
  Future<HiringPost> raiseCrewSalary(
    String postId, {
    required double increase,
    String? reason,
  });

  Future<List<HiringPost>> getOpenPosts({
    double? latitude,
    double? longitude,
    int? radiusKm,
  });

  /// Jobs this worker was invited onto, still waiting on an answer.
  Future<List<HiringPost>> getMyOffers();

  /// Work this worker took through a hiring post, past and future.
  Future<List<HiringPost>> getMyPostJobs();

  Future<HiringPost> apply(String id);

  /// Accepts or declines a business offer. Only accepting fills the vacancy.
  Future<HiringPost> respondToOffer({
    required String applicationId,
    required bool accept,
  });

  /// Records that the crew has started on the day.
  Future<HiringPost> startWork(String id);

  /// The worker's answer on whether their wages arrived. Refusing raises a dispute.
  Future<void> respondToPayment({
    required String applicationId,
    required bool received,
    String? disputeReason,
  });

  /// Opens a pay run for everyone still owed on a job.
  ///
  /// [expectedTotal] is what the app believes is owed. It is sent purely so a
  /// disagreement with the server's own figure is caught and refused — the server
  /// never pays this number.
  Future<PayoutBatch> createPayoutBatch({
    required String postId,
    required double expectedTotal,
  });

  /// Confirms the business's single payment cleared, splitting it to each worker.
  Future<PayoutBatch> confirmPayoutCollection({
    required String batchId,
    required String providerPaymentId,

    /// Razorpay's signature over the order and payment. Verified server-side before a rupee moves.
    String? signature,
  });
}
