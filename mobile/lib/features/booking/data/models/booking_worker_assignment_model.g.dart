// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_worker_assignment_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BookingWorkerAssignmentModel _$BookingWorkerAssignmentModelFromJson(
  Map<String, dynamic> json,
) => BookingWorkerAssignmentModel(
  workerProfileId: json['workerProfileId'] as String,
  workerName: json['workerName'] as String,
  workerPhone: json['workerPhone'] as String?,
  role: json['role'] as String?,
  status: json['status'] as String,
  displayStatus: json['displayStatus'] as String? ?? '',
  agreedSalaryAmount: (json['agreedSalaryAmount'] as num?)?.toDouble(),
  agreedSalaryUnit: json['agreedSalaryUnit'] as String?,
  originalSalaryAmount: (json['originalSalaryAmount'] as num?)?.toDouble(),
  paymentStatus: json['paymentStatus'] as String? ?? '',
  hasPayoutDetails: json['hasPayoutDetails'] as bool? ?? false,
);
