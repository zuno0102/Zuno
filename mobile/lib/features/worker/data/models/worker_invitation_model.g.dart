// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worker_invitation_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WorkerInvitationModel _$WorkerInvitationModelFromJson(
  Map<String, dynamic> json,
) => WorkerInvitationModel(
  id: json['id'] as String,
  businessOwnerProfileId: json['businessOwnerProfileId'] as String,
  businessName: json['businessName'] as String,
  status: json['status'] as String,
  invitedAt: DateTime.parse(json['invitedAt'] as String),
  businessLogoUrl: json['businessLogoUrl'] as String?,
  respondedAt: json['respondedAt'] == null
      ? null
      : DateTime.parse(json['respondedAt'] as String),
);
