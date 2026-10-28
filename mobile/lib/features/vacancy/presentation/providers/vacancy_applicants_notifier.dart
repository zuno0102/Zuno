import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_application.dart';
import 'package:zuno/features/vacancy/presentation/providers/business_vacancies_notifier.dart';
import 'package:zuno/features/vacancy/presentation/providers/paged_list.dart';
import 'package:zuno/features/vacancy/presentation/providers/vacancy_providers.dart';

part 'vacancy_applicants_notifier.g.dart';

/// One applicant list — New, Waiting, Shortlisted or Hired — for one vacancy, or with a null
/// [vacancyId] for every vacancy the business owns (what the home screen's tiles open).
@riverpod
class VacancyApplicantsNotifier extends _$VacancyApplicantsNotifier {
  @override
  Future<PagedList<VacancyApplication>> build(
    String? vacancyId, {
    required String status,
  }) async {
    final page = await ref
        .watch(vacancyRepositoryProvider)
        .getApplications(vacancyId, status: status);
    return PagedList(items: page.items, nextBefore: page.nextBefore);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    final page = await ref
        .read(vacancyRepositoryProvider)
        .getApplications(vacancyId, status: status, before: current.nextBefore);
    state = AsyncData(
      PagedList(
        items: [...current.items, ...page.items],
        nextBefore: page.nextBefore,
      ),
    );
  }
}

/// What a business does with an applicant. Every change moves them between lists, so each one
/// refreshes all of the vacancy's lists and its counts rather than patching one list.
///
/// Takes the container, not a list's ref: an action started from one list must finish even if the
/// business has moved on to another tab and that list has been disposed.
class VacancyApplicantActions {
  const VacancyApplicantActions(this._container);

  final ProviderContainer _container;

  /// Opening an applicant: New moves to Waiting. Only refreshes when that actually happened.
  Future<VacancyApplication> open(VacancyApplication application) async {
    final opened = await _container
        .read(vacancyRepositoryProvider)
        .markViewed(application.id);
    if (opened.status != application.status) _refresh();
    return opened;
  }

  /// Shortlist, hire or reject.
  Future<void> decide(String applicationId, String status) async {
    await _container
        .read(vacancyRepositoryProvider)
        .setApplicationStatus(applicationId, status: status);
    _refresh();
  }

  Future<void> saveNote(String applicationId, String note) async {
    await _container
        .read(vacancyRepositoryProvider)
        .setApplicationStatus(applicationId, note: note);
    _refresh();
  }

  Future<Uint8List> download(String answerId) =>
      _container.read(vacancyRepositoryProvider).downloadDocument(answerId);

  void _refresh() => _container
    ..invalidate(vacancyApplicantsProvider)
    ..invalidate(businessVacanciesProvider)
    ..invalidate(vacancySummaryProvider);
}
