// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vacancy_applicants_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One applicant list — New, Waiting, Shortlisted or Hired — for one vacancy, or with a null
/// [vacancyId] for every vacancy the business owns (what the home screen's tiles open).

@ProviderFor(VacancyApplicantsNotifier)
final vacancyApplicantsProvider = VacancyApplicantsNotifierFamily._();

/// One applicant list — New, Waiting, Shortlisted or Hired — for one vacancy, or with a null
/// [vacancyId] for every vacancy the business owns (what the home screen's tiles open).
final class VacancyApplicantsNotifierProvider
    extends
        $AsyncNotifierProvider<
          VacancyApplicantsNotifier,
          PagedList<VacancyApplication>
        > {
  /// One applicant list — New, Waiting, Shortlisted or Hired — for one vacancy, or with a null
  /// [vacancyId] for every vacancy the business owns (what the home screen's tiles open).
  VacancyApplicantsNotifierProvider._({
    required VacancyApplicantsNotifierFamily super.from,
    required (String?, {String status}) super.argument,
  }) : super(
         retry: null,
         name: r'vacancyApplicantsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$vacancyApplicantsNotifierHash();

  @override
  String toString() {
    return r'vacancyApplicantsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  VacancyApplicantsNotifier create() => VacancyApplicantsNotifier();

  @override
  bool operator ==(Object other) {
    return other is VacancyApplicantsNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$vacancyApplicantsNotifierHash() =>
    r'90f84f47f80fa3faf37a65de7d5e9da07711ccb7';

/// One applicant list — New, Waiting, Shortlisted or Hired — for one vacancy, or with a null
/// [vacancyId] for every vacancy the business owns (what the home screen's tiles open).

final class VacancyApplicantsNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          VacancyApplicantsNotifier,
          AsyncValue<PagedList<VacancyApplication>>,
          PagedList<VacancyApplication>,
          FutureOr<PagedList<VacancyApplication>>,
          (String?, {String status})
        > {
  VacancyApplicantsNotifierFamily._()
    : super(
        retry: null,
        name: r'vacancyApplicantsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One applicant list — New, Waiting, Shortlisted or Hired — for one vacancy, or with a null
  /// [vacancyId] for every vacancy the business owns (what the home screen's tiles open).

  VacancyApplicantsNotifierProvider call(
    String? vacancyId, {
    required String status,
  }) => VacancyApplicantsNotifierProvider._(
    argument: (vacancyId, status: status),
    from: this,
  );

  @override
  String toString() => r'vacancyApplicantsProvider';
}

/// One applicant list — New, Waiting, Shortlisted or Hired — for one vacancy, or with a null
/// [vacancyId] for every vacancy the business owns (what the home screen's tiles open).

abstract class _$VacancyApplicantsNotifier
    extends $AsyncNotifier<PagedList<VacancyApplication>> {
  late final _$args = ref.$arg as (String?, {String status});
  String? get vacancyId => _$args.$1;
  String get status => _$args.status;

  FutureOr<PagedList<VacancyApplication>> build(
    String? vacancyId, {
    required String status,
  });
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<PagedList<VacancyApplication>>,
              PagedList<VacancyApplication>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<PagedList<VacancyApplication>>,
                PagedList<VacancyApplication>
              >,
              AsyncValue<PagedList<VacancyApplication>>,
              Object?,
              Object?
            >;
    return element.handleCreate(
      ref,
      () => build(_$args.$1, status: _$args.status),
    );
  }
}
