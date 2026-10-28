import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_application.dart';

part 'vacancy_application_model.g.dart';

@JsonSerializable(createToJson: false)
class VacancyApplicationModel {
  const VacancyApplicationModel({
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
    this.answers = const [],
  });

  factory VacancyApplicationModel.fromJson(Map<String, dynamic> json) =>
      _$VacancyApplicationModelFromJson(json);

  final String id;
  final String vacancyId;
  final String vacancyTitle;
  final String workerName;
  final String? workerPhone;
  final String? workerPhotoUrl;
  final int? experienceYears;
  final String status;
  final DateTime appliedAt;
  final String? businessNote;
  final List<VacancyAnswerModel> answers;

  VacancyApplication toEntity() => VacancyApplication(
    id: id,
    vacancyId: vacancyId,
    vacancyTitle: vacancyTitle,
    workerName: workerName,
    workerPhone: workerPhone,
    workerPhotoUrl: workerPhotoUrl,
    experienceYears: experienceYears,
    status: status,
    appliedAt: appliedAt,
    businessNote: businessNote,
    answers: answers.map((a) => a.toEntity()).toList(),
  );
}

@JsonSerializable(createToJson: false)
class VacancyAnswerModel {
  const VacancyAnswerModel({
    required this.id,
    required this.prompt,
    this.answerText,
    required this.hasFile,
    this.fileName,
    this.contentType,
  });

  factory VacancyAnswerModel.fromJson(Map<String, dynamic> json) =>
      _$VacancyAnswerModelFromJson(json);

  final String id;
  final String prompt;
  final String? answerText;
  final bool hasFile;
  final String? fileName;
  final String? contentType;

  VacancyAnswer toEntity() => VacancyAnswer(
    id: id,
    prompt: prompt,
    answerText: answerText,
    hasFile: hasFile,
    fileName: fileName,
    contentType: contentType,
  );
}
