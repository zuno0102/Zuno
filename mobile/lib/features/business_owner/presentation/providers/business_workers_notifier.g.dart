// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_workers_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BusinessWorkersNotifier)
final businessWorkersProvider = BusinessWorkersNotifierProvider._();

final class BusinessWorkersNotifierProvider
    extends
        $AsyncNotifierProvider<BusinessWorkersNotifier, List<BusinessWorker>> {
  BusinessWorkersNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'businessWorkersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$businessWorkersNotifierHash();

  @$internal
  @override
  BusinessWorkersNotifier create() => BusinessWorkersNotifier();
}

String _$businessWorkersNotifierHash() =>
    r'05b447935c2687af306bd1425e9ea3d28e836990';

abstract class _$BusinessWorkersNotifier
    extends $AsyncNotifier<List<BusinessWorker>> {
  FutureOr<List<BusinessWorker>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<BusinessWorker>>, List<BusinessWorker>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<BusinessWorker>>,
                List<BusinessWorker>
              >,
              AsyncValue<List<BusinessWorker>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
