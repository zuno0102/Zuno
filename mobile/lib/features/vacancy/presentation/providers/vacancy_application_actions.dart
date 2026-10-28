import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_draft.dart';
import 'package:zuno/features/vacancy/presentation/providers/vacancy_providers.dart';
import 'package:zuno/features/vacancy/presentation/providers/worker_vacancies_notifier.dart';

/// A worker applying for, or withdrawing from, a full-time job.
///
/// Deliberately not methods on the job-list notifier. That list is auto-disposed, and the details
/// screen does not watch it — so calling it from there created a list that was thrown away mid-upload
/// and failed with "Cannot use the Ref after it has been disposed". These take the container, which
/// lives for the whole app, and refresh every list that shows the job once the server has answered.
class VacancyApplicationActions {
  const VacancyApplicationActions(this._container);

  final ProviderContainer _container;

  Future<Vacancy> apply(
    String vacancyId,
    List<VacancyAnswerDraft> answers,
  ) async {
    final applied = await _container
        .read(vacancyRepositoryProvider)
        .apply(vacancyId, answers);
    _refresh(vacancyId);
    return applied;
  }

  Future<void> withdraw(Vacancy vacancy) async {
    await _container
        .read(vacancyRepositoryProvider)
        .withdraw(vacancy.myApplicationId!);
    _refresh(vacancy.id);
  }

  void _refresh(String vacancyId) => _container
    ..invalidate(workerVacancyProvider(vacancyId))
    ..invalidate(workerVacanciesProvider)
    ..invalidate(myVacancyApplicationsProvider);
}
