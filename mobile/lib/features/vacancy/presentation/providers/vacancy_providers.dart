import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/auth/presentation/providers/auth_providers.dart';
import 'package:zuno/features/vacancy/data/datasources/vacancy_remote_datasource.dart';
import 'package:zuno/features/vacancy/data/repositories/vacancy_repository_impl.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_options.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_summary.dart';
import 'package:zuno/features/vacancy/domain/repositories/vacancy_repository.dart';

part 'vacancy_providers.g.dart';

@Riverpod(keepAlive: true)
VacancyRemoteDataSource vacancyRemoteDataSource(Ref ref) =>
    VacancyRemoteDataSource(ref.watch(dioClientProvider));

@Riverpod(keepAlive: true)
VacancyRepository vacancyRepository(Ref ref) => VacancyRepositoryImpl(
  remoteDataSource: ref.watch(vacancyRemoteDataSourceProvider),
);

/// Job types, fee plans and upload rules. Reference data, so kept for the session.
@Riverpod(keepAlive: true)
Future<VacancyOptions> vacancyOptions(Ref ref, {required bool asWorker}) =>
    ref.watch(vacancyRepositoryProvider).getOptions(asWorker: asWorker);

/// The business home screen's full-time hiring numbers. Refreshed whenever a vacancy or applicant
/// changes, so the tiles never lag the lists they lead to.
@riverpod
Future<VacancySummary> vacancySummary(Ref ref) =>
    ref.watch(vacancyRepositoryProvider).getSummary();

/// One vacancy as a worker sees it, for the detail screen and after a notification tap.
@riverpod
Future<Vacancy> workerVacancy(Ref ref, String id) =>
    ref.watch(vacancyRepositoryProvider).getForWorker(id);
