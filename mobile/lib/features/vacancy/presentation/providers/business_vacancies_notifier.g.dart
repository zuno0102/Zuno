// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_vacancies_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The business's own full-time vacancies, in every state.

@ProviderFor(BusinessVacanciesNotifier)
final businessVacanciesProvider = BusinessVacanciesNotifierProvider._();

/// The business's own full-time vacancies, in every state.
final class BusinessVacanciesNotifierProvider
    extends
        $AsyncNotifierProvider<BusinessVacanciesNotifier, PagedList<Vacancy>> {
  /// The business's own full-time vacancies, in every state.
  BusinessVacanciesNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'businessVacanciesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$businessVacanciesNotifierHash();

  @$internal
  @override
  BusinessVacanciesNotifier create() => BusinessVacanciesNotifier();
}

String _$businessVacanciesNotifierHash() =>
    r'41dedb3288a0262041637f8172764905924bc4d1';

/// The business's own full-time vacancies, in every state.

abstract class _$BusinessVacanciesNotifier
    extends $AsyncNotifier<PagedList<Vacancy>> {
  FutureOr<PagedList<Vacancy>> build();
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
    return element.handleCreate(ref, build);
  }
}
