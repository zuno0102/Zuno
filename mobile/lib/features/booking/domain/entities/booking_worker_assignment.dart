import 'package:zuno/shared/domain/payment_status.dart';
import 'package:zuno/core/utils/formatting.dart';

class BookingWorkerAssignment {
  const BookingWorkerAssignment({
    required this.workerProfileId,
    required this.workerName,
    this.workerPhone,
    this.role,
    required this.status,
    this.displayStatus = '',
    this.agreedSalaryAmount,
    this.agreedSalaryUnit,
    this.originalSalaryAmount,
    this.paymentStatus = '',
    this.hasPayoutDetails = false,
  });

  /// The wage before any raise, when it has been raised; otherwise null.
  final double? originalSalaryAmount;

  bool get hasBeenRaised => originalSalaryAmount != null;

  /// Whether the business can still add extra pay: a wage through Zuno, not turned down, not yet
  /// paid. The server applies the same rule.
  bool get canRaiseSalary =>
      isPayee && !isRejected && paymentStatus == 'Unpaid';

  final String workerProfileId;
  final String workerName;
  final String? workerPhone;
  final String? role;
  final String status;

  /// Where they stand on this order, read against how far the work has got: Awaiting, Active,
  /// InProgress, Completed or Declined. Worked out by the server, which knows both halves —
  /// someone who accepted is "active" until the work starts and "in progress" once it has.
  final String displayStatus;

  String get displayStatusLabel => switch (displayStatus) {
    'Awaiting' => 'Awaiting their answer',
    'Active' => 'Active',
    'InProgress' => 'In progress',
    'Completed' => 'Completed',
    'Declined' => 'Declined',
    _ => status,
  };

  /// Their wage for this job, or null when the business pays them outside Zuno.
  final double? agreedSalaryAmount;

  /// `PerEvent`, `PerDay` or `PerHour`. Null exactly when the amount is.
  final String? agreedSalaryUnit;

  /// `Unpaid`, `Processing`, `Paid`, `Failed`, `Disputed`. Only meaningful once a wage is set.
  final String paymentStatus;

  /// Whether there is somewhere to send their money.
  final bool hasPayoutDetails;

  bool get isAssigned => status == 'Assigned';
  bool get isAccepted => status == 'Accepted';
  bool get isRejected => status == 'Rejected';
  bool get isCompleted => status == 'Completed';

  /// Owed money through Zuno at all.
  bool get isPayee => agreedSalaryAmount != null;

  bool get isPaid => paymentStatus == 'Paid';

  /// How this worker's wage state reads on screen ("Payment failed", "Sending", "Paid"), or null
  /// when there is nothing to say — no wage through Zuno, or nothing tried yet.
  String? get paymentLabel =>
      isPayee ? paymentStatusLabel(paymentStatus) : null;

  /// Whether the business may phone this worker about the job.
  ///
  /// Only once they have taken it, matching the rule for a worker hired through a post: the same
  /// person can arrive by either route, and one of them being callable while the other is not
  /// would be indefensible. So [isAssigned] -- put on the job but not yet answered -- does not
  /// qualify, and somebody who turned the work down never does.
  ///
  /// [isCompleted] is in because a finished worker can still be owed money, and that is exactly
  /// when the business needs to reach them.
  ///
  /// Only half the rule -- the job also has to be live, which the assignment cannot know:
  /// see Booking.canCallCrewMember.
  bool get canBeCalled =>
      (isAccepted || isCompleted) && (workerPhone?.isNotEmpty ?? false);

  /// Owed money through Zuno and not yet paid.
  ///
  /// Outlives the job, and is what keeps a finished order's crew reachable. False for a regular
  /// paid outside Zuno, who is owed nothing here to outlive anything.
  bool get hasUnsettledPay => isPayee && !isPaid;

  /// "₹800 per event", or null when there is no wage to state.
  ///
  /// The unit is never dropped: ₹800 an hour and ₹800 for a whole event differ by a factor of
  /// eight on a long day, and a bare figure in a crew list invites exactly that mistake.
  String? get wageLabel => agreedSalaryAmount == null
      ? null
      : '${rupees(agreedSalaryAmount!)} '
            '${salaryUnitWords(agreedSalaryUnit ?? SalaryUnit.perEvent)}'
            '${hasBeenRaised ? ' (raised)' : ''}';

  /// Owed, and no way to send it. Worth saying before a pay run, not after.
  bool get cannotBePaidYet => isPayee && !isPaid && !hasPayoutDetails;
}
