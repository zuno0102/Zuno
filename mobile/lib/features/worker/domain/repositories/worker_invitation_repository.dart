import 'package:zuno/features/worker/domain/entities/worker_invitation.dart';

abstract interface class WorkerInvitationRepository {
  Future<List<WorkerInvitation>> getMyInvitations();

  Future<WorkerInvitation> respondToInvitation(
    String id, {
    required bool accept,
  });
}
