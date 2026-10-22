import 'package:zuno/features/hiring_post/domain/entities/hiring_post_salary_adjustment.dart';

class HiringPostApplication {
  const HiringPostApplication({
    required this.id,
    required this.workerProfileId,
    required this.workerName,
    this.workerPhone,
    required this.status,
    required this.appliedAt,
    this.agreedSalaryAmount,
    this.agreedSalaryUnit,
    this.workerRespondedAt,
    this.delayRisk,
    this.paymentStatus = 'Unpaid',
    this.paidAt,
    this.disputeReason,
    this.salaryAdjustments = const [],
  });

  final String id;
  final String workerProfileId;
  final String workerName;
  final String? workerPhone;
  final String status;
  final DateTime appliedAt;

  /// Locked in at confirmation. Null while the application is still pending.
  final double? agreedSalaryAmount;
  final String? agreedSalaryUnit;
  final DateTime? workerRespondedAt;

  /// Set when this worker is running late on an earlier job. Null when on schedule.
  final String? delayRisk;

  /// Where this worker's wages have got to, independent of the application itself:
  /// work can be long finished before anyone is paid.
  final String paymentStatus;
  final DateTime? paidAt;

  /// Set when the worker reports the money never arrived.
  final String? disputeReason;

  final List<HiringPostSalaryAdjustment> salaryAdjustments;

  bool get isPaid => paymentStatus == 'Paid';
  bool get isPaymentFailed => paymentStatus == 'Failed';
  bool get isPaymentDisputed => paymentStatus == 'Disputed';

  /// How the wage state reads on screen, or null while there is nothing to say.
  String? get paymentLabel => switch (paymentStatus) {
    'Paid' => 'Paid',
    'Failed' => 'Payment failed',
    'Disputed' => 'Disputed',
    'Processing' => 'Sending',
    'AwaitingWorkerConfirmation' => 'Awaiting confirmation',
    _ => null,
  };

  bool get isApplied => status == 'Applied';

  /// The business approved this worker and the offer is sitting with them, unanswered.
  /// It does not fill a slot — only [isAccepted] does.
  bool get isOfferPending => status == 'Confirmed';

  bool get isAccepted => status == 'Accepted';
  bool get isRejected => status == 'Rejected';
  bool get isDeclined => status == 'Declined';

  /// Whether the business may phone this worker about the job.
  ///
  /// Only once they have taken it. Accepting is what puts somebody on the business's crew, and
  /// the phone number is for working out the job with the people doing it -- not for canvassing
  /// applicants, and not for chasing an offer nobody has answered yet ([isOfferPending], which
  /// deliberately does not qualify).
  ///
  /// Written as an inclusion list rather than Booking.canBeCalled's exclusion list -- a new
  /// status the server grows later must not become callable by default.
  ///
  /// Only half the rule. The job also has to be live, which the application cannot know:
  /// see HiringPost.canCallCrewMember.
  bool get canBeCalled => isAccepted && (workerPhone?.isNotEmpty ?? false);

  /// Owed money through Zuno and not yet paid.
  ///
  /// Outlives the job, and is what keeps a finished order's crew reachable: a failed payout or a
  /// worker disputing that the money arrived is the one thing after completion worth a call.
  /// False for someone with no agreed salary -- they are paid outside Zuno, so nothing is owed
  /// here to outlive anything.
  bool get hasUnsettledPay => hasAgreedSalary && !isPaid;

  /// How this application reads on screen, since "Confirmed" now means something narrower.
  String get statusLabel => switch (status) {
    'Applied' => 'Applied',
    'Confirmed' => 'Awaiting worker',
    'Accepted' => 'Accepted',
    'Rejected' => 'Rejected',
    'Declined' => 'Declined by worker',
    _ => status,
  };

  bool get hasAgreedSalary => agreedSalaryAmount != null;
  bool get hasBeenRaised => salaryAdjustments.isNotEmpty;

  /// Whether the business can still raise this worker's salary for extra work.
  ///
  /// On the crew (or holding an offer), with a salary agreed, and only before payment: once a
  /// payout has started the money is already moving at the old figure. The server applies the
  /// same rule.
  bool get canRaiseSalary =>
      (isAccepted || isOfferPending) &&
      hasAgreedSalary &&
      paymentStatus == 'Unpaid';

  /// What the salary was when this worker was first confirmed, before any raises.
  double? get originalAgreedSalary => salaryAdjustments.isEmpty
      ? agreedSalaryAmount
      : salaryAdjustments.first.previousAmount;
}
