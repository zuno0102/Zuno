import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/presentation/providers/hiring_post_providers.dart';
import 'package:zuno/features/worker/presentation/providers/worker_job_filter_provider.dart';

part 'worker_hiring_posts_notifier.g.dart';

@riverpod
class WorkerHiringPostsNotifier extends _$WorkerHiringPostsNotifier {
  /// Watches the filter, so choosing a radius refetches on its own.
  ///
  /// Returns nothing until a location is set. Searching for work is anchored to a place now, and
  /// fetching every open post in the country to then hide it would be a wasted round trip on a
  /// phone connection — the screen shows the location prompt instead.
  ///
  /// The coarse coordinates are sent rather than the exact ones: the request URL is logged on both
  /// sides, and 110m of precision is irrelevant at these radii.
  @override
  Future<List<HiringPost>> build() {
    final filter = ref.watch(workerJobFilterProvider);

    if (!filter.hasPosition) {
      return Future.value(const []);
    }

    return ref.read(hiringPostRepositoryProvider).getOpenPosts(
      latitude: filter.coarseLatitude,
      longitude: filter.coarseLongitude,
      radiusKm: filter.radiusKm,
    );
  }


  Future<void> apply(String id) async {
    await ref.read(hiringPostRepositoryProvider).apply(id);
    await _refresh();
  }

  /// Accepts or declines an offer the business has made. Accepting is what actually
  /// takes the job; declining hands the slot back to the post.
  Future<void> respondToOffer({
    required String applicationId,
    required bool accept,
  }) async {
    await ref
        .read(hiringPostRepositoryProvider)
        .respondToOffer(applicationId: applicationId, accept: accept);
    await _refresh();
  }

  /// Confirms wages arrived, or reports that they never did.
  ///
  /// A business marking someone paid is only its own word. This is the worker's, and a report
  /// here is what raises the dispute that holds the job open and flags the business.
  Future<void> respondToPayment({
    required String applicationId,
    required bool received,
    String? disputeReason,
  }) async {
    await ref
        .read(hiringPostRepositoryProvider)
        .respondToPayment(
          applicationId: applicationId,
          received: received,
          disputeReason: disputeReason,
        );
    await _refresh();
  }

  Future<void> _refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () {
        final filter = ref.read(workerJobFilterProvider);
        if (!filter.hasPosition) return Future.value(const <HiringPost>[]);
        return ref.read(hiringPostRepositoryProvider).getOpenPosts(
          latitude: filter.coarseLatitude,
          longitude: filter.coarseLongitude,
          radiusKm: filter.radiusKm,
        );
      },
    );
  }
}
