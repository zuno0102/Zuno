class WorkerInvitation {
  const WorkerInvitation({
    required this.id,
    required this.businessOwnerProfileId,
    required this.businessName,
    required this.status,
    required this.invitedAt,
    this.businessLogoUrl,
    this.respondedAt,
  });

  final String id;
  final String businessOwnerProfileId;
  final String businessName;
  final String? businessLogoUrl;
  final String status;
  final DateTime invitedAt;
  final DateTime? respondedAt;
}
