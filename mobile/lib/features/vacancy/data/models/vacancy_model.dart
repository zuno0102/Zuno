import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy.dart';

part 'vacancy_model.g.dart';

@JsonSerializable(createToJson: false)
class VacancyModel {
  const VacancyModel({
    required this.id,
    required this.businessName,
    this.businessLogoUrl,
    required this.title,
    this.description,
    required this.jobTypeId,
    required this.jobTypeName,
    this.serviceSubCategoryId,
    this.serviceSubCategoryName,
    required this.openings,
    required this.salaryMin,
    this.salaryMax,
    required this.payPeriod,
    required this.workingDaysPerWeek,
    this.shiftStart,
    this.shiftEnd,
    this.contractMonths,
    this.location,
    this.districtName,
    this.latitude,
    this.longitude,
    this.distanceKm,
    required this.status,
    required this.isLive,
    required this.needsPayment,
    required this.canResume,
    this.feeAmount,
    this.publishedAt,
    this.expiresAt,
    required this.createdDate,
    this.applicantCount = 0,
    this.newCount = 0,
    this.waitingCount = 0,
    this.shortlistedCount = 0,
    this.hiredCount = 0,
    this.requirements = const [],
    this.myApplicationId,
    this.myApplicationStatus,
    this.myAppliedAt,
  });

  factory VacancyModel.fromJson(Map<String, dynamic> json) =>
      _$VacancyModelFromJson(json);

  final String id;
  final String businessName;
  final String? businessLogoUrl;
  final String title;
  final String? description;
  final String jobTypeId;
  final String jobTypeName;
  final String? serviceSubCategoryId;
  final String? serviceSubCategoryName;
  final int openings;
  final double salaryMin;
  final double? salaryMax;
  final String payPeriod;
  final int workingDaysPerWeek;
  final String? shiftStart;
  final String? shiftEnd;
  final int? contractMonths;
  final String? location;
  final String? districtName;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final String status;
  final bool isLive;
  final bool needsPayment;
  final bool canResume;
  final double? feeAmount;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final DateTime createdDate;
  final int applicantCount;
  final int newCount;
  final int waitingCount;
  final int shortlistedCount;
  final int hiredCount;
  final List<VacancyRequirementModel> requirements;
  final String? myApplicationId;
  final String? myApplicationStatus;
  final DateTime? myAppliedAt;

  Vacancy toEntity() => Vacancy(
    id: id,
    businessName: businessName,
    businessLogoUrl: businessLogoUrl,
    title: title,
    description: description,
    jobTypeId: jobTypeId,
    jobTypeName: jobTypeName,
    serviceSubCategoryId: serviceSubCategoryId,
    serviceSubCategoryName: serviceSubCategoryName,
    openings: openings,
    salaryMin: salaryMin,
    salaryMax: salaryMax,
    payPeriod: payPeriod,
    workingDaysPerWeek: workingDaysPerWeek,
    shiftStart: shiftStart,
    shiftEnd: shiftEnd,
    contractMonths: contractMonths,
    location: location,
    districtName: districtName,
    latitude: latitude,
    longitude: longitude,
    distanceKm: distanceKm,
    status: status,
    isLive: isLive,
    needsPayment: needsPayment,
    canResume: canResume,
    feeAmount: feeAmount,
    publishedAt: publishedAt,
    expiresAt: expiresAt,
    createdDate: createdDate,
    applicantCount: applicantCount,
    newCount: newCount,
    waitingCount: waitingCount,
    shortlistedCount: shortlistedCount,
    hiredCount: hiredCount,
    requirements: requirements.map((r) => r.toEntity()).toList(),
    myApplicationId: myApplicationId,
    myApplicationStatus: myApplicationStatus,
    myAppliedAt: myAppliedAt,
  );
}

@JsonSerializable(createToJson: false)
class VacancyRequirementModel {
  const VacancyRequirementModel({
    required this.id,
    required this.kind,
    required this.prompt,
    required this.isRequired,
  });

  factory VacancyRequirementModel.fromJson(Map<String, dynamic> json) =>
      _$VacancyRequirementModelFromJson(json);

  final String id;
  final String kind;
  final String prompt;
  final bool isRequired;

  VacancyRequirement toEntity() => VacancyRequirement(
    id: id,
    kind: kind,
    prompt: prompt,
    isRequired: isRequired,
  );
}
