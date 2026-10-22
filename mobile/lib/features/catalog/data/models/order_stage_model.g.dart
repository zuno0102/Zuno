// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_stage_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderStageModel _$OrderStageModelFromJson(Map<String, dynamic> json) =>
    OrderStageModel(
      code: json['code'] as String,
      label: json['label'] as String,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      tone: json['tone'] as String? ?? '',
      showOnBookings: json['showOnBookings'] as bool? ?? false,
      showOnWork: json['showOnWork'] as bool? ?? false,
    );
