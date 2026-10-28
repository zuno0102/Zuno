import 'dart:typed_data';

import 'package:zuno/features/vacancy/domain/entities/vacancy.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_application.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_draft.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_options.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_payment.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_summary.dart';

abstract interface class VacancyRepository {
  Future<VacancyOptions> getOptions({required bool asWorker});

  /// Live posts and applicants by list, for the business home screen.
  Future<VacancySummary> getSummary();

  // ---- Business ----

  Future<VacancyPage<Vacancy>> getMyVacancies({DateTime? before});

  Future<Vacancy> create(VacancyDraft draft);

  Future<Vacancy> update(String id, VacancyDraft draft);

  Future<void> delete(String id);

  Future<Vacancy> setHiring(String id, {required bool hiring});

  Future<VacancyPayment> createPayment(String id, {String? feePlanId});

  Future<Vacancy> confirmPayment(
    String id, {
    String? paymentId,
    String? signature,
  });

  /// One vacancy's applicants, or with a null [vacancyId] every vacancy's.
  Future<VacancyPage<VacancyApplication>> getApplications(
    String? vacancyId, {
    String? status,
    DateTime? before,
  });

  Future<VacancyApplication> setApplicationStatus(
    String applicationId, {
    String? status,
    String? note,
  });

  /// The business opened this applicant: New moves to Waiting.
  Future<VacancyApplication> markViewed(String applicationId);

  Future<Uint8List> downloadDocument(String answerId);

  // ---- Worker ----

  Future<VacancyPage<Vacancy>> getOpenVacancies({
    double? latitude,
    double? longitude,
    double? radiusKm,
    String? jobTypeId,
    DateTime? before,
  });

  Future<Vacancy> getForWorker(String id);

  Future<VacancyPage<Vacancy>> getMyApplications({DateTime? before});

  Future<Vacancy> apply(String id, List<VacancyAnswerDraft> answers);

  Future<void> withdraw(String applicationId);
}
