import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/presentation/providers/hiring_post_providers.dart';

part 'worker_post_jobs_notifier.g.dart';

/// Work this worker took through a hiring post.
///
/// A worker reaches paid work by two routes and only one of them reached My jobs. That screen is fed
/// by the bookings endpoint — customer orders they were assigned to — so a job taken through a
/// hiring post appeared on the dashboard and in the Find work feed and nowhere a worker could act on
/// it. "1 coming up" on the home page opened to an empty My jobs.
///
/// Read from its own endpoint rather than the Find work feed, which returns nothing until a location
/// is set and is cut to a page: work somebody has already committed to must not depend on a search.
@riverpod
Future<List<HiringPost>> workerPostJobs(Ref ref) =>
    ref.watch(hiringPostRepositoryProvider).getMyPostJobs();
