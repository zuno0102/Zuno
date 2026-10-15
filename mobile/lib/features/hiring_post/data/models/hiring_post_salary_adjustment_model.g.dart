// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hiring_post_salary_adjustment_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HiringPostSalaryAdjustmentModel _$HiringPostSalaryAdjustmentModelFromJson(
  Map<String, dynamic> json,
) => HiringPostSalaryAdjustmentModel(
  id: json['id'] as String,
  previousAmount: (json['previousAmount'] as num).toDouble(),
  newAmount: (json['newAmount'] as num).toDouble(),
  reason: json['reason'] as String?,
  adjustedAt: DateTime.parse(json['adjustedAt'] as String),
);
