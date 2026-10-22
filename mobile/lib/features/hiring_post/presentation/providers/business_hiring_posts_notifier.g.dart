// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_hiring_posts_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BusinessHiringPostsNotifier)
final businessHiringPostsProvider = BusinessHiringPostsNotifierProvider._();

final class BusinessHiringPostsNotifierProvider
    extends
        $AsyncNotifierProvider<BusinessHiringPostsNotifier, List<HiringPost>> {
  BusinessHiringPostsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'businessHiringPostsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$businessHiringPostsNotifierHash();

  @$internal
  @override
  BusinessHiringPostsNotifier create() => BusinessHiringPostsNotifier();
}

String _$businessHiringPostsNotifierHash() =>
    r'fbc13b0037826035ab68daac73f44258d19ba7fc';

abstract class _$BusinessHiringPostsNotifier
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
