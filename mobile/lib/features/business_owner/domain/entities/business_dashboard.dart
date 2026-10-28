import 'package:zuno/core/ui_config/ui_config.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/shared/domain/business_trust.dart';

/// The business home screen: what has been delivered, split by the kind of work.
class BusinessDashboard {
  const BusinessDashboard({
    this.eventsCompleted = 0,
    this.upcomingEvents = 0,
    this.awaitingPaymentEvents = 0,
    this.cancelledEvents = 0,
    this.totalRevenue = 0,
    this.crewEventsCompleted = 0,
    this.activeWorkers = 0,
    this.activeServices = 0,
    this.inactiveServices = 0,
    this.byCategory = const [],
    this.trend = const [],
    this.upcoming = const [],
    this.awaitingPayment = const [],
    this.cancelled = const [],
    this.crewEvents = const [],
    this.workers = const [],
    this.trust = const BusinessTrust(),
  });

  /// Customer bookings closed for good — event, crew, work and payment all done. The figure
  /// that splits by category.
  final int eventsCompleted;

  /// Confirmed bookings whose date is still ahead. A request not yet confirmed is not counted.
  final int upcomingEvents;

  /// Work marked complete while somebody on the crew is still unpaid.
  final int awaitingPaymentEvents;
  final int cancelledEvents;
  final double totalRevenue;

  /// Crew events run through hiring posts. Separate because a hiring post is a call for
  /// workers and carries no service category, so it cannot appear in the split.
  final int crewEventsCompleted;

  /// People on the roster who accepted and were never removed — who can be put on a job today.
  final int activeWorkers;

  /// Services customers can find and book right now.
  final int activeServices;

  /// Services switched off: kept, but hidden from customers.
  final int inactiveServices;

  final List<CategoryBreakdown> byCategory;
  final List<MonthlyActivity> trend;

  final List<DashboardEvent> upcoming;

  /// Work done but a wage still owed, most recently finished first.
  final List<DashboardEvent> awaitingPayment;
  final List<DashboardEvent> cancelled;
  final List<CrewEvent> crewEvents;

  /// The active roster, free workers first.
  final List<DashboardWorker> workers;
  final BusinessTrust trust;

  /// Whether the trend chart has anything worth drawing.
  bool get hasTrend => trend.any((m) => m.completed > 0);

  int get busiestMonthCount => trend.isEmpty
      ? 0
      : trend.map((m) => m.completed).reduce((a, b) => a > b ? a : b);
}

/// One main category — "Painting 2" — and the sub-categories inside it.
class CategoryBreakdown {
  const CategoryBreakdown({
    required this.serviceCategoryId,
    required this.categoryName,
    required this.count,
    this.revenue = 0,
    this.subCategories = const [],
  });

  final String serviceCategoryId;
  final String categoryName;
  final int count;
  final double revenue;
  final List<SubCategoryBreakdown> subCategories;
}

/// "Acrylic painting 1" — one line inside a category.
class SubCategoryBreakdown {
  const SubCategoryBreakdown({
    required this.name,
    required this.count,
    this.revenue = 0,
  });

  final String name;
  final int count;
  final double revenue;
}

/// One booking behind a dashboard tile.
class DashboardEvent {
  const DashboardEvent({
    required this.id,
    required this.serviceName,
    required this.categoryName,
    required this.customerName,
    required this.scheduledDate,
    required this.status,
    this.stage = '',
    this.subCategoryName,
    this.price = 0,
    this.requiredWorkerCount = 1,
    this.cancelledAt,
    this.cancellationReason,
    this.city,
  });

  final String id;
  final String serviceName;
  final String categoryName;
  final String? subCategoryName;
  final String customerName;
  final DateTime scheduledDate;
  final double price;
  final int requiredWorkerCount;
  final String status;

  /// The order stage code for the row's chip, named and coloured by the stage list.
  final String stage;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final String? city;

  /// Days until it happens; negative once it has passed.
  int get daysAway => scheduledDate.difference(DateTime.now()).inDays;

  /// Shares the wording with every other relative date in the app, so a booking and a worker's
  /// next job are not described two different ways on the same screen.
  String get whenLabel => relativeDayLabel(scheduledDate);
}

/// One crew event — a hiring post the business ran.
class CrewEvent {
  const CrewEvent({
    required this.id,
    required this.title,
    required this.eventDate,
    this.location,
    this.workersNeeded = 1,
    this.workersHired = 0,
    this.workCompletedAt,
    this.isFullySettled = false,
    this.totalWages = 0,
    this.outstandingWages = 0,
  });

  final String id;
  final String title;
  final DateTime eventDate;
  final String? location;
  final int workersNeeded;
  final int workersHired;
  final DateTime? workCompletedAt;
  final bool isFullySettled;
  final double totalWages;
  final double outstandingWages;

  bool get isWorkDone => workCompletedAt != null;

  /// Work finished and every worker paid — the only state that counts to the record.
  bool get isFullyComplete => isWorkDone && isFullySettled;

  String get crewLabel => '$workersHired of $workersNeeded hired';
}

/// One person on the roster, as the dashboard shows them.
class DashboardWorker {
  const DashboardWorker({
    required this.workerProfileId,
    required this.workerName,
    required this.availabilityStatus,
    this.workerPhone,
    this.jobsCompleted = 0,
    required this.sinceDate,
    this.busyOn,
  });

  final String workerProfileId;
  final String workerName;
  final String? workerPhone;

  /// AtWork, Booked or Active — the same three the workers tab shows.
  final String availabilityStatus;

  /// Jobs finished for this business. What earns them the next one.
  final int jobsCompleted;
  final DateTime sinceDate;

  /// When the job holding them starts — the soonest, if there is more than one. Null when free.
  final DateTime? busyOn;

  bool get isAtWork => availabilityStatus == 'AtWork';
  bool get isBooked => availabilityStatus == 'Booked';

  /// Nothing on their plate — the ones worth reading first when staffing a job.
  bool get isFree => !isAtWork && !isBooked;

  String get availabilityLabel =>
      UiConfig.current.label('WorkerAvailability.Business', availabilityStatus);

  /// "From 23 Sep 09:00" — when the job holding them starts. Null when free, so the row omits
  /// the line entirely.
  ///
  /// "Booked" on its own cannot be acted on: it reads the same for someone busy this afternoon
  /// and someone busy in March. The work itself is never named — the diary spans every business
  /// this worker serves, and one business has no claim on another's customers.
  String? get busyDetail {
    final at = busyOn;
    if (at == null) return null;

    return 'From ${formatDayMonth(at)} ${formatTime(at)}';
  }

  String get experienceLabel => switch (jobsCompleted) {
    0 => 'No jobs yet',
    1 => '1 job done',
    _ => '$jobsCompleted jobs done',
  };
}

/// One month of customer activity.
class MonthlyActivity {
  const MonthlyActivity({
    required this.label,
    required this.year,
    required this.month,
    this.completed = 0,
    this.revenue = 0,
  });

  final String label;
  final int year;
  final int month;
  final int completed;
  final double revenue;
}
