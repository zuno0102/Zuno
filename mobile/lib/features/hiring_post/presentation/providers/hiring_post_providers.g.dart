// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hiring_post_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(hiringPostRemoteDataSource)
final hiringPostRemoteDataSourceProvider =
    HiringPostRemoteDataSourceProvider._();

final class HiringPostRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          HiringPostRemoteDataSource,
          HiringPostRemoteDataSource,
          HiringPostRemoteDataSource
        >
    with $Provider<HiringPostRemoteDataSource> {
  HiringPostRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hiringPostRemoteDataSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hiringPostRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<HiringPostRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  HiringPostRemoteDataSource create(Ref ref) {
    return hiringPostRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HiringPostRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HiringPostRemoteDataSource>(value),
    );
  }
}

String _$hiringPostRemoteDataSourceHash() =>
    r'0d2a7abec21bc69ab86626034d661a0cc890cad5';

@ProviderFor(hiringPostRepository)
final hiringPostRepositoryProvider = HiringPostRepositoryProvider._();

final class HiringPostRepositoryProvider
    extends
        $FunctionalProvider<
          HiringPostRepository,
          HiringPostRepository,
          HiringPostRepository
        >
    with $Provider<HiringPostRepository> {
  HiringPostRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hiringPostRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hiringPostRepositoryHash();

  @$internal
  @override
  $ProviderElement<HiringPostRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  HiringPostRepository create(Ref ref) {
    return hiringPostRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HiringPostRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HiringPostRepository>(value),
    );
  }
}

String _$hiringPostRepositoryHash() =>
    r'a375c9ab9a65be9678f353cbb629bffd41957b75';
