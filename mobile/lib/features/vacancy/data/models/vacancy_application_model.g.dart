// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vacancy_application_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VacancyApplicationModel _$VacancyApplicationModelFromJson(
  Map<String, dynamic> json,
) => VacancyApplicationModel(
  id: json['id'] as String,
  vacancyId: json['vacancyId'] as String,
  vacancyTitle: json['vacancyTitle'] as String? ?? '',
  workerName: json['workerName'] as String,
  workerPhone: json['workerPhone'] as String?,
  workerPhotoUrl: json['workerPhotoUrl'] as String?,
  experienceYears: (json['experienceYears'] as num?)?.toInt(),
  status: json['status'] as String,
  appliedAt: DateTime.parse(json['appliedAt'] as String),
  businessNote: json['businessNote'] as String?,
  answers:
      (json['answers'] as List<dynamic>?)
          ?.map((e) => VacancyAnswerModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

VacancyAnswerModel _$VacancyAnswerModelFromJson(Map<String, dynamic> json) =>
    VacancyAnswerModel(
      id: json['id'] as String,
      prompt: json['prompt'] as String,
      answerText: json['answerText'] as String?,
      hasFile: json['hasFile'] as bool,
      fileName: json['fileName'] as String?,
      contentType: json['contentType'] as String?,
    );
