// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_options_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppOptionsModel _$AppOptionsModelFromJson(
  Map<String, dynamic> json,
) => AppOptionsModel(
  hiringPostMinDurationMinutes: (json['hiringPostMinDurationMinutes'] as num?)
      ?.toInt(),
  hiringPostMaxDurationMinutes: (json['hiringPostMaxDurationMinutes'] as num?)
      ?.toInt(),
  hiringPostDefaultDurationMinutes:
      (json['hiringPostDefaultDurationMinutes'] as num?)?.toInt(),
  hiringPostMaxWorkers: (json['hiringPostMaxWorkers'] as num?)?.toInt(),
  orderMaxCrewSize: (json['orderMaxCrewSize'] as num?)?.toInt(),
  serviceMaxQuestions: (json['serviceMaxQuestions'] as num?)?.toInt(),
  serviceImageSlots: (json['serviceImageSlots'] as num?)?.toInt(),
  serviceVideoMaxSeconds: (json['serviceVideoMaxSeconds'] as num?)?.toInt(),
  serviceVideoMaxBytes: (json['serviceVideoMaxBytes'] as num?)?.toInt(),
  imageMaxBytes: (json['imageMaxBytes'] as num?)?.toInt(),
  imageUploadQuality: (json['imageUploadQuality'] as num?)?.toInt(),
  imageUploadMaxWidth: (json['imageUploadMaxWidth'] as num?)?.toInt(),
  maxDaysAhead: (json['maxDaysAhead'] as num?)?.toInt(),
  customerBookingMaxDaysAhead: (json['customerBookingMaxDaysAhead'] as num?)
      ?.toInt(),
  vacancyMaxOpenings: (json['vacancyMaxOpenings'] as num?)?.toInt(),
  vacancyMaxContractMonths: (json['vacancyMaxContractMonths'] as num?)?.toInt(),
  vacancyMaxFields: (json['vacancyMaxFields'] as num?)?.toInt(),
  vacancyTitleMaxLength: (json['vacancyTitleMaxLength'] as num?)?.toInt(),
  vacancyDescriptionMaxLength: (json['vacancyDescriptionMaxLength'] as num?)
      ?.toInt(),
  vacancyLocationMaxLength: (json['vacancyLocationMaxLength'] as num?)?.toInt(),
  vacancyFieldNameMaxLength: (json['vacancyFieldNameMaxLength'] as num?)
      ?.toInt(),
);
