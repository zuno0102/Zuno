class BusinessWorker {
  const BusinessWorker({
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

  final String id;
  final String workerProfileId;
  final String workerName;
  final String? workerEmail;
  final String? workerPhone;
  final String status;
  final DateTime invitedAt;
  final DateTime? respondedAt;
  final String availabilityStatus;

  bool get isActive => status == 'Active';
  bool get isInvited => status == 'Invited';

  bool get isAtWork => availabilityStatus == 'AtWork';
  bool get isBooked => availabilityStatus == 'Booked';
}
