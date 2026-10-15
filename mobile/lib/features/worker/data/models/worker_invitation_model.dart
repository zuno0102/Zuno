import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/worker/domain/entities/worker_invitation.dart';

part 'worker_invitation_model.g.dart';

@JsonSerializable(createToJson: false)
class WorkerInvitationModel {
  const WorkerInvitationModel({
    required this.id,
    required this.businessOwnerProfileId,
    required this.businessName,
    required this.status,
    required this.invitedAt,
    this.businessLogoUrl,
    this.respondedAt,
  });

  factory WorkerInvitationModel.fromJson(Map<String, dynamic> json) =>
      _$WorkerInvitationModelFromJson(json);

  final String id;
  final String businessOwnerProfileId;
  final String businessName;
  final String? businessLogoUrl;
  final String status;
  final DateTime invitedAt;
  final DateTime? respondedAt;

  WorkerInvitation toEntity() => WorkerInvitation(
    id: id,
    businessOwnerProfileId: businessOwnerProfileId,
    businessName: businessName,
    businessLogoUrl: businessLogoUrl,
    status: status,
    invitedAt: invitedAt,
    respondedAt: respondedAt,
  );
}
