// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worker_job_offers_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Jobs a business invited this worker onto, still waiting on an answer.
///
/// Its own provider rather than a filter over the Find work feed, for the same reason the server
/// gives it its own query: the feed is a search. It returns nothing at all until a location is set,
/// it narrows by radius, and it is cut to a page — so an offer read from it could be missing because
/// of a filter the worker set last week, on a screen whose whole purpose is things that need
/// answering.

@ProviderFor(WorkerJobOffersNotifier)
final workerJobOffersProvider = WorkerJobOffersNotifierProvider._();

/// Jobs a business invited this worker onto, still waiting on an answer.
///
/// Its own provider rather than a filter over the Find work feed, for the same reason the server
/// gives it its own query: the feed is a search. It returns nothing at all until a location is set,
/// it narrows by radius, and it is cut to a page — so an offer read from it could be missing because
/// of a filter the worker set last week, on a screen whose whole purpose is things that need
/// answering.
final class WorkerJobOffersNotifierProvider
    extends $AsyncNotifierProvider<WorkerJobOffersNotifier, List<HiringPost>> {
  /// Jobs a business invited this worker onto, still waiting on an answer.
  ///
  /// Its own provider rather than a filter over the Find work feed, for the same reason the server
  /// gives it its own query: the feed is a search. It returns nothing at all until a location is set,
  /// it narrows by radius, and it is cut to a page — so an offer read from it could be missing because
  /// of a filter the worker set last week, on a screen whose whole purpose is things that need
  /// answering.
  WorkerJobOffersNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workerJobOffersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workerJobOffersNotifierHash();

  @$internal
  @override
  WorkerJobOffersNotifier create() => WorkerJobOffersNotifier();
}

String _$workerJobOffersNotifierHash() =>
    r'd66cc116471a5748d39ddcd5eb3eed17364fb291';

/// Jobs a business invited this worker onto, still waiting on an answer.
///
/// Its own provider rather than a filter over the Find work feed, for the same reason the server
/// gives it its own query: the feed is a search. It returns nothing at all until a location is set,
/// it narrows by radius, and it is cut to a page — so an offer read from it could be missing because
/// of a filter the worker set last week, on a screen whose whole purpose is things that need
/// answering.

abstract class _$WorkerJobOffersNotifier
    extends $AsyncNotifier<List<HiringPost>> {
  FutureOr<List<HiringPost>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<HiringPost>>, List<HiringPost>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<HiringPost>>, List<HiringPost>>,
              AsyncValue<List<HiringPost>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
