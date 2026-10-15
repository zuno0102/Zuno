/// A worker's own profile: what they earned, what they are owed, and whether they can be paid.
class WorkerProfile {
  const WorkerProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.availabilityStatus,
    required this.verificationStatus,
    required this.payoutVerificationStatus,
    this.photoUrl,
    this.level = 1,
    this.levelName = 'New',
    this.jobsToNextLevel,
    this.nextLevelRequirement,
    this.phoneNumber,
    this.experienceYears,
    this.hourlyRate,
    this.upiVpa,
    this.hasPayoutDestination = false,
    this.canReceivePayouts = false,
    this.totalEarned = 0,
    this.owedToYou = 0,
    this.jobsCompleted = 0,
    this.jobsPaid = 0,
    this.averageSalary,
    this.businessesWorkedFor = 0,
    this.offersDeclined = 0,
    this.openDisputes = 0,
  });

  final String id;
  final String fullName;
  final String? phoneNumber;
  final String email;
  final int? experienceYears;
  final double? hourlyRate;
  final String availabilityStatus;
  final String verificationStatus;

  /// The worker's own picture, or null until they add one.
  final String? photoUrl;

  /// 1-5, earned from finished work.
  final int level;

  /// Describes experience, never quality — there are no worker ratings yet.
  final String levelName;

  /// Jobs remaining until the next level, or null at the top.
  final int? jobsToNextLevel;

  /// The nearest thing standing between this worker and the next level, in their own words —
  /// "3 more jobs", "work for 2 more businesses". Null at the top.
  ///
  /// Sent by the server because the level no longer rests on jobs alone, so a job count on its own
  /// could say "0 jobs to level 3" to somebody held back by something else entirely.
  final String? nextLevelRequirement;

  final String? upiVpa;
  final bool hasPayoutDestination;
  final bool canReceivePayouts;
  final String payoutVerificationStatus;

  final double totalEarned;
  final double owedToYou;
  final int jobsCompleted;
  final int jobsPaid;
  final double? averageSalary;
  final int businessesWorkedFor;
  final int offersDeclined;
  final int openDisputes;

  bool get isAvailable => availabilityStatus == 'Available';

  /// The one thing that stops wages arriving at all, so it is the profile's first card.
  bool get needsPayoutSetup => !canReceivePayouts;

  /// Shows enough of the handle to recognise, without printing it in full.
  String? get maskedUpi {
    final vpa = upiVpa;
    if (vpa == null || vpa.isEmpty) return null;
    final at = vpa.indexOf('@');
    if (at <= 2) return vpa;
    return '${vpa.substring(0, 2)}${'•' * (at - 2)}${vpa.substring(at)}';
  }

  String get experienceLabel => switch (experienceYears) {
    null || 0 => 'Not set',
    1 => '1 year',
    final years => '$years years',
  };
}
