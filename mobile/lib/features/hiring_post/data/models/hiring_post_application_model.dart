import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/hiring_post/data/models/hiring_post_salary_adjustment_model.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post_application.dart';

part 'hiring_post_application_model.g.dart';

@JsonSerializable(createToJson: false)
class HiringPostApplicationModel {
  const HiringPostApplicationModel({
    required this.id,
    required this.workerProfileId,
    required this.workerName,
    this.workerPhone,
    required this.status,
    required this.appliedAt,
    this.agreedSalaryAmount,
    this.agreedSalaryUnit,
    this.workerRespondedAt,
    this.delayRisk,
    this.paymentStatus = 'Unpaid',
    this.paidAt,
    this.disputeReason,
    this.salaryAdjustments = const [],
  });

  factory HiringPostApplicationModel.fromJson(Map<String, dynamic> json) =>
      _$HiringPostApplicationModelFromJson(json);

  final String id;
  final String workerProfileId;
  final String workerName;
  final String? workerPhone;
  final String status;
  final DateTime appliedAt;
  final double? agreedSalaryAmount;
  final String? agreedSalaryUnit;
  final DateTime? workerRespondedAt;
  final String? delayRisk;
  final String paymentStatus;
  final DateTime? paidAt;
  final String? disputeReason;
  final List<HiringPostSalaryAdjustmentModel> salaryAdjustments;

  HiringPostApplication toEntity() => HiringPostApplication(
    id: id,
    workerProfileId: workerProfileId,
    workerName: workerName,
    workerPhone: workerPhone,
    status: status,
    appliedAt: appliedAt,
    agreedSalaryAmount: agreedSalaryAmount,
    agreedSalaryUnit: agreedSalaryUnit,
    workerRespondedAt: workerRespondedAt,
    delayRisk: delayRisk,
    paymentStatus: paymentStatus,
    paidAt: paidAt,
    disputeReason: disputeReason,
    salaryAdjustments: salaryAdjustments.map((a) => a.toEntity()).toList(),
  );
}
