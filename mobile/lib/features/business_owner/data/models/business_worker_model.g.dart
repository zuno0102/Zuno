// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_worker_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BusinessWorkerModel _$BusinessWorkerModelFromJson(Map<String, dynamic> json) =>
    BusinessWorkerModel(
      id: json['id'] as String,
      workerProfileId: json['workerProfileId'] as String,
      workerName: json['workerName'] as String,
      status: json['status'] as String,
      invitedAt: DateTime.parse(json['invitedAt'] as String),
      workerEmail: json['workerEmail'] as String?,
      workerPhone: json['workerPhone'] as String?,
      respondedAt: json['respondedAt'] == null
          ? null
          : DateTime.parse(json['respondedAt'] as String),
      availabilityStatus: json['availabilityStatus'] as String? ?? 'Active',
    );
