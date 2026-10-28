import 'dart:typed_data';

import 'package:zuno/features/vacancy/data/datasources/vacancy_remote_datasource.dart';
import 'package:zuno/features/vacancy/data/models/vacancy_model.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_application.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_draft.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_options.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_payment.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_summary.dart';
import 'package:zuno/features/vacancy/domain/repositories/vacancy_repository.dart';

class VacancyRepositoryImpl implements VacancyRepository {
  VacancyRepositoryImpl({required VacancyRemoteDataSource remoteDataSource})
    : _remote = remoteDataSource;

  final VacancyRemoteDataSource _remote;

  static VacancyPage<Vacancy> _vacancies(
    (List<VacancyModel>, DateTime?) page,
  ) => VacancyPage(
    items: page.$1.map((m) => m.toEntity()).toList(),
    nextBefore: page.$2,
  );

  @override
  Future<VacancyOptions> getOptions({required bool asWorker}) async =>
      (await _remote.getOptions(asWorker: asWorker)).toEntity();

  @override
  Future<VacancySummary> getSummary() async =>
      (await _remote.getSummary()).toEntity();

  @override
  Future<VacancyPage<Vacancy>> getMyVacancies({DateTime? before}) async =>
      _vacancies(await _remote.getMyVacancies(before: before));

  @override
  Future<Vacancy> create(VacancyDraft draft) async =>
      (await _remote.create(draft)).toEntity();

  @override
  Future<Vacancy> update(String id, VacancyDraft draft) async =>
      (await _remote.update(id, draft)).toEntity();

  @override
  Future<void> delete(String id) => _remote.delete(id);

  @override
  Future<Vacancy> setHiring(String id, {required bool hiring}) async =>
      (await _remote.setHiring(id, hiring: hiring)).toEntity();

  @override
  Future<VacancyPayment> createPayment(String id, {String? feePlanId}) async =>
      (await _remote.createPayment(id, feePlanId: feePlanId)).toEntity();

  @override
  Future<Vacancy> confirmPayment(
    String id, {
    String? paymentId,
    String? signature,
  }) async => (await _remote.confirmPayment(
    id,
    paymentId: paymentId,
    signature: signature,
  )).toEntity();

  @override
  Future<VacancyPage<VacancyApplication>> getApplications(
    String? vacancyId, {
    String? status,
    DateTime? before,
  }) async {
    final page = await _remote.getApplications(
      vacancyId,
      status: status,
      before: before,
    );
    return VacancyPage(
      items: page.$1.map((m) => m.toEntity()).toList(),
      nextBefore: page.$2,
    );
  }

  @override
  Future<VacancyApplication> setApplicationStatus(
    String applicationId, {
    String? status,
    String? note,
  }) async => (await _remote.setApplicationStatus(
    applicationId,
    status: status,
    note: note,
  )).toEntity();

  @override
  Future<VacancyApplication> markViewed(String applicationId) async =>
      (await _remote.markViewed(applicationId)).toEntity();

  @override
  Future<Uint8List> downloadDocument(String answerId) =>
      _remote.downloadDocument(answerId);

  @override
  Future<VacancyPage<Vacancy>> getOpenVacancies({
    double? latitude,
    double? longitude,
    double? radiusKm,
    String? jobTypeId,
    DateTime? before,
  }) async => _vacancies(
    await _remote.getOpenVacancies(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      jobTypeId: jobTypeId,
      before: before,
    ),
  );

  @override
  Future<Vacancy> getForWorker(String id) async =>
      (await _remote.getForWorker(id)).toEntity();

  @override
  Future<VacancyPage<Vacancy>> getMyApplications({DateTime? before}) async =>
      _vacancies(await _remote.getMyApplications(before: before));

  @override
  Future<Vacancy> apply(String id, List<VacancyAnswerDraft> answers) async =>
      (await _remote.apply(id, answers)).toEntity();

  @override
  Future<void> withdraw(String applicationId) =>
      _remote.withdraw(applicationId);
}
