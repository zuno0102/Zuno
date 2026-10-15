// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_catalog_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(adminCatalogRemoteDataSource)
final adminCatalogRemoteDataSourceProvider =
    AdminCatalogRemoteDataSourceProvider._();

final class AdminCatalogRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          AdminCatalogRemoteDataSource,
          AdminCatalogRemoteDataSource,
          AdminCatalogRemoteDataSource
        >
    with $Provider<AdminCatalogRemoteDataSource> {
  AdminCatalogRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'adminCatalogRemoteDataSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$adminCatalogRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<AdminCatalogRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AdminCatalogRemoteDataSource create(Ref ref) {
    return adminCatalogRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AdminCatalogRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AdminCatalogRemoteDataSource>(value),
    );
  }
}

String _$adminCatalogRemoteDataSourceHash() =>
    r'6921b438e455435c0ee497b88c54341033f98a6e';

@ProviderFor(adminCatalogRepository)
final adminCatalogRepositoryProvider = AdminCatalogRepositoryProvider._();

final class AdminCatalogRepositoryProvider
    extends
        $FunctionalProvider<
          AdminCatalogRepository,
          AdminCatalogRepository,
          AdminCatalogRepository
        >
    with $Provider<AdminCatalogRepository> {
  AdminCatalogRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'adminCatalogRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$adminCatalogRepositoryHash();

  @$internal
  @override
  $ProviderElement<AdminCatalogRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AdminCatalogRepository create(Ref ref) {
    return adminCatalogRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AdminCatalogRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AdminCatalogRepository>(value),
    );
  }
}

String _$adminCatalogRepositoryHash() =>
    r'4f5310b3d09cfc7e6902e6aa75bed97513bd5fa5';

/// The whole catalogue, and the app owner's edits to it.

@ProviderFor(AdminCatalogNotifier)
final adminCatalogProvider = AdminCatalogNotifierProvider._();

/// The whole catalogue, and the app owner's edits to it.
final class AdminCatalogNotifierProvider
    extends
        $AsyncNotifierProvider<AdminCatalogNotifier, List<CatalogCategory>> {
  /// The whole catalogue, and the app owner's edits to it.
  AdminCatalogNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'adminCatalogProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$adminCatalogNotifierHash();

  @$internal
  @override
  AdminCatalogNotifier create() => AdminCatalogNotifier();
}

String _$adminCatalogNotifierHash() =>
    r'9bb6310df7db8be929a02be833eeb9328963e0c1';

/// The whole catalogue, and the app owner's edits to it.

abstract class _$AdminCatalogNotifier
    extends $AsyncNotifier<List<CatalogCategory>> {
  FutureOr<List<CatalogCategory>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<CatalogCategory>>, List<CatalogCategory>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<CatalogCategory>>,
                List<CatalogCategory>
              >,
              AsyncValue<List<CatalogCategory>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
