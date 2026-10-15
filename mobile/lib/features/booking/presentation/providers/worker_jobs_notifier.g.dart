// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worker_jobs_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WorkerJobsNotifier)
final workerJobsProvider = WorkerJobsNotifierProvider._();

final class WorkerJobsNotifierProvider
    extends $AsyncNotifierProvider<WorkerJobsNotifier, List<Booking>> {
  WorkerJobsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workerJobsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workerJobsNotifierHash();

  @$internal
  @override
  WorkerJobsNotifier create() => WorkerJobsNotifier();
}

String _$workerJobsNotifierHash() =>
    r'13e56f17a70d1218227d0393d085aabb8fd34499';

abstract class _$WorkerJobsNotifier extends $AsyncNotifier<List<Booking>> {
  FutureOr<List<Booking>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Booking>>, List<Booking>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Booking>>, List<Booking>>,
              AsyncValue<List<Booking>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
