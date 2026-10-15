import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/worker/domain/entities/worker_invitation.dart';
import 'package:zuno/features/worker/presentation/providers/worker_providers.dart';

part 'worker_invitations_notifier.g.dart';

@riverpod
class WorkerInvitationsNotifier extends _$WorkerInvitationsNotifier {
  @override
  Future<List<WorkerInvitation>> build() =>
      ref.watch(workerInvitationRepositoryProvider).getMyInvitations();

  Future<void> respond(String id, {required bool accept}) async {
    // No interim AsyncLoading here: the calling card is still mid-await inside this same
    // list, and flipping to AsyncLoading would unmount it before its own try/catch/finally
    // can run (see BusinessProfileNotifier.updateProfile for the full explanation).
    await ref
        .read(workerInvitationRepositoryProvider)
        .respondToInvitation(id, accept: accept);
    state = AsyncData(
      await ref.read(workerInvitationRepositoryProvider).getMyInvitations(),
    );
  }
}
