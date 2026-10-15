// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worker_hiring_posts_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WorkerHiringPostsNotifier)
final workerHiringPostsProvider = WorkerHiringPostsNotifierProvider._();

final class WorkerHiringPostsNotifierProvider
    extends
        $AsyncNotifierProvider<WorkerHiringPostsNotifier, List<HiringPost>> {
  WorkerHiringPostsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workerHiringPostsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workerHiringPostsNotifierHash();

  @$internal
  @override
  WorkerHiringPostsNotifier create() => WorkerHiringPostsNotifier();
}

String _$workerHiringPostsNotifierHash() =>
    r'ecab0ecc243816f39a7b7dd411756ef83f9642c5';

abstract class _$WorkerHiringPostsNotifier
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
