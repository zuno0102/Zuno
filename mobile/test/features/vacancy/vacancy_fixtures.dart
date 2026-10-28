import 'dart:typed_data';

import 'package:zuno/features/vacancy/data/models/vacancy_model.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_application.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_draft.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_options.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_payment.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_summary.dart';
import 'package:zuno/features/vacancy/domain/repositories/vacancy_repository.dart';

/// A vacancy as the server sends it, with every field the app reads.
Map<String, dynamic> vacancyJson({
  String id = 'v-1',
  String status = 'Open',
  bool isLive = true,
  bool needsPayment = false,
  bool canResume = false,
  String? myApplicationId,
  String? myApplicationStatus,
  int applicantCount = 0,
  double? salaryMax = 20000,
}) => {
  'id': id,
  'businessOwnerProfileId': 'b-1',
  'businessName': 'Nila Stores',
  'businessLogoUrl': null,
  'title': 'Office receptionist',
  'description': 'Front desk and phone calls.',
  'jobTypeId': 't-1',
  'jobTypeName': 'Full-time',
  'serviceSubCategoryId': null,
  'serviceSubCategoryName': null,
  'openings': 2,
  'salaryMin': 15000.0,
  'salaryMax': salaryMax,
  'payPeriod': 'PerMonth',
  'workingDaysPerWeek': 6,
  'shiftStart': '09:30:00',
  'shiftEnd': '18:00:00',
  'contractMonths': null,
  'location': 'Near bus stand',
  'districtName': 'Kanyakumari',
  'latitude': 8.1833,
  'longitude': 77.4119,
  'distanceKm': 1.2,
  'status': status,
  'isLive': isLive,
  'needsPayment': needsPayment,
  'canResume': canResume,
  'feeAmount': 49.0,
  'publishedAt': '2026-10-27T10:00:00+00:00',
  'expiresAt': '2026-11-26T10:00:00+00:00',
  'hiringStoppedAt': null,
  'createdDate': '2026-10-27T09:00:00+00:00',
  'applicantCount': applicantCount,
  'shortlistedCount': 0,
  'hiredCount': 0,
  'requirements': [
    {
      'id': 'r-1',
      'kind': 'File',
      'prompt': 'Aadhaar',
      'isRequired': true,
      'sortOrder': 0,
    },
    {
      'id': 'r-2',
      'kind': 'Text',
      'prompt': 'Do you know Tally?',
      'isRequired': true,
      'sortOrder': 1,
    },
    {
      'id': 'r-3',
      'kind': 'YesNo',
      'prompt': 'Do you have a two-wheeler?',
      'isRequired': true,
      'sortOrder': 2,
    },
    {
      'id': 'r-4',
      'kind': 'Number',
      'prompt': 'Years of experience',
      'isRequired': false,
      'sortOrder': 3,
    },
  ],
  'myApplicationId': myApplicationId,
  'myApplicationStatus': myApplicationStatus,
  'myAppliedAt': myApplicationId == null ? null : '2026-10-27T11:00:00+00:00',
};

Vacancy vacancy({
  String id = 'v-1',
  String status = 'Open',
  bool isLive = true,
  bool needsPayment = false,
  bool canResume = false,
  String? myApplicationId,
  String? myApplicationStatus,
  int applicantCount = 0,
}) => VacancyModel.fromJson(
  vacancyJson(
    id: id,
    status: status,
    isLive: isLive,
    needsPayment: needsPayment,
    canResume: canResume,
    myApplicationId: myApplicationId,
    myApplicationStatus: myApplicationStatus,
    applicantCount: applicantCount,
  ),
).toEntity();

/// A repository whose answers each test sets. Calls nobody set up fail loudly.
class FakeVacancyRepository implements VacancyRepository {
  Future<VacancyPage<Vacancy>> Function()? myVacancies;
  Future<Vacancy> Function(String id)? forWorker;
  final List<String> withdrawn = [];
  final List<List<VacancyAnswerDraft>> applied = [];

  @override
  Future<VacancyPage<Vacancy>> getMyVacancies({DateTime? before}) =>
      myVacancies!();

  @override
  Future<Vacancy> getForWorker(String id) => forWorker!(id);

  VacancySummary summary = const VacancySummary(
    activePosts: 0,
    newCount: 0,
    waitingCount: 0,
    shortlistedCount: 0,
    hiredCount: 0,
  );

  @override
  Future<VacancySummary> getSummary() async => summary;

  @override
  Future<VacancyOptions> getOptions({required bool asWorker}) async =>
      const VacancyOptions(
        jobTypes: [],
        feePlans: [],
        allowedFileExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        maxFileSizeBytes: 5242880,
      );

  @override
  Future<VacancyPage<Vacancy>> getOpenVacancies({
    double? latitude,
    double? longitude,
    double? radiusKm,
    String? jobTypeId,
    DateTime? before,
  }) async => const VacancyPage(items: []);

  List<Vacancy> myApplications = const [];

  @override
  Future<VacancyPage<Vacancy>> getMyApplications({DateTime? before}) async =>
      VacancyPage(items: myApplications);

  @override
  Future<void> withdraw(String applicationId) async =>
      withdrawn.add(applicationId);

  @override
  Future<Vacancy> apply(String id, List<VacancyAnswerDraft> answers) async {
    applied.add(answers);
    return forWorker!(id);
  }

  @override
  Future<Vacancy> create(VacancyDraft draft) => throw UnimplementedError();

  @override
  Future<Vacancy> update(String id, VacancyDraft draft) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String id) => throw UnimplementedError();

  final List<bool> hiringChanges = [];

  @override
  Future<Vacancy> setHiring(String id, {required bool hiring}) async {
    hiringChanges.add(hiring);
    return vacancy(
      id: id,
      status: hiring ? VacancyStatus.open : VacancyStatus.stopped,
      isLive: hiring,
      canResume: !hiring,
    );
  }

  @override
  Future<VacancyPayment> createPayment(String id, {String? feePlanId}) =>
      throw UnimplementedError();

  @override
  Future<Vacancy> confirmPayment(
    String id, {
    String? paymentId,
    String? signature,
  }) => throw UnimplementedError();

  /// Applicants by status, as the business's lists ask for them.
  Map<String, List<VacancyApplication>> applicants = const {};
  final List<String> opened = [];
  final List<(String, String?)> decisions = [];

  @override
  Future<VacancyPage<VacancyApplication>> getApplications(
    String? vacancyId, {
    String? status,
    DateTime? before,
  }) async {
    askedForVacancy.add(vacancyId);
    return VacancyPage(items: applicants[status] ?? const []);
  }

  @override
  Future<VacancyApplication> setApplicationStatus(
    String applicationId, {
    String? status,
    String? note,
  }) async {
    decisions.add((applicationId, status));
    return _applicant(
      applicationId,
    ).copyWith(status: status, businessNote: note);
  }

  @override
  Future<VacancyApplication> markViewed(String applicationId) async {
    opened.add(applicationId);
    return _applicant(applicationId).copyWith(status: 'Viewed');
  }

  /// Set to check which list was asked for: one vacancy's, or every vacancy's (null).
  final List<String?> askedForVacancy = [];

  VacancyApplication _applicant(String id) =>
      applicants.values.expand((list) => list).firstWhere((a) => a.id == id);

  @override
  Future<Uint8List> downloadDocument(String answerId) =>
      throw UnimplementedError();
}

VacancyApplication applicant({
  String id = 'a-1',
  String status = 'Applied',
  String name = 'Ravi K',
}) => VacancyApplication(
  id: id,
  vacancyId: 'v-1',
  workerName: name,
  workerPhone: '9876543210',
  status: status,
  appliedAt: DateTime(2026, 10, 27),
  answers: const [
    VacancyAnswer(
      id: 'x-1',
      prompt: 'Do you know Tally?',
      answerText: 'Yes',
      hasFile: false,
    ),
  ],
);
