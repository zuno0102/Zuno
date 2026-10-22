import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post_application.dart';
import 'package:zuno/shared/domain/track_state.dart';

class HiringPost {
  const HiringPost({
    required this.id,
    required this.businessOwnerProfileId,
    this.bookingId,
    this.bookingReference,
    this.bookingStatus,
    required this.businessName,
    this.businessLogoUrl,
    this.businessPhone,
    required this.title,
    this.description,
    this.imageUrl,
    required this.eventDate,
    this.durationMinutes = 120,
    this.workStartedAt,
    this.workCompletedAt,
    this.hiringStoppedAt,
    this.settledAt,
    this.totalPayable = 0,
    this.outstandingAmount = 0,
    this.payeeCount = 0,
    this.paidPayeeCount = 0,
    this.hasDisputedPayment = false,
    this.isFullyComplete = false,
    this.serviceSubCategoryId,
    this.serviceSubCategoryName,
    this.location,
    this.districtName,
    this.latitude,
    this.longitude,
    this.locationPrecision = 'None',
    this.distanceKm,
    required this.workersNeeded,
    required this.salaryAmount,
    this.salaryUnit = 'PerEvent',
    required this.confirmedCount,
    this.pendingOfferCount = 0,
    this.filledCount = 0,
    required this.status,
    required this.createdDate,
    this.myApplicationStatus,
    this.myApplicationId,
    this.myAgreedSalaryAmount,
    this.myPaymentStatus,
    this.myPaidAt,
    this.myDisputeReason,
    this.applications = const [],
  });

  final String id;
  final String businessOwnerProfileId;

  /// The customer order this crew was hired for, when the post came from one.
  final String? bookingId;

  /// "Catering · 28 Sep" — what the hire is for, named by the server.
  final String? bookingReference;

  /// Where that order stands — Confirmed, Completed, Cancelled. Null for a standalone post,
  /// which answers to no order.
  final String? bookingStatus;
  final String businessName;
  final String? businessLogoUrl;

  /// The business's phone, on a worker's own accepted jobs only — who a worker calls about the job.
  /// Customers and workers never contact each other directly; the business is the middle man.
  final String? businessPhone;
  final String title;
  final String? description;
  final String? imageUrl;
  final DateTime eventDate;
  final int durationMinutes;

  /// When the business said the crew started. Null while the job is only scheduled.
  final DateTime? workStartedAt;

  final DateTime? workCompletedAt;

  /// When the business stopped hiring and chose to manage with the crew it has.
  final DateTime? hiringStoppedAt;

  /// When the last worker was paid. The moment the hiring genuinely ended.
  final DateTime? settledAt;

  /// What the whole crew is owed, calculated on the server from each agreed wage.
  final double totalPayable;

  /// Still owed. Zero exactly when everyone has been paid.
  final double outstandingAmount;

  final int payeeCount;
  final int paidPayeeCount;

  /// A worker has reported their wages never arrived.
  final bool hasDisputedPayment;

  /// Work done *and* everyone paid — the whole hiring finished, as distinct from the event
  /// merely being over or the places merely being filled. Only this counts toward the
  /// business's completed-job total.
  final bool isFullyComplete;

  /// The kind of work, inside the category — "Interior wall painting".
  final String? serviceSubCategoryId;
  final String? serviceSubCategoryName;
  final String? location;

  /// The district the job is in, for grouping the feed and labelling a card.
  final String? districtName;

  /// Where the job is, for a map pin. Null when the post has no position.
  final double? latitude;
  final double? longitude;

  /// `None`, `DistrictApprox`, `Geocoded` or `Pinned`.
  ///
  /// `None` means the post cannot take part in a distance search, and is listed apart rather than
  /// hidden. Anything below `Pinned` should be shown as approximate rather than exact.
  final String locationPrecision;

  /// Straight-line kilometres from the worker, or null.
  ///
  /// Null for three different reasons, told apart by [locationPrecision]: the viewer is not a
  /// worker, the worker gave no location, or the job has no position.
  final double? distanceKm;

  bool get hasPosition => latitude != null && longitude != null;

  /// Whether the position is exact enough to trust at a small radius.
  bool get isLocationApproximate => locationPrecision != 'Pinned';

  /// True when the job has no usable location at all.
  bool get hasNoLocation => locationPrecision == 'None' || !hasPosition;

  /// "1.3 km away", or null when there is no distance to state.
  ///
  /// Under 10km is given to one decimal place, because at walking distance the difference between
  /// 1.3 and 2.2 matters; beyond that it is rounded, since nobody chooses between 46 and 47 km.
  String? get distanceLabel {
    if (distanceKm case final km?) {
      return km < 10
          ? '${km.toStringAsFixed(1)} km away'
          : '${km.round()} km away';
    }
    return null;
  }

  final int workersNeeded;
  final double salaryAmount;
  final String salaryUnit;
  final int confirmedCount;
  final int pendingOfferCount;

  /// Workers who have accepted and are actually turning up.
  final int filledCount;
  final String status;
  final DateTime createdDate;
  final String? myApplicationStatus;
  final String? myApplicationId;
  final double? myAgreedSalaryAmount;

  /// For a worker viewing this post: whether their own wages have been paid. Carried on the post
  /// because [applications] is withheld from workers, so this is the only place they can see it.
  final String? myPaymentStatus;
  final DateTime? myPaidAt;
  final String? myDisputeReason;

  final List<HiringPostApplication> applications;

  bool get isOpen => status == 'Open';
  bool get hasApplied => myApplicationStatus != null;

  /// The business has approved this worker and is waiting on their answer.
  bool get hasPendingOffer => myApplicationStatus == 'Confirmed';
  bool get myOfferAccepted => myApplicationStatus == 'Accepted';
  bool get myOfferDeclined => myApplicationStatus == 'Declined';
  bool get isFullyStaffed => filledCount >= workersNeeded;

  /// Whether another worker can still be sent to this job. Only accepted workers count —
  /// an unanswered offer reserves nothing, so backups can be lined up while waiting.
  /// Mirrors HiringPost.CanOfferAnotherWorker on the server.
  bool get canOfferAnotherWorker => filledCount < workersNeeded;

  /// Once anyone is confirmed the salary is contractually locked — the business may still
  /// raise it, but never lower it, and the unit can no longer change.
  bool get isSalaryLocked => confirmedCount > 0;

  /// Whether the event itself is behind us. Derived from [eventDate] rather than stored, so
  /// a post becomes Completed the moment its time passes — no scheduled job to run or miss.
  /// [now] is injectable for tests.
  bool isEventOver({DateTime? now}) =>
      (now ?? DateTime.now()).isAfter(eventDate.toLocal());

  /// Whether the event window has opened but not yet closed.
  bool isEventUnderway({DateTime? now}) {
    final at = now ?? DateTime.now();
    return !at.isBefore(eventDate.toLocal()) &&
        at.isBefore(eventEndDate.toLocal());
  }

  bool get isHiringStopped => hiringStoppedAt != null;

  /// Whether hiring for this job is over for good: stopped by the business, the work marked
  /// done, or the scheduled end gone by. A job already under way still hires — a worker who can
  /// arrive late beats being one short all day. Mirrors HiringPost.IsHiringOver on the server.
  bool isHiringOver({DateTime? now}) =>
      isHiringStopped ||
      isWorkCompleted ||
      !(now ?? DateTime.now()).isBefore(eventEndDate.toLocal());

  /// Whether workers can actually see and apply to this post right now.
  ///
  /// Two independent things close a post: every place being taken, and hiring being over.
  /// [status] only tracks the first — it is a stored column that nothing updates when a time
  /// simply goes by — so the rest is layered on here. Mirrors the server, which filters the
  /// worker feed and the apply guard on the same conditions.
  bool isOpenToWorkers({DateTime? now}) => isOpen && !isHiringOver(now: now);

  /// Already under way and still short-handed: the worker feed flags it as needed now.
  bool isNeededNow({DateTime? now}) =>
      isOpenToWorkers(now: now) && isEventUnderway(now: now);

  /// Whether the business's Hiring tab still lists this post: it is still a vacancy being
  /// filled. Once hiring stops or the work is done, the job is run from the Orders tab instead —
  /// unless a worker's pay failed or is disputed, because this card is where the business rings
  /// them about it.
  bool isListedAsVacancy({DateTime? now}) =>
      (!isHiringOver(now: now) && !isOrderClosed) || hasPaymentProblem;

  /// A worker's payout failed or they say it never arrived: someone has to sort it out by phone.
  bool get hasPaymentProblem =>
      applications.any((a) => a.isPaymentFailed || a.isPaymentDisputed);

  /// Whether the order behind this post is over — finished or called off.
  ///
  /// A post does not close itself when its order ends, so [status] keeps saying Open long after
  /// there is anything left to staff. Standalone posts answer to no order and are never dead
  /// by this test.
  bool get isOrderClosed =>
      bookingStatus == 'Completed' || bookingStatus == 'Cancelled';

  /// Whether this job is worth putting in front of the business as somewhere to send a worker.
  ///
  /// Three things have to hold at once, and only the first is what [status] tracks: the post is
  /// open, hiring is not over (stopped, done, or past its end), and there is a place left once
  /// accepted workers are counted. The order behind it must still be live too — the one
  /// condition nothing on the post itself can tell you.
  bool isInvitable({DateTime? now}) =>
      isOpen &&
      !isOrderClosed &&
      !isHiringOver(now: now) &&
      canOfferAnotherWorker;

  /// The business can stop hiring at any point before the job is over and manage with the
  /// crew it has.
  bool canStopHiring({DateTime? now}) => !isHiringOver(now: now);

  /// Deleting an upcoming post with a hired crew pulls the ground out from under them,
  /// so the confirmation dialog warns harder in that case — it does not block it.
  bool get deleteNeedsStrongWarning => !isEventOver() && confirmedCount > 0;

  /// When the work is scheduled to finish.
  DateTime get eventEndDate =>
      eventDate.add(Duration(minutes: durationMinutes));

  bool get isWorkStarted => workStartedAt != null;
  bool get isWorkCompleted => workCompletedAt != null;

  /// Whether the business may still phone this member of the crew.
  ///
  /// Two halves: the application says *who* may be called, this says *when*. The option lives
  /// from the moment the worker is confirmed until the job is over -- and then, for as long as
  /// their money is unsettled, because a failed or disputed payout is precisely what a business
  /// needs to ring somebody about after the work is done.
  ///
  /// Both completion signals are load-bearing. [isWorkCompleted] catches a standalone post, which
  /// answers to no order and so is never closed by [isOrderClosed]; [isOrderClosed] catches one
  /// whose booking finished or was called off without the post being marked done.
  bool canCallCrewMember(HiringPostApplication application) =>
      application.canBeCalled &&
      (!(isWorkCompleted || isOrderClosed) || application.hasUnsettledPay);

  /// Whether there are wages still to pay. What puts the "Pay all" button on a card.
  bool get hasOutstandingPayment => outstandingAmount > 0;

  /// Part-way through: some of the crew paid, some not. Distinct from untouched, because
  /// the button reads "Resume" rather than "Pay all".
  bool get isPartiallyPaid => paidPayeeCount > 0 && hasOutstandingPayment;

  /// "5 of 5 unpaid" — the line above the pay button.
  String get outstandingLabel {
    final unpaid = payeeCount - paidPayeeCount;
    return '$unpaid of $payeeCount unpaid';
  }

  /// The business can say the crew has started once the event time has arrived and somebody
  /// is actually hired. Mirrors the server's guards so the button is hidden rather than failing.
  bool canStartWork({DateTime? now}) =>
      !isWorkStarted &&
      !isWorkCompleted &&
      filledCount > 0 &&
      !(now ?? DateTime.now()).isBefore(eventDate.toLocal());

  /// The business can close the work off once it has actually started and is not already done.
  /// Marking it complete releases the crew for other jobs before the scheduled end time.
  bool canMarkComplete({DateTime? now}) => isWorkStarted && !isWorkCompleted;

  // ---- The three tracks --------------------------------------------------------------------
  //
  // "Complete" used to mean three unrelated things on one card — the date had passed, the
  // business had marked the work done, and everyone had been paid — with nothing on screen
  // telling them apart. These separate the three, so each reads on its own terms.

  /// Whether anybody was ever actually taken on for this job.
  ///
  /// The dividing line between an event that happened and a date that merely went by. A post
  /// nobody accepted is not a completed event, however far in the past it now sits.
  bool get hadCrew => filledCount > 0 || isWorkStarted;

  /// Where the event itself stands: due, happening, over — or gone by unfilled.
  TrackState eventState({DateTime? now}) {
    if (isEventUnderway(now: now)) return TrackState.inProgress;
    if (isEventOver(now: now)) {
      return hadCrew ? TrackState.completed : TrackState.lapsed;
    }
    return TrackState.active;
  }

  /// Where the crew stands: waiting for the day, due on site, working, or finished.
  ///
  /// Deliberately dormant until the event itself begins. The tracks run as a cascade — each one
  /// only wakes when the one above it is under way — so a job weeks out reads as nothing to do,
  /// which is the truth. Hiring progress is not lost: the detail line carries it throughout.
  TrackState workersState({DateTime? now}) {
    if (isWorkCompleted) return TrackState.completed;
    if (isWorkStarted) return TrackState.inProgress;
    // Nothing left to hire for once hiring is over with nobody taken on. Not before: a job
    // under way still takes late joiners.
    if (isHiringOver(now: now) && filledCount == 0) return TrackState.lapsed;
    // The crew is only "active" from the moment they are actually due on site.
    if (isEventUnderway(now: now) || isEventOver(now: now)) {
      return TrackState.active;
    }
    return TrackState.notStarted;
  }

  /// Where the wages stand. Nothing is owed until the work has actually begun, so this stays
  /// dormant rather than pretending a scheduled job already carries a debt.
  TrackState paymentState() {
    if (isFullyComplete) return TrackState.completed;
    if (isWorkCompleted) return TrackState.inProgress;
    if (isWorkStarted) return TrackState.active;
    return TrackState.notStarted;
  }

  /// All three tracks finished. The one state that credits the business's record — an event
  /// that happened and a crew that went unpaid earns nothing.
  bool isSuccessfullyCompleted({DateTime? now}) =>
      eventState(now: now) == TrackState.completed &&
      workersState(now: now) == TrackState.completed &&
      paymentState() == TrackState.completed;

  /// The event came and went with nobody hired. Worth surfacing plainly: the post did not
  /// succeed, and the only useful next steps are to repost it or delete it.
  bool isLapsed({DateTime? now}) => eventState(now: now) == TrackState.lapsed;

  /// A short line under each track name, saying what the state actually rests on.
  String eventDetail({DateTime? now}) => switch (eventState(now: now)) {
    TrackState.completed =>
      'Finished ${formatDayMonth(eventEndDate.toLocal())}',
    TrackState.inProgress => 'Happening now',
    TrackState.lapsed =>
      'Passed ${formatDayMonth(eventDate.toLocal())}, unfilled',
    _ => 'Due ${formatDayMonth(eventDate.toLocal())}',
  };

  String workersDetail({DateTime? now}) => switch (workersState(now: now)) {
    TrackState.completed => '$filledCount worked this job',
    TrackState.inProgress => '$filledCount on the job',
    TrackState.lapsed => 'Nobody was hired',
    // Hiring is still worth reporting while the track itself is dormant — it is the one thing
    // the business can act on before the day arrives.
    _ when isHiringStopped && filledCount < workersNeeded =>
      '$filledCount of $workersNeeded · hiring stopped',
    _ => '$filledCount of $workersNeeded hired',
  };

  String paymentDetail() => switch (paymentState()) {
    TrackState.completed => 'All $payeeCount paid',
    TrackState.inProgress =>
      hasDisputedPayment ? 'Disputed' : '${rupees(outstandingAmount)} owed',
    TrackState.active => 'Due after the work',
    // Payment never lapses on its own — it simply never opened, which notStarted covers.
    TrackState.notStarted || TrackState.lapsed => 'Nothing owed',
  };

  // ---- The viewing worker's own wages ------------------------------------------------------
  //
  // Separate from the crew-wide payment track: a worker cares whether *they* were paid, and the
  // post-level figures cover everybody. These read the fields the server fills in for the
  // viewer alone, since the applicant list is withheld from workers.

  bool get isMyPaymentPaid => myPaymentStatus == 'Paid';
  bool get isMyPaymentDisputed => myPaymentStatus == 'Disputed';

  /// Whether to offer the confirm / dispute buttons.
  bool get canRespondToMyPayment =>
      myApplicationId != null &&
      myPaymentStatus != null &&
      myPaymentStatus != 'Unpaid' &&
      !isMyPaymentPaid &&
      !isMyPaymentDisputed;

  TrackState get myPaymentState {
    if (isMyPaymentPaid) return TrackState.completed;
    if (isMyPaymentDisputed) return TrackState.inProgress;
    if (myPaymentStatus != null && myPaymentStatus != 'Unpaid') {
      return TrackState.inProgress;
    }
    if (isWorkStarted) return TrackState.active;
    return TrackState.notStarted;
  }

  String get myPaymentDetail {
    final amount = myAgreedSalaryAmount;
    final money = amount == null ? '' : rupees(amount);
    if (isMyPaymentPaid) return '$money received';
    if (isMyPaymentDisputed) return 'You reported this';
    if (canRespondToMyPayment) return '$money sent — confirm it';
    if (isWorkCompleted) return '$money owed';
    return money.isEmpty ? 'After the work' : '$money after the work';
  }

  /// "3:00 PM – 5:00 PM (2h)" — the window this job occupies in a worker's day.
  String get scheduleLabel {
    final start = eventDate.toLocal();
    final end = eventEndDate.toLocal();
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    final length = [
      if (hours > 0) '${hours}h',
      if (mins > 0) '${mins}m',
    ].join(' ');
    return '${formatTime(start)} – ${formatTime(end)} ($length)';
  }

  String get salaryLabel =>
      '${rupees(salaryAmount)} '
      '${salaryUnitWords(salaryUnit)}';
}
