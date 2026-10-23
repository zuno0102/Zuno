import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/worker/domain/entities/worker_profile.dart';

/// A worker's home screen: what they have done, what they are owed, what is coming.
///
/// Carries the profile whole rather than beside it. Two sources each working out "total earned" is
/// how the shell header and the profile tab came to disagree about what a worker was owed, and this
/// screen shows both figures within a thumb's reach of each other.
class WorkerDashboard {
  const WorkerDashboard({
    this.profile,
    this.inProgressCount = 0,
    this.upcomingCount = 0,
    this.openHiringPostCount = 0,
    this.inProgress = const [],
    this.upcoming = const [],
    this.completed = const [],
    this.pendingPayments = const [],
    this.pendingPaymentTotal = 0,
    this.trend = const [],
  });

  final WorkerProfile? profile;

  final int inProgressCount;
  final int upcomingCount;

  /// Open jobs anywhere this worker has not applied to. Independent of any distance filter, so the
  /// header showing it stays correct on every tab.
  final int openHiringPostCount;

  /// Capped by the server, so these can be shorter than the counts above.
  final List<WorkerJobSummary> inProgress;
  final List<WorkerJobSummary> upcoming;

  /// Work already finished, newest first.
  final List<WorkerJobSummary> completed;

  /// Finished work that has not been paid for, one row per job.
  final List<WorkerPendingPayment> pendingPayments;

  final double pendingPaymentTotal;

  /// Oldest month first, matching the chart's left-to-right axis.
  final List<WorkerMonthlyEarning> trend;

  /// Whether there is any history worth drawing, as opposed to six empty months.
  bool get hasTrend => trend.any((m) => m.jobsCompleted > 0 || m.earned > 0);

  /// The tallest bar, so the chart can scale to it. 0 when there is nothing.
  int get busiestMonthCount =>
      trend.isEmpty ? 0 : trend.map((m) => m.jobsCompleted).reduce((a, b) => a > b ? a : b);

  double get mostEarnedInAMonth =>
      trend.isEmpty ? 0 : trend.map((m) => m.earned).reduce((a, b) => a > b ? a : b);

  /// Nothing has been earned and nothing done, so a first-job message beats a row of ₹0.
  bool get hasWorkRecord =>
      (profile?.jobsCompleted ?? 0) > 0 || (profile?.totalEarned ?? 0) > 0;

  bool get isOwedMoney => pendingPaymentTotal > 0;

  /// Jobs waiting on the worker to say yes or no. What the dashboard nudges about.
  int get needsMyAnswerCount =>
      upcoming.where((j) => j.needsMyAnswer).length +
      inProgress.where((j) => j.needsMyAnswer).length;
}

/// One job on a worker's list, from whichever route put them on it.
class WorkerJobSummary {
  const WorkerJobSummary({
    required this.id,
    required this.source,
    required this.title,
    required this.businessName,
    required this.scheduledDate,
    this.location,
    this.myWage,
    this.myWageUnit,
    this.myStatus = '',
    this.workStartedAt,
    this.needsMyAnswer = false,
    this.myRole,
  });

  /// The booking id, or the post id for standalone work.
  final String id;

  /// `Booking` or `Post`. A standalone post has no order behind it, so it cannot be opened the
  /// same way — the screen has to know which kind it is holding before offering to open it.
  final String source;

  final String title;
  final String businessName;
  final DateTime scheduledDate;
  final String? location;

  /// This worker's own wage, never the price the customer pays. Null when paid outside Zuno.
  final double? myWage;
  final String? myWageUnit;

  /// Where this worker stands on the job, not where the job stands.
  final String myStatus;

  final DateTime? workStartedAt;
  final bool needsMyAnswer;

  /// Lead, Supervisor or Support on this job — null for a plain crew member, and always null
  /// on a hiring post, which is taken on alone.
  final String? myRole;

  bool get isFromBooking => source == 'Booking';
  bool get hasStarted => workStartedAt != null;

  /// "₹800 per event", or null when there is no wage to state.
  ///
  /// The unit is never dropped: ₹800 an hour and ₹800 for a whole event differ by a factor of
  /// eight on a long day, and a bare figure invites exactly that mistake.
  String? get wageLabel => myWage == null
      ? null
      : '${rupees(myWage!)} ${salaryUnitWords(myWageUnit ?? 'PerEvent')}';

  String get whenLabel => relativeDayLabel(scheduledDate);
}

/// A wage that has been earned and not received.
class WorkerPendingPayment {
  const WorkerPendingPayment({
    required this.applicationId,
    required this.title,
    required this.businessName,
    required this.amount,
    this.unit,
    this.paymentStatus = '',
    this.workCompletedAt,
  });

  /// What the worker confirms or disputes against.
  final String applicationId;
  final String title;
  final String businessName;
  final double amount;
  final String? unit;
  final String paymentStatus;
  final DateTime? workCompletedAt;

  /// How the wait reads on screen. Each says who the ball is with.
  String get stateLabel => switch (paymentStatus) {
    'Unpaid' => 'Not sent yet',
    'Processing' => 'On its way',
    'Failed' => 'Payment failed',
    'AwaitingWorkerConfirmation' => 'Confirm you received it',
    _ => paymentStatus,
  };

  /// The one state the worker can act on, rather than only wait through.
  bool get needsMyConfirmation => paymentStatus == 'AwaitingWorkerConfirmation';

  /// Worth flagging: the money was attempted and bounced, which usually means payout details.
  bool get hasFailed => paymentStatus == 'Failed';
}

/// One month of a worker's history.
class WorkerMonthlyEarning {
  const WorkerMonthlyEarning({
    required this.label,
    required this.year,
    required this.month,
    this.jobsCompleted = 0,
    this.earned = 0,
  });

  final String label;
  final int year;
  final int month;
  final int jobsCompleted;
  final double earned;
}
