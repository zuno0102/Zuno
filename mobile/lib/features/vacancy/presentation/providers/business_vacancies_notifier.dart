import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_draft.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_payment.dart';
import 'package:zuno/features/vacancy/presentation/providers/paged_list.dart';
import 'package:zuno/features/vacancy/presentation/providers/vacancy_providers.dart';

part 'business_vacancies_notifier.g.dart';

/// The business's own full-time vacancies, in every state.
@riverpod
class BusinessVacanciesNotifier extends _$BusinessVacanciesNotifier {
  @override
  Future<PagedList<Vacancy>> build() async {
    final page = await ref.watch(vacancyRepositoryProvider).getMyVacancies();
    return PagedList(items: page.items, nextBefore: page.nextBefore);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    final page = await ref
        .read(vacancyRepositoryProvider)
        .getMyVacancies(before: current.nextBefore);
    state = AsyncData(
      PagedList(
        items: [...current.items, ...page.items],
        nextBefore: page.nextBefore,
      ),
    );
  }

  Future<Vacancy> create(VacancyDraft draft) async =>
      _put(await ref.read(vacancyRepositoryProvider).create(draft));

  Future<Vacancy> edit(String id, VacancyDraft draft) async =>
      _put(await ref.read(vacancyRepositoryProvider).update(id, draft));

  Future<Vacancy> setHiring(String id, {required bool hiring}) async => _put(
    await ref.read(vacancyRepositoryProvider).setHiring(id, hiring: hiring),
  );

  Future<VacancyPayment> openPayment(String id) =>
      ref.read(vacancyRepositoryProvider).createPayment(id);

  Future<Vacancy> confirmPayment(
    String id, {
    String? paymentId,
    String? signature,
  }) async => _put(
    await ref
        .read(vacancyRepositoryProvider)
        .confirmPayment(id, paymentId: paymentId, signature: signature),
  );

  /// Takes the vacancy off the list once the server has deleted it.
  Future<void> delete(String id) async {
    await ref.read(vacancyRepositoryProvider).delete(id);
    ref.invalidate(vacancySummaryProvider);
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(items: current.items.where((v) => v.id != id).toList()),
    );
  }

  /// Puts a vacancy the server just returned into the list without reloading every page.
  Vacancy put(Vacancy vacancy) => _put(vacancy);

  Vacancy _put(Vacancy vacancy) {
    // Every change here — posted, paid, stopped, restarted — can move the home screen's numbers.
    ref.invalidate(vacancySummaryProvider);
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.upsert(vacancy, (v) => v.id));
    }
    return vacancy;
  }
}
