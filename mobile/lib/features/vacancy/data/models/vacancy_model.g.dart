// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vacancy_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VacancyModel _$VacancyModelFromJson(Map<String, dynamic> json) => VacancyModel(
  id: json['id'] as String,
  businessName: json['businessName'] as String,
  businessLogoUrl: json['businessLogoUrl'] as String?,
  title: json['title'] as String,
  description: json['description'] as String?,
  jobTypeId: json['jobTypeId'] as String,
  jobTypeName: json['jobTypeName'] as String,
  serviceSubCategoryId: json['serviceSubCategoryId'] as String?,
  serviceSubCategoryName: json['serviceSubCategoryName'] as String?,
  openings: (json['openings'] as num).toInt(),
  salaryMin: (json['salaryMin'] as num).toDouble(),
  salaryMax: (json['salaryMax'] as num?)?.toDouble(),
  payPeriod: json['payPeriod'] as String,
  workingDaysPerWeek: (json['workingDaysPerWeek'] as num).toInt(),
  shiftStart: json['shiftStart'] as String?,
  shiftEnd: json['shiftEnd'] as String?,
  contractMonths: (json['contractMonths'] as num?)?.toInt(),
  location: json['location'] as String?,
  districtName: json['districtName'] as String?,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  distanceKm: (json['distanceKm'] as num?)?.toDouble(),
  status: json['status'] as String,
  isLive: json['isLive'] as bool,
  needsPayment: json['needsPayment'] as bool,
  canResume: json['canResume'] as bool,
  feeAmount: (json['feeAmount'] as num?)?.toDouble(),
  publishedAt: json['publishedAt'] == null
      ? null
      : DateTime.parse(json['publishedAt'] as String),
  expiresAt: json['expiresAt'] == null
      ? null
      : DateTime.parse(json['expiresAt'] as String),
  createdDate: DateTime.parse(json['createdDate'] as String),
  applicantCount: (json['applicantCount'] as num?)?.toInt() ?? 0,
  newCount: (json['newCount'] as num?)?.toInt() ?? 0,
  waitingCount: (json['waitingCount'] as num?)?.toInt() ?? 0,
  shortlistedCount: (json['shortlistedCount'] as num?)?.toInt() ?? 0,
  hiredCount: (json['hiredCount'] as num?)?.toInt() ?? 0,
  requirements:
      (json['requirements'] as List<dynamic>?)
          ?.map(
            (e) => VacancyRequirementModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  myApplicationId: json['myApplicationId'] as String?,
  myApplicationStatus: json['myApplicationStatus'] as String?,
  myAppliedAt: json['myAppliedAt'] == null
      ? null
      : DateTime.parse(json['myAppliedAt'] as String),
);

VacancyRequirementModel _$VacancyRequirementModelFromJson(
  Map<String, dynamic> json,
) => VacancyRequirementModel(
  id: json['id'] as String,
  kind: json['kind'] as String,
  prompt: json['prompt'] as String,
  isRequired: json['isRequired'] as bool,
);
