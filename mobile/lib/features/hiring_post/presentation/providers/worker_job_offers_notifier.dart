import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/presentation/providers/hiring_post_providers.dart';

part 'worker_job_offers_notifier.g.dart';

/// Jobs a business invited this worker onto, still waiting on an answer.
///
/// Its own provider rather than a filter over the Find work feed, for the same reason the server
/// gives it its own query: the feed is a search. It returns nothing at all until a location is set,
/// it narrows by radius, and it is cut to a page — so an offer read from it could be missing because
/// of a filter the worker set last week, on a screen whose whole purpose is things that need
/// answering.
@riverpod
class WorkerJobOffersNotifier extends _$WorkerJobOffersNotifier {
  @override
  Future<List<HiringPost>> build() =>
      ref.watch(hiringPostRepositoryProvider).getMyOffers();

  /// Accepts or declines one, and drops it from the list either way.
  ///
  /// Accepting is what actually takes the job; declining hands the place back to the post. Both
  /// answers end the offer, so the row goes in both cases.
  Future<void> respond({
    required String applicationId,
    required bool accept,
  }) async {
    // Taken before the await, because the list reloads afterwards and reading through `ref` on a
    // notifier that has been disposed in the meantime throws.
    final repository = ref.read(hiringPostRepositoryProvider);
    await repository.respondToOffer(applicationId: applicationId, accept: accept);

    if (!ref.mounted) return;
    state = AsyncData(await repository.getMyOffers());
  }
}
