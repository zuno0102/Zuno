/// What a business's record looks like to each side of the marketplace.
///
/// Two blocks rather than one score: a customer is deciding whether the job will be done well,
/// a worker whether they will be paid and how much. A single number answers neither honestly.
class BusinessTrust {
  const BusinessTrust({
    this.customers = const CustomerFacingTrust(),
    this.workers = const WorkerFacingTrust(),
  });

  final CustomerFacingTrust customers;
  final WorkerFacingTrust workers;
}

/// The delivery record — what a customer is buying.
class CustomerFacingTrust {
  const CustomerFacingTrust({
    this.eventsCompleted = 0,
    this.ratingAverage,
    this.reviewCount = 0,
    this.repeatCustomers = 0,
  });

  final int eventsCompleted;

  /// Null until anyone has reviewed, which is different from a rating of zero.
  final double? ratingAverage;
  final int reviewCount;
  final int repeatCustomers;

  bool get hasReviews => ratingAverage != null && reviewCount > 0;
}

/// The pay record — what a worker is deciding on.
class WorkerFacingTrust {
  const WorkerFacingTrust({
    this.averageSalary,
    this.lowestSalary,
    this.highestSalary,
    this.salaryUnit,
    this.totalHires = 0,
    this.paidPostedRateCount = 0,
    this.raisedPayCount = 0,
    this.crewsPaid = 0,
    this.crewsAwaitingPayment = 0,
    this.typicalHoursToPay,
    this.distinctWorkers = 0,
    this.repeatHires = 0,
    this.openDisputes = 0,
    this.overdueWages = 0,
  });

  final double? averageSalary;
  final double? lowestSalary;
  final double? highestSalary;
  final String? salaryUnit;
  final int totalHires;
  final int paidPostedRateCount;
  final int raisedPayCount;
  final int crewsPaid;
  final int crewsAwaitingPayment;
  final double? typicalHoursToPay;
  final int distinctWorkers;
  final int repeatHires;
  final int openDisputes;
  final double overdueWages;

  bool get hasHires => totalHires > 0;

  /// Crew whose work is finished — the only ones who can meaningfully be owed.
  int get crewsDue => crewsPaid + crewsAwaitingPayment;

  /// "per event" / "per day" / "per hour", for the line under the headline figure.
  String get unitLabel => switch (salaryUnit) {
    'PerDay' => 'per day',
    'PerHour' => 'per hour',
    _ => 'per event',
  };

  String get salaryRangeLabel {
    if (lowestSalary == null || highestSalary == null) return '';
    final lo = lowestSalary!.toStringAsFixed(0);
    final hi = highestSalary!.toStringAsFixed(0);
    return lo == hi ? '₹$lo' : '₹$lo — ₹$hi';
  }

  /// "within 19 hrs" / "within 2 days" — how long after the work money usually lands.
  String? get payTimeLabel {
    final hours = typicalHoursToPay;
    if (hours == null) return null;
    if (hours < 1) return 'same hour';
    if (hours < 48) return '${hours.round()} hrs';
    return '${(hours / 24).round()} days';
  }

  /// Only worth a badge when there is enough history to mean something.
  bool get keepsItsWord => totalHires >= 3 && paidPostedRateCount == totalHires;

  /// Nobody goes back to someone who did not pay them.
  bool get hasRepeatCrew => repeatHires > 0;
}
