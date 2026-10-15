import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/presentation/providers/booking_providers.dart';

part 'worker_jobs_notifier.g.dart';

@riverpod
class WorkerJobsNotifier extends _$WorkerJobsNotifier {
  @override
  Future<List<Booking>> build() =>
      ref.watch(bookingRepositoryProvider).getMyJobsAsWorker();

  Future<void> respond(String id, {required bool accept}) async {
    await ref
        .read(bookingRepositoryProvider)
        .respondToAssignment(id, accept: accept);
    await _refresh();
  }

  /// The job's lead moving the whole order, not just their own row.
  Future<void> startJobAsLead(String id) async {
    await ref.read(bookingRepositoryProvider).startJobAsLead(id);
    await _refresh();
  }

  Future<void> finishJobAsLead(String id) async {
    await ref.read(bookingRepositoryProvider).finishJobAsLead(id);
    await _refresh();
  }

  Future<void> complete(String id) async {
    await ref.read(bookingRepositoryProvider).completeBooking(id);
    await _refresh();
  }

  // No interim AsyncLoading here: the calling card is still mid-await inside this same
  // list, and flipping to AsyncLoading would unmount it before its own try/catch/finally
  // can run (see BusinessProfileNotifier.updateProfile for the full explanation).
  Future<void> _refresh() async {
    state = AsyncData(
      await ref.read(bookingRepositoryProvider).getMyJobsAsWorker(),
    );
  }
}
