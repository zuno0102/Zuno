import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/network/dio_error_mapper.dart';
import 'package:zuno/features/vacancy/data/models/vacancy_application_model.dart';
import 'package:zuno/features/vacancy/data/models/vacancy_model.dart';
import 'package:zuno/features/vacancy/data/models/vacancy_options_model.dart';
import 'package:zuno/features/vacancy/data/models/vacancy_summary_model.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_draft.dart';

class VacancyRemoteDataSource {
  VacancyRemoteDataSource(this._dio);

  final Dio _dio;

  // ---- Business ----

  Future<VacancyOptionsModel> getOptions({required bool asWorker}) async =>
      VacancyOptionsModel.fromJson(
        await _get(
          asWorker
              ? ApiConstants.workerVacancyOptionsPath
              : ApiConstants.businessVacancyOptionsPath,
        ),
      );

  Future<VacancySummaryModel> getSummary() async =>
      VacancySummaryModel.fromJson(
        await _get(ApiConstants.businessVacancySummaryPath),
      );

  Future<(List<VacancyModel>, DateTime?)> getMyVacancies({DateTime? before}) =>
      _page(
        ApiConstants.businessVacanciesPath,
        VacancyModel.fromJson,
        query: {'before': ?before?.toUtc().toIso8601String()},
      );

  Future<VacancyModel> create(VacancyDraft draft) async =>
      VacancyModel.fromJson(
        await _send('POST', ApiConstants.businessVacanciesPath, _body(draft)),
      );

  Future<VacancyModel> update(String id, VacancyDraft draft) async =>
      VacancyModel.fromJson(
        await _send('PUT', ApiConstants.businessVacancyPath(id), _body(draft)),
      );

  Future<void> delete(String id) => _send(
    'DELETE',
    ApiConstants.businessVacancyPath(id),
    null,
    expectBody: false,
  );

  Future<VacancyModel> setHiring(String id, {required bool hiring}) async =>
      VacancyModel.fromJson(
        await _send(
          'POST',
          hiring
              ? ApiConstants.startVacancyHiringPath(id)
              : ApiConstants.stopVacancyHiringPath(id),
          const {},
        ),
      );

  Future<VacancyPaymentModel> createPayment(
    String id, {
    String? feePlanId,
  }) async => VacancyPaymentModel.fromJson(
    await _send('POST', ApiConstants.vacancyPaymentPath(id), {
      'feePlanId': ?feePlanId,
    }),
  );

  Future<VacancyModel> confirmPayment(
    String id, {
    String? paymentId,
    String? signature,
  }) async => VacancyModel.fromJson(
    await _send('POST', ApiConstants.confirmVacancyPaymentPath(id), {
      'providerPaymentId': ?paymentId,
      'signature': ?signature,
    }),
  );

  /// One vacancy's applicants, or with a null [vacancyId] every vacancy's.
  Future<(List<VacancyApplicationModel>, DateTime?)> getApplications(
    String? vacancyId, {
    String? status,
    DateTime? before,
  }) => _page(
    vacancyId == null
        ? ApiConstants.allVacancyApplicationsPath
        : ApiConstants.vacancyApplicationsPath(vacancyId),
    VacancyApplicationModel.fromJson,
    query: {'status': ?status, 'before': ?before?.toUtc().toIso8601String()},
  );

  Future<VacancyApplicationModel> setApplicationStatus(
    String applicationId, {
    String? status,
    String? note,
  }) async => VacancyApplicationModel.fromJson(
    await _send(
      'POST',
      ApiConstants.vacancyApplicationStatusPath(applicationId),
      {'status': ?status, 'note': ?note},
    ),
  );

  /// The business opened this applicant: New moves to Waiting.
  Future<VacancyApplicationModel> markViewed(String applicationId) async =>
      VacancyApplicationModel.fromJson(
        await _send(
          'POST',
          ApiConstants.vacancyApplicationViewedPath(applicationId),
          const {},
        ),
      );

  Future<Uint8List> downloadDocument(String answerId) async {
    try {
      final response = await _dio.get<List<int>>(
        ApiConstants.vacancyDocumentPath(answerId),
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  // ---- Worker ----

  Future<(List<VacancyModel>, DateTime?)> getOpenVacancies({
    double? latitude,
    double? longitude,
    double? radiusKm,
    String? jobTypeId,
    DateTime? before,
  }) => _page(
    ApiConstants.workerVacanciesPath,
    VacancyModel.fromJson,
    query: {
      'latitude': ?latitude,
      'longitude': ?longitude,
      'radiusKm': ?radiusKm,
      'jobTypeId': ?jobTypeId,
      'before': ?before?.toUtc().toIso8601String(),
    },
  );

  Future<VacancyModel> getForWorker(String id) async =>
      VacancyModel.fromJson(await _get(ApiConstants.workerVacancyPath(id)));

  Future<(List<VacancyModel>, DateTime?)> getMyApplications({
    DateTime? before,
  }) => _page(
    ApiConstants.myVacancyApplicationsPath,
    VacancyModel.fromJson,
    query: {'before': ?before?.toUtc().toIso8601String()},
  );

  /// One multipart form: `text_{requirementId}` for answers, `file_{requirementId}` for files.
  /// Bytes rather than paths, so it works on the web build too.
  Future<VacancyModel> apply(
    String id,
    List<VacancyAnswerDraft> answers,
  ) async {
    final form = FormData();

    for (final answer in answers) {
      if (answer.text case final text? when text.trim().isNotEmpty) {
        form.fields.add(MapEntry('text_${answer.requirementId}', text.trim()));
      }
      if (answer.bytes case final bytes?) {
        form.files.add(
          MapEntry(
            'file_${answer.requirementId}',
            MultipartFile.fromBytes(
              bytes,
              filename: answer.fileName ?? 'document',
            ),
          ),
        );
      }
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.applyToVacancyPath(id),
        data: form,
      );
      return VacancyModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<void> withdraw(String applicationId) => _send(
    'DELETE',
    ApiConstants.withdrawVacancyApplicationPath(applicationId),
    null,
    expectBody: false,
  );

  // ---- Plumbing ----

  Map<String, dynamic> _body(VacancyDraft d) => {
    'title': d.title,
    'description': ?d.description,
    'jobTypeId': d.jobTypeId,
    'openings': d.openings,
    'salaryMin': d.salaryMin,
    'salaryMax': ?d.salaryMax,
    'payPeriod': d.payPeriod,
    'workingDaysPerWeek': d.workingDaysPerWeek,
    'shiftStart': ?d.shiftStart,
    'shiftEnd': ?d.shiftEnd,
    'contractMonths': ?d.contractMonths,
    'location': ?d.location,
    'latitude': ?d.latitude,
    'longitude': ?d.longitude,
    'locationPrecision': ?d.locationPrecision,
    'requirements': [
      for (final r in d.requirements)
        {'kind': r.kind, 'prompt': r.prompt, 'isRequired': r.isRequired},
    ],
  };

  Future<Map<String, dynamic>> _get(String path) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(path);
      return response.data!;
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<(List<T>, DateTime?)> _page<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: query,
      );
      final data = response.data!;
      final items = (data['items'] as List<dynamic>)
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();
      final next = data['nextBefore'] as String?;
      return (items, next == null ? null : DateTime.parse(next));
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path,
    Map<String, dynamic>? body, {
    bool expectBody = true,
  }) async {
    try {
      final response = await _dio.request<Map<String, dynamic>>(
        path,
        data: body,
        options: Options(method: method),
      );
      return expectBody ? response.data! : const {};
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
