// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worker_job_filter_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WorkerJobFilterNotifier)
final workerJobFilterProvider = WorkerJobFilterNotifierProvider._();

final class WorkerJobFilterNotifierProvider
    extends $NotifierProvider<WorkerJobFilterNotifier, WorkerJobFilter> {
  WorkerJobFilterNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workerJobFilterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workerJobFilterNotifierHash();

  @$internal
  @override
  WorkerJobFilterNotifier create() => WorkerJobFilterNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkerJobFilter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkerJobFilter>(value),
    );
  }
}

String _$workerJobFilterNotifierHash() =>
    r'57d1bae37d6e2966502eb7ca06cdbd5b1e92e42c';

abstract class _$WorkerJobFilterNotifier extends $Notifier<WorkerJobFilter> {
  WorkerJobFilter build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<WorkerJobFilter, WorkerJobFilter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<WorkerJobFilter, WorkerJobFilter>,
              WorkerJobFilter,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
