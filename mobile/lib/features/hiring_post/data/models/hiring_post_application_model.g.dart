// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hiring_post_application_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HiringPostApplicationModel _$HiringPostApplicationModelFromJson(
  Map<String, dynamic> json,
) => HiringPostApplicationModel(
  id: json['id'] as String,
  workerProfileId: json['workerProfileId'] as String,
  workerName: json['workerName'] as String,
  workerPhone: json['workerPhone'] as String?,
  status: json['status'] as String,
  appliedAt: DateTime.parse(json['appliedAt'] as String),
  agreedSalaryAmount: (json['agreedSalaryAmount'] as num?)?.toDouble(),
  agreedSalaryUnit: json['agreedSalaryUnit'] as String?,
  workerRespondedAt: json['workerRespondedAt'] == null
      ? null
      : DateTime.parse(json['workerRespondedAt'] as String),
  delayRisk: json['delayRisk'] as String?,
  paymentStatus: json['paymentStatus'] as String? ?? 'Unpaid',
  paidAt: json['paidAt'] == null
      ? null
      : DateTime.parse(json['paidAt'] as String),
  disputeReason: json['disputeReason'] as String?,
  salaryAdjustments:
      (json['salaryAdjustments'] as List<dynamic>?)
          ?.map(
            (e) => HiringPostSalaryAdjustmentModel.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList() ??
      const [],
);
