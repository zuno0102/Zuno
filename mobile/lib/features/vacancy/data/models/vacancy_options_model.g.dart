// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vacancy_options_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VacancyOptionsModel _$VacancyOptionsModelFromJson(
  Map<String, dynamic> json,
) => VacancyOptionsModel(
  jobTypes:
      (json['jobTypes'] as List<dynamic>?)
          ?.map((e) => VacancyJobTypeModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  feePlans:
      (json['feePlans'] as List<dynamic>?)
          ?.map((e) => VacancyFeePlanModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  allowedFileExtensions:
      (json['allowedFileExtensions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  maxFileSizeBytes: (json['maxFileSizeBytes'] as num?)?.toInt() ?? 0,
);

VacancyJobTypeModel _$VacancyJobTypeModelFromJson(Map<String, dynamic> json) =>
    VacancyJobTypeModel(
      id: json['id'] as String,
      name: json['name'] as String,
      hasFixedLength: json['hasFixedLength'] as bool,
    );

VacancyFeePlanModel _$VacancyFeePlanModelFromJson(Map<String, dynamic> json) =>
    VacancyFeePlanModel(
      id: json['id'] as String,
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      listingDays: (json['listingDays'] as num).toInt(),
    );

VacancyPaymentModel _$VacancyPaymentModelFromJson(Map<String, dynamic> json) =>
    VacancyPaymentModel(
      vacancyId: json['vacancyId'] as String,
      planName: json['planName'] as String,
      amount: (json['amount'] as num).toDouble(),
      listingDays: (json['listingDays'] as num).toInt(),
      providerOrderId: json['providerOrderId'] as String?,
      razorpayKeyId: json['razorpayKeyId'] as String?,
      nothingToCollect: json['nothingToCollect'] as bool,
      vacancy: json['vacancy'] == null
          ? null
          : VacancyModel.fromJson(json['vacancy'] as Map<String, dynamic>),
    );
