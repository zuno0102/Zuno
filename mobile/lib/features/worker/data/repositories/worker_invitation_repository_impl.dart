import 'package:zuno/features/worker/data/datasources/worker_remote_datasource.dart';
import 'package:zuno/features/worker/domain/entities/worker_invitation.dart';
import 'package:zuno/features/worker/domain/repositories/worker_invitation_repository.dart';

class WorkerInvitationRepositoryImpl implements WorkerInvitationRepository {
  WorkerInvitationRepositoryImpl({
    required WorkerRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final WorkerRemoteDataSource _remoteDataSource;

  @override
  Future<List<WorkerInvitation>> getMyInvitations() async =>
      (await _remoteDataSource.getMyInvitations())
          .map((m) => m.toEntity())
          .toList();

  @override
  Future<WorkerInvitation> respondToInvitation(
    String id, {
    required bool accept,
  }) async => (await _remoteDataSource.respondToInvitation(
    id,
    accept: accept,
  )).toEntity();
}
