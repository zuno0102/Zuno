import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/business_owner/domain/entities/business_worker.dart';

part 'business_worker_model.g.dart';

@JsonSerializable(createToJson: false)
class BusinessWorkerModel {
  const BusinessWorkerModel({
    required this.id,
    required this.workerProfileId,
    required this.workerName,
    required this.status,
    required this.invitedAt,
    this.workerEmail,
    this.workerPhone,
    this.respondedAt,
    this.availabilityStatus = 'Active',
  });

  factory BusinessWorkerModel.fromJson(Map<String, dynamic> json) =>
      _$BusinessWorkerModelFromJson(json);

  final String id;
  final String workerProfileId;
  final String workerName;
  final String? workerEmail;
  final String? workerPhone;
  final String status;
  final DateTime invitedAt;
  final DateTime? respondedAt;
  final String availabilityStatus;

  BusinessWorker toEntity() => BusinessWorker(
    id: id,
    workerProfileId: workerProfileId,
    workerName: workerName,
    workerEmail: workerEmail,
    workerPhone: workerPhone,
    status: status,
    invitedAt: invitedAt,
    respondedAt: respondedAt,
    availabilityStatus: availabilityStatus,
  );
}
