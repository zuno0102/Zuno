/// Where a full-time vacancy stands, as the server names it.
class VacancyStatus {
  const VacancyStatus._();

  static const awaitingPayment = 'AwaitingPayment';
  static const open = 'Open';
  static const stopped = 'Stopped';
}

/// The kind of answer a business's custom field takes.
class VacancyRequirementKind {
  const VacancyRequirementKind._();

  static const text = 'Text';
  static const number = 'Number';
  static const yesNo = 'YesNo';
  static const file = 'File';

  static const all = [text, number, yesNo, file];
}

/// What a salary figure is counted per.
class VacancyPayPeriod {
  const VacancyPayPeriod._();

  static const perDay = 'PerDay';
  static const perWeek = 'PerWeek';
  static const perMonth = 'PerMonth';

  static const all = [perMonth, perWeek, perDay];
}

/// Where the business has got to with an applicant.
class VacancyApplicationStatus {
  const VacancyApplicationStatus._();

  /// Sent, not opened yet: the business's New list.
  static const applied = 'Applied';

  /// Opened, no decision yet: the business's Waiting list.
  static const viewed = 'Viewed';
  static const shortlisted = 'Shortlisted';
  static const hired = 'Hired';

  /// Turned down: leaves the business's lists, and what the worker sent is deleted.
  static const rejected = 'Rejected';

  /// The business's lists, in order. Rejected is not one: it is gone from their side.
  static const businessLists = [applied, viewed, shortlisted, hired];
}

/// A business's paid listing for long-running work — a shop helper, a receptionist, a contract.
///
/// Distinct from a hiring post, which is crew for one event and is paid through the app. Here the
/// app only connects the two sides; hiring and salary happen between them.
class Vacancy {
  const Vacancy({
    required this.id,
    required this.businessName,
    this.businessLogoUrl,
    required this.title,
    this.description,
    required this.jobTypeId,
    required this.jobTypeName,
    this.serviceSubCategoryId,
    this.serviceSubCategoryName,
    required this.openings,
    required this.salaryMin,
    this.salaryMax,
    required this.payPeriod,
    required this.workingDaysPerWeek,
    this.shiftStart,
    this.shiftEnd,
    this.contractMonths,
    this.location,
    this.districtName,
    this.latitude,
    this.longitude,
    this.distanceKm,
    required this.status,
    required this.isLive,
    required this.needsPayment,
    required this.canResume,
    this.feeAmount,
    this.publishedAt,
    this.expiresAt,
    required this.createdDate,
    required this.applicantCount,
    required this.newCount,
    required this.waitingCount,
    required this.shortlistedCount,
    required this.hiredCount,
    required this.requirements,
    this.myApplicationId,
    this.myApplicationStatus,
    this.myAppliedAt,
  });

  final String id;
  final String businessName;
  final String? businessLogoUrl;
  final String title;
  final String? description;
  final String jobTypeId;
  final String jobTypeName;
  final String? serviceSubCategoryId;
  final String? serviceSubCategoryName;
  final int openings;
  final double salaryMin;
  final double? salaryMax;
  final String payPeriod;
  final int workingDaysPerWeek;

  /// "HH:mm:ss", as the server sends a time of day.
  final String? shiftStart;
  final String? shiftEnd;
  final int? contractMonths;
  final String? location;
  final String? districtName;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final String status;

  /// Workers can see it right now.
  final bool isLive;

  /// Never paid, or the paid period ran out.
  final bool needsPayment;

  /// Stopped, and can start hiring again without paying.
  final bool canResume;
  final double? feeAmount;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final DateTime createdDate;

  /// Everyone still in the running; rejected applicants are not counted.
  final int applicantCount;

  /// Not opened yet.
  final int newCount;

  /// Opened, no decision yet.
  final int waitingCount;
  final int shortlistedCount;
  final int hiredCount;
  final List<VacancyRequirement> requirements;

  final String? myApplicationId;
  final String? myApplicationStatus;
  final DateTime? myAppliedAt;

  bool get isStopped => status == VacancyStatus.stopped;

  bool get hasApplied => myApplicationId != null;

  /// The server's rule: a hired worker cannot withdraw.
  bool get canWithdraw =>
      hasApplied && myApplicationStatus != VacancyApplicationStatus.hired;

  /// The server's rule: only an open vacancy can be stopped.
  bool get canStop => status == VacancyStatus.open && isLive;
}

/// One custom field on the application form — "Aadhaar" as a file, "Do you have a bike?" as Yes/No.
class VacancyRequirement {
  const VacancyRequirement({
    required this.id,
    required this.kind,
    required this.prompt,
    required this.isRequired,
  });

  final String id;
  final String kind;
  final String prompt;
  final bool isRequired;

  bool get isFile => kind == VacancyRequirementKind.file;
}
