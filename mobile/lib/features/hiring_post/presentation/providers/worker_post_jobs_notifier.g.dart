// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worker_post_jobs_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Work this worker took through a hiring post.
///
/// A worker reaches paid work by two routes and only one of them reached My jobs. That screen is fed
/// by the bookings endpoint — customer orders they were assigned to — so a job taken through a
/// hiring post appeared on the dashboard and in the Find work feed and nowhere a worker could act on
/// it. "1 coming up" on the home page opened to an empty My jobs.
///
/// Read from its own endpoint rather than the Find work feed, which returns nothing until a location
/// is set and is cut to a page: work somebody has already committed to must not depend on a search.

@ProviderFor(workerPostJobs)
final workerPostJobsProvider = WorkerPostJobsProvider._();

/// Work this worker took through a hiring post.
///
/// A worker reaches paid work by two routes and only one of them reached My jobs. That screen is fed
/// by the bookings endpoint — customer orders they were assigned to — so a job taken through a
/// hiring post appeared on the dashboard and in the Find work feed and nowhere a worker could act on
/// it. "1 coming up" on the home page opened to an empty My jobs.
///
/// Read from its own endpoint rather than the Find work feed, which returns nothing until a location
/// is set and is cut to a page: work somebody has already committed to must not depend on a search.

final class WorkerPostJobsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<HiringPost>>,
          List<HiringPost>,
          FutureOr<List<HiringPost>>
        >
    with $FutureModifier<List<HiringPost>>, $FutureProvider<List<HiringPost>> {
  /// Work this worker took through a hiring post.
  ///
  /// A worker reaches paid work by two routes and only one of them reached My jobs. That screen is fed
  /// by the bookings endpoint — customer orders they were assigned to — so a job taken through a
  /// hiring post appeared on the dashboard and in the Find work feed and nowhere a worker could act on
  /// it. "1 coming up" on the home page opened to an empty My jobs.
  ///
  /// Read from its own endpoint rather than the Find work feed, which returns nothing until a location
  /// is set and is cut to a page: work somebody has already committed to must not depend on a search.
  WorkerPostJobsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workerPostJobsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workerPostJobsHash();

  @$internal
  @override
  $FutureProviderElement<List<HiringPost>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<HiringPost>> create(Ref ref) {
    return workerPostJobs(ref);
  }
}

String _$workerPostJobsHash() => r'374b1587d90f4f04db47a87598ed17a9be6ed089';
