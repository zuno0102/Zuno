import 'package:zuno/core/ui_config/ui_config.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/core/utils/ui_lookup.dart';
import 'package:zuno/features/booking/domain/entities/booking_service_answer.dart';
import 'package:zuno/features/booking/domain/entities/booking_terms_proposal.dart';
import 'package:zuno/features/booking/domain/entities/booking_worker_assignment.dart';
import 'package:zuno/shared/domain/job_role.dart';
import 'package:zuno/features/booking/domain/entities/rating.dart';
import 'package:zuno/shared/domain/track_state.dart';

class Booking {
  const Booking({
    required this.id,
    this.reference = '',
    this.crewStatus = 'NotStaffed',
    this.activeCrewCount = 0,
    this.wageStatus = '',
    this.wagePayeeCount = 0,
    this.wagePaidPayeeCount = 0,
    this.wageTotalPayable = 0,
    this.wageOutstandingAmount = 0,
    this.workStartedAt,
    required this.businessOwnerProfileId,
    required this.businessName,
    required this.customerProfileId,
    required this.customerName,
    required this.businessServiceId,
    required this.serviceName,
    required this.serviceCategoryName,
    this.variantName,
    this.serviceSubCategoryId,
    this.serviceSubCategoryName,
    this.imageUrl,
    required this.status,
    this.stage = '',
    required this.scheduledDate,
    required this.priceQuoted,
    this.priceType,
    this.serviceAnswers = const [],
    this.agreementStatus = 'NotRequired',
    this.proposals = const [],
    this.businessLogoUrl,
    this.businessPhone,
    this.customerPhone,
    this.requiredWorkerCount = 1,
    this.assignedWorkers = const [],
    this.myAssignmentStatus,
    this.myRole,
    this.myPaymentStatus,
    this.myWageAmount,
    this.notes,
    this.addressLine1,
    this.addressLine2,
    this.latitude,
    this.longitude,
    this.city,
    this.state,
    this.postalCode,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.rating,
  });

  final String id;

  /// The short order code — "#7A3F91C2" — for people to quote and match.
  final String reference;

  /// Staffing progress, a separate track from [status]: NotStaffed, PartStaffed,
  /// FullyStaffed, Done.
  final String crewStatus;

  /// People on the job, counted by the server.
  final int activeCrewCount;

  /// Where the crew's wages stand: NoWagesThroughZuno, Disputed, Outstanding, Settled. Empty
  /// for a customer, and empty when the caller did not ask.
  final String wageStatus;
  final int wagePayeeCount;
  final int wagePaidPayeeCount;
  final double wageTotalPayable;
  final double wageOutstandingAmount;

  /// When the business marked the work under way.
  final DateTime? workStartedAt;
  final String businessOwnerProfileId;
  final String businessName;
  final String? businessLogoUrl;
  final String? businessPhone;
  final String customerProfileId;
  final String customerName;
  final String? customerPhone;
  final String businessServiceId;
  final String serviceName;
  final String serviceCategoryName;
  final String? variantName;

  /// The kind of work this order is for, from the package the customer chose.
  final String? serviceSubCategoryId;
  final String? serviceSubCategoryName;
  final String? imageUrl;
  final int requiredWorkerCount;
  final List<BookingWorkerAssignment> assignedWorkers;
  final String? myAssignmentStatus;

  /// What the viewing worker is on this one job — "Supervisor". Null for everyone else.
  final String? myRole;

  /// Where the viewing worker's own wage stands: `Unpaid`, `Processing`, `Paid`, `Failed`,
  /// `Disputed`, `AwaitingWorkerConfirmation`. Null for anyone who is not a worker on this order.
  ///
  /// Their own row, never [wageStatus], which rolls up the whole crew and is the business's view.
  final String? myPaymentStatus;

  /// The wage on the viewing worker's own assignment, or null when there is none on it.
  ///
  /// Null is ordinary rather than exceptional: a worker who reached this order through a hiring post
  /// has a mirror assignment deliberately carrying no salary, because the wage lives on the
  /// application and money is never recorded twice. Null means "my pay is not held on this row", not
  /// "I am owed nothing".
  final double? myWageAmount;

  final String status;

  /// Where this stands as the viewer reads it — an order stage code such as `AwaitingPayment`,
  /// decided by the server. Its name and colour come from the order stage list.
  final String stage;
  final DateTime scheduledDate;
  final String? notes;
  final double priceQuoted;

  /// What [priceQuoted] is a price of — `Fixed`, `Hourly`, `Daily` or `PerPerson`.
  ///
  /// Null on orders placed before the server recorded it; those show a bare figure, exactly as
  /// they always did.
  final String? priceType;

  /// What the customer told the business about this job.
  final List<BookingServiceAnswer> serviceAnswers;

  /// Who owes the other a reply on the crew and price: NotRequired, AwaitingBusiness,
  /// AwaitingCustomer, Agreed or Closed. Viewer-neutral; the screens turn it into
  /// "waiting for you" or "waiting for them".
  final String agreementStatus;

  /// Every offer and counter-offer, oldest first.
  final List<BookingTermsProposal> proposals;

  final String? addressLine1;
  final String? addressLine2;

  /// The pinned job location. Null on bookings made before pinning existed.
  final double? latitude;
  final double? longitude;
  final String? city;
  final String? state;
  final String? postalCode;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final Rating? rating;

  // ---- Price ---------------------------------------------------------------------------------

  /// Whether the total depends on a crew size still to be agreed.
  bool get isPricedPerPerson => isPerPersonPrice(priceType);

  /// What to show where the order's price goes.
  ///
  /// A per-person order means two different things at two moments, and [priceQuoted] holds a
  /// different number in each:
  ///
  ///  * before the crew size is agreed it holds the **rate**, so printing it bare would put ₹500
  ///    on a ₹9,000 job;
  ///  * accepting an offer overwrites it with the **agreed total**, so multiplying by the crew
  ///    size again would turn ₹9,000 into ₹162,000.
  ///
  /// The crew size is what tells the two apart: 0 means nothing has been agreed yet.
  String priceDisplay() {
    if (!isPricedPerPerson) {
      return priceType == null
          ? rupees(priceQuoted)
          : priceLabel(priceQuoted, priceType!);
    }

    if (requiredWorkerCount < 1) {
      return '${rupees(priceQuoted)} per person · crew size to be agreed';
    }

    // Settled. The figure is the whole order, with the headcount it was agreed at — the working
    // that got here is on the offer itself, where both sides can read who proposed what.
    return '${rupees(priceQuoted)} · $requiredWorkerCount people';
  }

  // ---- Agreeing the crew and the price -------------------------------------------------------

  /// The offer still on the table, if there is one.
  BookingTermsProposal? get openProposal {
    for (final proposal in proposals) {
      if (proposal.isOpen) return proposal;
    }
    return null;
  }

  /// The offer that was taken up, once terms were settled.
  BookingTermsProposal? get acceptedProposal {
    for (final proposal in proposals) {
      if (proposal.isAccepted) return proposal;
    }
    return null;
  }

  bool get termsAreAgreed => agreementStatus == 'Agreed';

  /// Whether the side looking at this owes the other an answer.
  bool needsMyReply({required bool viewerIsBusiness}) => viewerIsBusiness
      ? agreementStatus == 'AwaitingBusiness'
      : agreementStatus == 'AwaitingCustomer';

  /// Whether the other side is sitting on an offer of ours.
  bool awaitingTheirReply({required bool viewerIsBusiness}) => viewerIsBusiness
      ? agreementStatus == 'AwaitingCustomer'
      : agreementStatus == 'AwaitingBusiness';

  /// "Accept as booked" only makes sense while nothing is being negotiated.
  ///
  /// With an offer open it would mean something else entirely — confirming at the service's
  /// listed price rather than the one on the table — so the server refuses it and the button
  /// should not be there to press.
  bool get canConfirmAsBooked => isPending && openProposal == null;

  // ---- The order's own track -------------------------------------------------------------

  bool get isPending => status == 'Pending';
  bool get isConfirmed => status == 'Confirmed';
  bool get isInProgress => status == 'InProgress';
  bool get isCompleted => status == 'Completed';
  bool get isCancelled => status == 'Cancelled';

  /// Old rows only. Staffing stopped living on the order's status, but history keeps the value,
  /// so it is still read — never written.
  bool get isAssigned => status == 'Assigned';

  /// Whether this order is at a point where its crew can be given roles.
  ///
  /// From the business confirming it until the work is finished, and no wider. A role exists so
  /// somebody can run the job: before it is confirmed there is no job, and once it is done there
  /// is nothing left to run — the work cannot be started or completed twice. Mirrors
  /// `BookingWorkControl.CanHoldRoles` on the server, which refuses the same window.
  bool get canHoldCrewRoles => isConfirmed || isAssigned || isInProgress;

  bool get canBeCancelled => isPending || isConfirmed || isAssigned;
  bool get canBeRated => isCompleted && rating == null;
  bool get canBeCalled => !isPending && !isCancelled;

  /// Whether the two sides may message each other about this order.
  ///
  /// Opens when the business takes the order on, and closes at whichever end comes first: the order
  /// being called off, or the customer rating it. Before confirmation there is nothing agreed to
  /// discuss; after a rating there is nothing left to settle, because rating is the customer's last
  /// act on an order — offered once, and it cannot be taken back.
  ///
  /// The gap between finishing and rating is deliberately left open. That is the window where a
  /// missing item or an invoice actually gets sorted out.
  ///
  /// The server enforces all of this. This only decides whether the button is offered.
  bool get canBeMessaged => canBeCalled && !(isCompleted && rating != null);

  /// Whether the job is over for the crew: the work is finished or the order called off. From then
  /// on a crew row offers no role, chat or call — only what is left to settle, such as a raise
  /// before payment.
  bool get isCrewJobOver => isCompleted || isCancelled;

  /// Whether the business may still phone this member of the crew.
  ///
  /// Two halves: the assignment says *who* may be called, this says *when* — from the moment the
  /// worker is put on the job until it is over.
  ///
  /// Deliberately narrower than [canBeCalled], which governs calls between the business and the
  /// customer and stays true on a finished order: the two parties to a booking may have things to
  /// settle long afterwards, whereas the crew's involvement ends with the job.
  bool canCallCrewMember(BookingWorkerAssignment worker) =>
      worker.canBeCalled && !isCrewJobOver;

  /// Whether the business may message this member of the crew: once they have said yes, until
  /// the job is over.
  bool canMessageCrewMember(BookingWorkerAssignment worker) =>
      !isCrewJobOver && (worker.isAccepted || worker.isCompleted);

  /// Whether the day has come. The order reads as under way from this moment whether or not
  /// anyone has pressed anything — the event is happening; the *work* is a separate question.
  bool hasReachedItsDate({DateTime? now}) =>
      !scheduledDate.isAfter(now ?? DateTime.now());

  /// A confirmed order, on its day, with someone who has actually said yes.
  ///
  /// The date matters: starting next month's wedding today would leave every screen reading that
  /// order wrongly until the event came round. The server refuses it too.
  bool canStartWork({DateTime? now}) =>
      isConfirmed &&
      hasReachedItsDate(now: now) &&
      assignedWorkers.any((w) => w.isAccepted);

  // ---- The four tracks ---------------------------------------------------------------------
  //
  // A cascade: each one opens as the one before it advances, so the business always has exactly
  // one thing to do and can see what it unlocks. Every state is derived — nothing here is stored
  // twice, and nothing has to run at midnight for the event to notice its own date.
  //
  //   confirm        -> EVENT active
  //   the day comes  -> EVENT in progress,  WORK active
  //   start work     -> WORK in progress,   PAYMENT active
  //   mark completed -> EVENT + WORK done,  PAYMENT in progress
  //   pay the crew   -> PAYMENT done        -> the whole order is finished

  bool get isWorkStarted => workStartedAt != null;
  bool get isWorkCompleted => completedAt != null;

  /// Only work that has actually begun can be closed.
  bool get canCompleteWork => isInProgress;

  /// The event itself: is the day here, and did it happen?
  TrackState eventState({DateTime? now}) {
    if (isCancelled) return TrackState.lapsed;
    if (isCompleted) return TrackState.completed;
    if (isPending) return TrackState.notStarted;
    // Work under way means the event is under way — somebody is on site. Said outright rather
    // than left to the clock to agree: the two must never read differently, and a scheduled
    // date that was edited after the crew arrived would otherwise make them.
    if (isWorkStarted) return TrackState.inProgress;
    return hasReachedItsDate(now: now)
        ? TrackState.inProgress
        : TrackState.active;
  }

  /// The crew being on site. Opens when the day does, not when the order is accepted.
  TrackState workState({DateTime? now}) {
    if (isCancelled) return TrackState.lapsed;
    if (isWorkCompleted) return TrackState.completed;
    if (isWorkStarted) return TrackState.inProgress;
    if (isPending) return TrackState.notStarted;
    return hasReachedItsDate(now: now)
        ? TrackState.active
        : TrackState.notStarted;
  }

  /// The wages. Nothing is owed until somebody actually works, so this stays shut until then
  /// rather than pretending a job weeks away already carries a debt.
  TrackState paymentState() {
    if (isCancelled) return TrackState.lapsed;
    // Nobody owed, or everybody paid. A roster-staffed order settles the moment work is done —
    // there is no payment coming that could ever move it.
    if (isWorkCompleted && isWageClear) return TrackState.completed;
    if (isWorkCompleted) return TrackState.inProgress;
    if (isWorkStarted) return TrackState.active;
    return TrackState.notStarted;
  }

  /// Every track home. The one state that counts toward the business's record.
  bool get isEntirelyComplete =>
      eventState() == TrackState.completed &&
      workState() == TrackState.completed &&
      paymentState() == TrackState.completed;

  /// A short line under each track saying what its state actually rests on.
  String eventDetail({DateTime? now}) => switch (eventState(now: now)) {
    TrackState.completed => 'Finished',
    TrackState.inProgress => 'The day is here',
    TrackState.lapsed => 'Called off',
    TrackState.active => 'Due ${formatDayMonth(scheduledDate)}',
    TrackState.notStarted => 'Not confirmed yet',
  };

  String workDetail({DateTime? now}) => switch (workState(now: now)) {
    TrackState.completed => 'Marked completed',
    TrackState.inProgress => 'Crew on the job',
    TrackState.lapsed => 'Called off',
    TrackState.active => 'Ready to start',
    TrackState.notStarted => 'Waiting for the day',
  };

  String paymentDetail() => switch (paymentState()) {
    TrackState.completed =>
      owesNoWages ? 'No wages through Zuno' : 'All crew paid',
    TrackState.inProgress =>
      isWageDisputed ? 'Disputed' : '${rupees(wageOutstandingAmount)} owed',
    TrackState.lapsed => 'Called off',
    TrackState.active => 'Due after the work',
    TrackState.notStarted => 'Nothing owed yet',
  };

  // ---- The crew's track ------------------------------------------------------------------
  //
  // Counted by the server, which excludes crew who have finished. The old client-side count
  // included them, so a finished job could still read as fully staffed.

  int get activeWorkerCount => activeCrewCount;

  bool get isFullyStaffed => activeCrewCount >= requiredWorkerCount;

  bool get isCrewDone => crewStatus == 'Done';

  /// "2 of 5 · Part staffed".
  String get crewStatusLabel =>
      UiConfig.current.own('BookingCrewStatus', crewStatus)?.label ??
      crewStatus;

  String get crewCountLabel => '$activeCrewCount of $requiredWorkerCount';

  bool get myAssignmentAwaitingResponse => myAssignmentStatus == 'Assigned';
  bool get myAssignmentIsAccepted => myAssignmentStatus == 'Accepted';
  bool get myAssignmentIsCompleted => myAssignmentStatus == 'Completed';

  /// Whether the viewing worker may message and call the business about this job: once they have
  /// taken it on (or finished it), and not on a cancelled order.
  ///
  /// The business, never the customer — the business is the middle man, and workers and customers
  /// do not contact each other directly.
  bool get workerCanContactBusiness =>
      !isCancelled && (myAssignmentIsAccepted || myAssignmentIsCompleted);

  /// Whether the viewer is the Lead on this job, and so can move its work status.
  ///
  /// Only Lead. Supervisor watches the work and Support fixes what it needs; neither declares that
  /// it started. A job has one person answerable for that.
  bool get iLeadThisJob => JobRole.grantsWorkControl(myRole);

  /// Whether the viewer holds any of the three roles on this job 2014 for showing the title, not for
  /// granting anything.
  bool get iHaveARoleOnThisJob => (myRole ?? '').trim().isNotEmpty;

  // ---- The wages' track -------------------------------------------------------------------
  //
  // Rolled up by the server from the hiring raised against this order. Blank for a customer, and
  // blank when nobody asked for it — which is not the same as owing nothing.

  bool get hasWageInfo => wageStatus.isNotEmpty;
  bool get owesNoWages => wageStatus == 'NoWagesThroughZuno';
  bool get isWageSettled => wageStatus == 'Settled';
  bool get isWageDisputed => wageStatus == 'Disputed';
  bool get hasOutstandingWages => wageStatus == 'Outstanding';

  /// Nobody is waiting on money — everyone was paid, or nobody was owed.
  bool get isWageClear => isWageSettled || owesNoWages;

  // ---- The viewing worker's own wage, as opposed to the crew's -----------------------------------

  /// A wage is recorded against this worker's own row on this order.
  bool get hasMyWage => (myWageAmount ?? 0) > 0;

  /// My own wage is set and has not reached me.
  ///
  /// Requires an amount as well as a status: a mirror assignment from a hiring post sits at `Unpaid`
  /// for ever because it carries no money at all, and reading that as an outstanding wage is exactly
  /// how a paid job came to be labelled unpaid.
  bool get myWageIsOutstanding =>
      hasMyWage &&
      const {
        'Unpaid',
        'Processing',
        'Failed',
        'AwaitingWorkerConfirmation',
      }.contains(myPaymentStatus);

  bool get myWageIsPaid => myPaymentStatus == 'Paid';

  String get wageStatusLabel =>
      UiConfig.current.own('BookingWageStatus', wageStatus)?.label ?? '';

  /// "2 of 5 paid" — only meaningful when somebody is actually owed.
  String get wagePaidLabel => '$wagePaidPayeeCount of $wagePayeeCount paid';

  // ---- The whole order --------------------------------------------------------------------
}
