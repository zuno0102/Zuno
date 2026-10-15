import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/auth/presentation/providers/auth_providers.dart';
import 'package:zuno/features/worker/data/datasources/worker_remote_datasource.dart';
import 'package:zuno/features/worker/data/repositories/worker_invitation_repository_impl.dart';
import 'package:zuno/features/worker/domain/entities/hiring_business.dart';
import 'package:zuno/features/worker/domain/entities/worker_profile.dart';
import 'package:zuno/features/worker/domain/repositories/worker_invitation_repository.dart';
import 'package:zuno/features/worker/presentation/providers/worker_job_filter_provider.dart';

part 'worker_providers.g.dart';

@Riverpod(keepAlive: true)
WorkerRemoteDataSource workerRemoteDataSource(Ref ref) =>
    WorkerRemoteDataSource(ref.watch(dioClientProvider));

@Riverpod(keepAlive: true)
WorkerInvitationRepository workerInvitationRepository(Ref ref) =>
    WorkerInvitationRepositoryImpl(
      remoteDataSource: ref.watch(workerRemoteDataSourceProvider),
    );

@riverpod
Future<WorkerProfile> workerProfile(Ref ref) async =>
    (await ref.watch(workerRemoteDataSourceProvider).getMyProfile()).toEntity();

@riverpod
Future<HiringBusiness> hiringBusiness(Ref ref, String businessId) async {
  // The position the Find work feed is already using, so this screen measures from the same place.
  // Watched, so setting a location on the feed fills in the distances here too.
  final filter = ref.watch(workerJobFilterProvider);

  return (await ref
          .watch(workerRemoteDataSourceProvider)
          .getHiringBusiness(
            businessId,
            latitude: filter.coarseLatitude,
            longitude: filter.coarseLongitude,
          ))
      .toEntity();
}
