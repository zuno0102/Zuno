// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worker_profile_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WorkerProfileModel _$WorkerProfileModelFromJson(Map<String, dynamic> json) =>
    WorkerProfileModel(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      availabilityStatus: json['availabilityStatus'] as String,
      verificationStatus: json['verificationStatus'] as String,
      payoutVerificationStatus: json['payoutVerificationStatus'] as String,
      photoUrl: json['photoUrl'] as String?,
      level: (json['level'] as num?)?.toInt() ?? 1,
      levelName: json['levelName'] as String? ?? 'New',
      jobsToNextLevel: (json['jobsToNextLevel'] as num?)?.toInt(),
      nextLevelRequirement: json['nextLevelRequirement'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      experienceYears: (json['experienceYears'] as num?)?.toInt(),
      hourlyRate: (json['hourlyRate'] as num?)?.toDouble(),
      upiVpa: json['upiVpa'] as String?,
      hasPayoutDestination: json['hasPayoutDestination'] as bool? ?? false,
      canReceivePayouts: json['canReceivePayouts'] as bool? ?? false,
      totalEarned: (json['totalEarned'] as num?)?.toDouble() ?? 0,
      owedToYou: (json['owedToYou'] as num?)?.toDouble() ?? 0,
      jobsCompleted: (json['jobsCompleted'] as num?)?.toInt() ?? 0,
      jobsPaid: (json['jobsPaid'] as num?)?.toInt() ?? 0,
      averageSalary: (json['averageSalary'] as num?)?.toDouble(),
      businessesWorkedFor: (json['businessesWorkedFor'] as num?)?.toInt() ?? 0,
      offersDeclined: (json['offersDeclined'] as num?)?.toInt() ?? 0,
      openDisputes: (json['openDisputes'] as num?)?.toInt() ?? 0,
    );
