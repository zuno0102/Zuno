import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_payment.dart';
import 'package:zuno/features/vacancy/presentation/providers/paged_list.dart';
import 'package:zuno/features/vacancy/presentation/providers/vacancy_providers.dart';
import 'package:zuno/features/worker/presentation/providers/worker_job_filter_provider.dart';

part 'worker_vacancies_notifier.g.dart';

/// Live full-time vacancies near the worker. Shares the event-work feed's saved location and
/// distance, so a worker sets where they are once for both.
@riverpod
class WorkerVacanciesNotifier extends _$WorkerVacanciesNotifier {
  @override
  Future<PagedList<Vacancy>> build({String? jobTypeId}) async {
    final filter = ref.watch(workerJobFilterProvider);
    final page = await _fetch(filter, before: null);
    return PagedList(items: page.items, nextBefore: page.nextBefore);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    final page = await _fetch(
      ref.read(workerJobFilterProvider),
      before: current.nextBefore,
    );
    state = AsyncData(
      PagedList(
        items: [...current.items, ...page.items],
        nextBefore: page.nextBefore,
      ),
    );
  }

  Future<VacancyPage<Vacancy>> _fetch(
    WorkerJobFilter filter, {
    required DateTime? before,
  }) => ref
      .read(vacancyRepositoryProvider)
      .getOpenVacancies(
        // Coarse, as the event feed sends it: three decimals is plenty at these radii.
        latitude: filter.coarseLatitude,
        longitude: filter.coarseLongitude,
        radiusKm: filter.isFiltering ? filter.radiusKm!.toDouble() : null,
        jobTypeId: jobTypeId,
        before: before,
      );
}

/// The vacancies this worker has applied to, newest application first.
@riverpod
Future<List<Vacancy>> myVacancyApplications(Ref ref) async =>
    (await ref.watch(vacancyRepositoryProvider).getMyApplications()).items;
