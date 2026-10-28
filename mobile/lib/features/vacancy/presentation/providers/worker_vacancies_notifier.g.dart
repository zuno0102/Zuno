// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worker_vacancies_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Live full-time vacancies near the worker. Shares the event-work feed's saved location and
/// distance, so a worker sets where they are once for both.

@ProviderFor(WorkerVacanciesNotifier)
final workerVacanciesProvider = WorkerVacanciesNotifierFamily._();

/// Live full-time vacancies near the worker. Shares the event-work feed's saved location and
/// distance, so a worker sets where they are once for both.
final class WorkerVacanciesNotifierProvider
    extends
        $AsyncNotifierProvider<WorkerVacanciesNotifier, PagedList<Vacancy>> {
  /// Live full-time vacancies near the worker. Shares the event-work feed's saved location and
  /// distance, so a worker sets where they are once for both.
  WorkerVacanciesNotifierProvider._({
    required WorkerVacanciesNotifierFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'workerVacanciesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workerVacanciesNotifierHash();

  @override
  String toString() {
    return r'workerVacanciesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  WorkerVacanciesNotifier create() => WorkerVacanciesNotifier();

  @override
  bool operator ==(Object other) {
    return other is WorkerVacanciesNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workerVacanciesNotifierHash() =>
    r'dcc3bbd1a77d9d3cbc9494b782f943ede60f0a90';

/// Live full-time vacancies near the worker. Shares the event-work feed's saved location and
/// distance, so a worker sets where they are once for both.

final class WorkerVacanciesNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          WorkerVacanciesNotifier,
          AsyncValue<PagedList<Vacancy>>,
          PagedList<Vacancy>,
          FutureOr<PagedList<Vacancy>>,
          String?
        > {
  WorkerVacanciesNotifierFamily._()
    : super(
        retry: null,
        name: r'workerVacanciesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Live full-time vacancies near the worker. Shares the event-work feed's saved location and
  /// distance, so a worker sets where they are once for both.

  WorkerVacanciesNotifierProvider call({String? jobTypeId}) =>
      WorkerVacanciesNotifierProvider._(argument: jobTypeId, from: this);

  @override
  String toString() => r'workerVacanciesProvider';
}

/// Live full-time vacancies near the worker. Shares the event-work feed's saved location and
/// distance, so a worker sets where they are once for both.

abstract class _$WorkerVacanciesNotifier
    extends $AsyncNotifier<PagedList<Vacancy>> {
  late final _$args = ref.$arg as String?;
  String? get jobTypeId => _$args;

  FutureOr<PagedList<Vacancy>> build({String? jobTypeId});
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<PagedList<Vacancy>>, PagedList<Vacancy>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PagedList<Vacancy>>, PagedList<Vacancy>>,
              AsyncValue<PagedList<Vacancy>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(jobTypeId: _$args));
  }
}

/// The vacancies this worker has applied to, newest application first.

@ProviderFor(myVacancyApplications)
final myVacancyApplicationsProvider = MyVacancyApplicationsProvider._();

/// The vacancies this worker has applied to, newest application first.

final class MyVacancyApplicationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Vacancy>>,
          List<Vacancy>,
          FutureOr<List<Vacancy>>
        >
    with $FutureModifier<List<Vacancy>>, $FutureProvider<List<Vacancy>> {
  /// The vacancies this worker has applied to, newest application first.
  MyVacancyApplicationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myVacancyApplicationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myVacancyApplicationsHash();

  @$internal
  @override
  $FutureProviderElement<List<Vacancy>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Vacancy>> create(Ref ref) {
    return myVacancyApplications(ref);
  }
}

String _$myVacancyApplicationsHash() =>
    r'59ceb294bae0b6dda6e1d38456edfb72484ee557';
