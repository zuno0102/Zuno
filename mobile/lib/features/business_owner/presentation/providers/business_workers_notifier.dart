import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/business_owner/domain/entities/business_worker.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_providers.dart';

part 'business_workers_notifier.g.dart';

@riverpod
class BusinessWorkersNotifier extends _$BusinessWorkersNotifier {
  @override
  Future<List<BusinessWorker>> build() =>
      ref.watch(businessRepositoryProvider).getWorkers();

  Future<void> invite(String workerIdentifier) async {
    await ref.read(businessRepositoryProvider).inviteWorker(workerIdentifier);
    await _refresh();
  }

  Future<void> remove(String id) async {
    await ref.read(businessRepositoryProvider).removeWorker(id);
    await _refresh();
  }

  Future<void> _refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(businessRepositoryProvider).getWorkers(),
    );
  }
}
