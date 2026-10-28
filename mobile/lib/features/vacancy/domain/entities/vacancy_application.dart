/// One applicant, as the business reviewing them sees them.
class VacancyApplication {
  const VacancyApplication({
    required this.id,
    required this.vacancyId,
    this.vacancyTitle = '',
    required this.workerName,
    this.workerPhone,
    this.workerPhotoUrl,
    this.experienceYears,
    required this.status,
    required this.appliedAt,
    this.businessNote,
    required this.answers,
  });

  final String id;
  final String vacancyId;

  /// Which job this is for. Shown where applicants from every job are listed together.
  final String vacancyTitle;
  final String workerName;
  final String? workerPhone;
  final String? workerPhotoUrl;
  final int? experienceYears;
  final String status;
  final DateTime appliedAt;

  /// Private to the business; the worker never sees it.
  final String? businessNote;
  final List<VacancyAnswer> answers;

  VacancyApplication copyWith({String? status, String? businessNote}) =>
      VacancyApplication(
        id: id,
        vacancyId: vacancyId,
        vacancyTitle: vacancyTitle,
        workerName: workerName,
        workerPhone: workerPhone,
        workerPhotoUrl: workerPhotoUrl,
        experienceYears: experienceYears,
        status: status ?? this.status,
        appliedAt: appliedAt,
        businessNote: businessNote ?? this.businessNote,
        answers: answers,
      );
}

/// What an applicant sent for one requirement. A document carries no URL: it is downloaded
/// through an endpoint that checks who is asking.
class VacancyAnswer {
  const VacancyAnswer({
    required this.id,
    required this.prompt,
    this.answerText,
    required this.hasFile,
    this.fileName,
    this.contentType,
  });

  final String id;
  final String prompt;
  final String? answerText;
  final bool hasFile;
  final String? fileName;
  final String? contentType;

  bool get isImage => contentType?.startsWith('image/') ?? false;
}
