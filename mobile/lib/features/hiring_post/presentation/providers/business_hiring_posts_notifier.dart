import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/domain/entities/payout_batch.dart';
import 'package:zuno/features/hiring_post/presentation/providers/hiring_post_providers.dart';

part 'business_hiring_posts_notifier.g.dart';

@riverpod
class BusinessHiringPostsNotifier extends _$BusinessHiringPostsNotifier {
  @override
  Future<List<HiringPost>> build() =>
      ref.watch(hiringPostRepositoryProvider).getMyPosts();

  Future<HiringPost> createPost({
    String? bookingId,
    required String title,
    String? description,
    required DateTime eventDate,
    required int durationMinutes,
    String? location,
    String? serviceSubCategoryId,
    required int workersNeeded,
    required double salaryAmount,
    required String salaryUnit,
  }) async {
    final created = await ref
        .read(hiringPostRepositoryProvider)
        .createPost(
          bookingId: bookingId,
          title: title,
          description: description,
          eventDate: eventDate,
          durationMinutes: durationMinutes,
          location: location,
          serviceSubCategoryId: serviceSubCategoryId,
          workersNeeded: workersNeeded,
          salaryAmount: salaryAmount,
          salaryUnit: salaryUnit,
        );
    await _refresh();
    return created;
  }

  Future<HiringPost> updatePost({
    required String id,
    required String title,
    String? description,
    required DateTime eventDate,
    required int durationMinutes,
    String? location,
    String? serviceSubCategoryId,
    required int workersNeeded,
    required double salaryAmount,
    required String salaryUnit,
  }) async {
    final updated = await ref
        .read(hiringPostRepositoryProvider)
        .updatePost(
          id: id,
          title: title,
          description: description,
          eventDate: eventDate,
          durationMinutes: durationMinutes,
          location: location,
          serviceSubCategoryId: serviceSubCategoryId,
          workersNeeded: workersNeeded,
          salaryAmount: salaryAmount,
          salaryUnit: salaryUnit,
        );
    await _refresh();
    return updated;
  }

  Future<void> deletePost(String id) async {
    await ref.read(hiringPostRepositoryProvider).deletePost(id);
    await _refresh();
  }

  Future<void> inviteWorker({
    required String postId,
    required String workerIdentifier,
  }) async {
    await ref
        .read(hiringPostRepositoryProvider)
        .inviteWorker(postId: postId, workerIdentifier: workerIdentifier);
    await _refresh();
  }

  Future<void> startWork(String id) async {
    await ref.read(hiringPostRepositoryProvider).startWork(id);
    await _refresh();
  }

  Future<void> completeWork(String id) async {
    await ref.read(hiringPostRepositoryProvider).completeWork(id);
    await _refresh();
  }

  /// Opens a pay run without paying anything, so the crew and total can be reviewed first.
  ///
  /// [expectedTotal] is the figure the card is showing. Sending it lets the server refuse
  /// the run outright if the two disagree, rather than paying an amount the business was
  /// never shown.
  Future<PayoutBatch> startPayRun({
    required String postId,
    required double expectedTotal,
  }) => ref
      .read(hiringPostRepositoryProvider)
      .createPayoutBatch(postId: postId, expectedTotal: expectedTotal);

  /// Completes the run: one payment from the business, split to every worker.
  ///
  /// [providerPaymentId] stands in for what a real gateway hands back after the PIN. It
  /// doubles as the idempotency key, so a retried tap settles the run once.
  Future<PayoutBatch> payCrew({
    required String batchId,
    required String providerPaymentId,
    String? signature,
  }) async {
    final batch = await ref
        .read(hiringPostRepositoryProvider)
        .confirmPayoutCollection(
          batchId: batchId,
          providerPaymentId: providerPaymentId,
          signature: signature,
        );
    await _refresh();
    return batch;
  }

  Future<void> uploadImage(String id, Uint8List imageBytes) async {
    await ref
        .read(hiringPostRepositoryProvider)
        .uploadPostImage(id, imageBytes);
    await _refresh();
  }

  Future<void> confirmApplication(String applicationId) async {
    await ref
        .read(hiringPostRepositoryProvider)
        .confirmApplication(applicationId);
    await _refresh();
  }

  Future<void> rejectApplication(String applicationId) async {
    await ref
        .read(hiringPostRepositoryProvider)
        .rejectApplication(applicationId);
    await _refresh();
  }

  Future<void> raiseAgreedSalary({
    required String applicationId,
    required double newAmount,
    String? reason,
  }) async {
    await ref
        .read(hiringPostRepositoryProvider)
        .raiseAgreedSalary(
          applicationId: applicationId,
          newAmount: newAmount,
          reason: reason,
        );
    await _refresh();
  }

  Future<void> _refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(hiringPostRepositoryProvider).getMyPosts(),
    );
  }
}
