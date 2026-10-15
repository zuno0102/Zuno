import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/worker/domain/entities/worker_profile.dart';

part 'worker_profile_model.g.dart';

@JsonSerializable(createToJson: false)
class WorkerProfileModel {
  const WorkerProfileModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.availabilityStatus,
    required this.verificationStatus,
    required this.payoutVerificationStatus,
    this.photoUrl,
    this.level = 1,
    this.levelName = 'New',
    this.jobsToNextLevel,
    this.nextLevelRequirement,
    this.phoneNumber,
    this.experienceYears,
    this.hourlyRate,
    this.upiVpa,
    this.hasPayoutDestination = false,
    this.canReceivePayouts = false,
    this.totalEarned = 0,
    this.owedToYou = 0,
    this.jobsCompleted = 0,
    this.jobsPaid = 0,
    this.averageSalary,
    this.businessesWorkedFor = 0,
    this.offersDeclined = 0,
    this.openDisputes = 0,
  });

  factory WorkerProfileModel.fromJson(Map<String, dynamic> json) =>
      _$WorkerProfileModelFromJson(json);

  final String id;
  final String fullName;
  final String? phoneNumber;
  final String email;
  final int? experienceYears;
  final double? hourlyRate;
  final String availabilityStatus;
  final String verificationStatus;
  final String? photoUrl;
  final int level;
  final String levelName;
  final int? jobsToNextLevel;
  final String? nextLevelRequirement;
  final String? upiVpa;
  final bool hasPayoutDestination;
  final bool canReceivePayouts;
  final String payoutVerificationStatus;
  final double totalEarned;
  final double owedToYou;
  final int jobsCompleted;
  final int jobsPaid;
  final double? averageSalary;
  final int businessesWorkedFor;
  final int offersDeclined;
  final int openDisputes;

  WorkerProfile toEntity() => WorkerProfile(
    id: id,
    fullName: fullName,
    phoneNumber: phoneNumber,
    email: email,
    experienceYears: experienceYears,
    hourlyRate: hourlyRate,
    availabilityStatus: availabilityStatus,
    verificationStatus: verificationStatus,
    photoUrl: photoUrl,
    level: level,
    levelName: levelName,
    jobsToNextLevel: jobsToNextLevel,
    nextLevelRequirement: nextLevelRequirement,
    upiVpa: upiVpa,
    hasPayoutDestination: hasPayoutDestination,
    canReceivePayouts: canReceivePayouts,
    payoutVerificationStatus: payoutVerificationStatus,
    totalEarned: totalEarned,
    owedToYou: owedToYou,
    jobsCompleted: jobsCompleted,
    jobsPaid: jobsPaid,
    averageSalary: averageSalary,
    businessesWorkedFor: businessesWorkedFor,
    offersDeclined: offersDeclined,
    openDisputes: openDisputes,
  );
}
