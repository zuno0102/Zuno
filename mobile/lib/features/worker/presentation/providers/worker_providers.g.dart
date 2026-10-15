// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worker_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(workerRemoteDataSource)
final workerRemoteDataSourceProvider = WorkerRemoteDataSourceProvider._();

final class WorkerRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          WorkerRemoteDataSource,
          WorkerRemoteDataSource,
          WorkerRemoteDataSource
        >
    with $Provider<WorkerRemoteDataSource> {
  WorkerRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workerRemoteDataSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workerRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<WorkerRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkerRemoteDataSource create(Ref ref) {
    return workerRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkerRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkerRemoteDataSource>(value),
    );
  }
}

String _$workerRemoteDataSourceHash() =>
    r'4a84d4a21896d061074cee157f09987f8f4456d0';

@ProviderFor(workerInvitationRepository)
final workerInvitationRepositoryProvider =
    WorkerInvitationRepositoryProvider._();

final class WorkerInvitationRepositoryProvider
    extends
        $FunctionalProvider<
          WorkerInvitationRepository,
          WorkerInvitationRepository,
          WorkerInvitationRepository
        >
    with $Provider<WorkerInvitationRepository> {
  WorkerInvitationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workerInvitationRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workerInvitationRepositoryHash();

  @$internal
  @override
  $ProviderElement<WorkerInvitationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkerInvitationRepository create(Ref ref) {
    return workerInvitationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkerInvitationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkerInvitationRepository>(value),
    );
  }
}

String _$workerInvitationRepositoryHash() =>
    r'a769765671eb73d701fd63d6ff76d097ca577af5';

@ProviderFor(workerProfile)
final workerProfileProvider = WorkerProfileProvider._();

final class WorkerProfileProvider
    extends
        $FunctionalProvider<
          AsyncValue<WorkerProfile>,
          WorkerProfile,
          FutureOr<WorkerProfile>
        >
    with $FutureModifier<WorkerProfile>, $FutureProvider<WorkerProfile> {
  WorkerProfileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workerProfileProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workerProfileHash();

  @$internal
  @override
  $FutureProviderElement<WorkerProfile> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<WorkerProfile> create(Ref ref) {
    return workerProfile(ref);
  }
}

String _$workerProfileHash() => r'be1a8efc0d97c85b23316ec3ba15952ebb5043e9';

@ProviderFor(hiringBusiness)
final hiringBusinessProvider = HiringBusinessFamily._();

final class HiringBusinessProvider
    extends
        $FunctionalProvider<
          AsyncValue<HiringBusiness>,
          HiringBusiness,
          FutureOr<HiringBusiness>
        >
    with $FutureModifier<HiringBusiness>, $FutureProvider<HiringBusiness> {
  HiringBusinessProvider._({
    required HiringBusinessFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'hiringBusinessProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$hiringBusinessHash();

  @override
  String toString() {
    return r'hiringBusinessProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<HiringBusiness> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<HiringBusiness> create(Ref ref) {
    final argument = this.argument as String;
    return hiringBusiness(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is HiringBusinessProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$hiringBusinessHash() => r'36e6f69de63ed847a97e639cda4c4e922b13b246';

final class HiringBusinessFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<HiringBusiness>, String> {
  HiringBusinessFamily._()
    : super(
        retry: null,
        name: r'hiringBusinessProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  HiringBusinessProvider call(String businessId) =>
      HiringBusinessProvider._(argument: businessId, from: this);

  @override
  String toString() => r'hiringBusinessProvider';
}
