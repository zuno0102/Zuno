import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post_salary_adjustment.dart';

part 'hiring_post_salary_adjustment_model.g.dart';

@JsonSerializable(createToJson: false)
class HiringPostSalaryAdjustmentModel {
  const HiringPostSalaryAdjustmentModel({
    required this.id,
    required this.previousAmount,
    required this.newAmount,
    this.reason,
    required this.adjustedAt,
  });

  factory HiringPostSalaryAdjustmentModel.fromJson(Map<String, dynamic> json) =>
      _$HiringPostSalaryAdjustmentModelFromJson(json);

  final String id;
  final double previousAmount;
  final double newAmount;
  final String? reason;
  final DateTime adjustedAt;

  HiringPostSalaryAdjustment toEntity() => HiringPostSalaryAdjustment(
    id: id,
    previousAmount: previousAmount,
    newAmount: newAmount,
    reason: reason,
    adjustedAt: adjustedAt,
  );
}
