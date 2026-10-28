// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vacancy_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(vacancyRemoteDataSource)
final vacancyRemoteDataSourceProvider = VacancyRemoteDataSourceProvider._();

final class VacancyRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          VacancyRemoteDataSource,
          VacancyRemoteDataSource,
          VacancyRemoteDataSource
        >
    with $Provider<VacancyRemoteDataSource> {
  VacancyRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vacancyRemoteDataSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vacancyRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<VacancyRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VacancyRemoteDataSource create(Ref ref) {
    return vacancyRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VacancyRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VacancyRemoteDataSource>(value),
    );
  }
}

String _$vacancyRemoteDataSourceHash() =>
    r'a8f738be31617d5451b0db5b47998f1e68335a2c';

@ProviderFor(vacancyRepository)
final vacancyRepositoryProvider = VacancyRepositoryProvider._();

final class VacancyRepositoryProvider
    extends
        $FunctionalProvider<
          VacancyRepository,
          VacancyRepository,
          VacancyRepository
        >
    with $Provider<VacancyRepository> {
  VacancyRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vacancyRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vacancyRepositoryHash();

  @$internal
  @override
  $ProviderElement<VacancyRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VacancyRepository create(Ref ref) {
    return vacancyRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VacancyRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VacancyRepository>(value),
    );
  }
}

String _$vacancyRepositoryHash() => r'6633857f676368560e597600422b986b39b5e586';

/// Job types, fee plans and upload rules. Reference data, so kept for the session.

@ProviderFor(vacancyOptions)
final vacancyOptionsProvider = VacancyOptionsFamily._();

/// Job types, fee plans and upload rules. Reference data, so kept for the session.

final class VacancyOptionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<VacancyOptions>,
          VacancyOptions,
          FutureOr<VacancyOptions>
        >
    with $FutureModifier<VacancyOptions>, $FutureProvider<VacancyOptions> {
  /// Job types, fee plans and upload rules. Reference data, so kept for the session.
  VacancyOptionsProvider._({
    required VacancyOptionsFamily super.from,
    required bool super.argument,
  }) : super(
         retry: null,
         name: r'vacancyOptionsProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$vacancyOptionsHash();

  @override
  String toString() {
    return r'vacancyOptionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<VacancyOptions> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<VacancyOptions> create(Ref ref) {
    final argument = this.argument as bool;
    return vacancyOptions(ref, asWorker: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is VacancyOptionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$vacancyOptionsHash() => r'cee360ab9023fbd931eb5e9a1a4d18a5c7eb8703';

/// Job types, fee plans and upload rules. Reference data, so kept for the session.

final class VacancyOptionsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<VacancyOptions>, bool> {
  VacancyOptionsFamily._()
    : super(
        retry: null,
        name: r'vacancyOptionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Job types, fee plans and upload rules. Reference data, so kept for the session.

  VacancyOptionsProvider call({required bool asWorker}) =>
      VacancyOptionsProvider._(argument: asWorker, from: this);

  @override
  String toString() => r'vacancyOptionsProvider';
}

/// The business home screen's full-time hiring numbers. Refreshed whenever a vacancy or applicant
/// changes, so the tiles never lag the lists they lead to.

@ProviderFor(vacancySummary)
final vacancySummaryProvider = VacancySummaryProvider._();

/// The business home screen's full-time hiring numbers. Refreshed whenever a vacancy or applicant
/// changes, so the tiles never lag the lists they lead to.

final class VacancySummaryProvider
    extends
        $FunctionalProvider<
          AsyncValue<VacancySummary>,
          VacancySummary,
          FutureOr<VacancySummary>
        >
    with $FutureModifier<VacancySummary>, $FutureProvider<VacancySummary> {
  /// The business home screen's full-time hiring numbers. Refreshed whenever a vacancy or applicant
  /// changes, so the tiles never lag the lists they lead to.
  VacancySummaryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vacancySummaryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vacancySummaryHash();

  @$internal
  @override
  $FutureProviderElement<VacancySummary> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<VacancySummary> create(Ref ref) {
    return vacancySummary(ref);
  }
}

String _$vacancySummaryHash() => r'92839b671af167246bd1d6d5f5217c3fe1c4a44a';

/// One vacancy as a worker sees it, for the detail screen and after a notification tap.

@ProviderFor(workerVacancy)
final workerVacancyProvider = WorkerVacancyFamily._();

/// One vacancy as a worker sees it, for the detail screen and after a notification tap.

final class WorkerVacancyProvider
    extends $FunctionalProvider<AsyncValue<Vacancy>, Vacancy, FutureOr<Vacancy>>
    with $FutureModifier<Vacancy>, $FutureProvider<Vacancy> {
  /// One vacancy as a worker sees it, for the detail screen and after a notification tap.
  WorkerVacancyProvider._({
    required WorkerVacancyFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'workerVacancyProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workerVacancyHash();

  @override
  String toString() {
    return r'workerVacancyProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Vacancy> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Vacancy> create(Ref ref) {
    final argument = this.argument as String;
    return workerVacancy(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkerVacancyProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workerVacancyHash() => r'01e153be1e4a1a32a113341f59c73375ab249d71';

/// One vacancy as a worker sees it, for the detail screen and after a notification tap.

final class WorkerVacancyFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Vacancy>, String> {
  WorkerVacancyFamily._()
    : super(
        retry: null,
        name: r'workerVacancyProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One vacancy as a worker sees it, for the detail screen and after a notification tap.

  WorkerVacancyProvider call(String id) =>
      WorkerVacancyProvider._(argument: id, from: this);

  @override
  String toString() => r'workerVacancyProvider';
}
