import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/worker/data/models/worker_profile_model.dart';
import 'package:zuno/features/worker/domain/entities/worker_dashboard.dart';

part 'worker_dashboard_model.g.dart';

@JsonSerializable(createToJson: false)
class WorkerDashboardModel {
  const WorkerDashboardModel({
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

  factory WorkerDashboardModel.fromJson(Map<String, dynamic> json) =>
      _$WorkerDashboardModelFromJson(json);

  final WorkerProfileModel? profile;
  final int inProgressCount;
  final int upcomingCount;
  final int openHiringPostCount;
  final List<WorkerJobSummaryModel> inProgress;
  final List<WorkerJobSummaryModel> upcoming;
  final List<WorkerJobSummaryModel> completed;
  final List<WorkerPendingPaymentModel> pendingPayments;
  final double pendingPaymentTotal;
  final List<WorkerMonthlyEarningModel> trend;

  WorkerDashboard toEntity() => WorkerDashboard(
    profile: profile?.toEntity(),
    inProgressCount: inProgressCount,
    upcomingCount: upcomingCount,
    openHiringPostCount: openHiringPostCount,
    inProgress: inProgress.map((j) => j.toEntity()).toList(),
    upcoming: upcoming.map((j) => j.toEntity()).toList(),
    completed: completed.map((j) => j.toEntity()).toList(),
    pendingPayments: pendingPayments.map((p) => p.toEntity()).toList(),
    pendingPaymentTotal: pendingPaymentTotal,
    trend: trend.map((m) => m.toEntity()).toList(),
  );
}

@JsonSerializable(createToJson: false)
class WorkerJobSummaryModel {
  const WorkerJobSummaryModel({
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
  });

  factory WorkerJobSummaryModel.fromJson(Map<String, dynamic> json) =>
      _$WorkerJobSummaryModelFromJson(json);

  final String id;
  final String source;
  final String title;
  final String businessName;
  final DateTime scheduledDate;
  final String? location;
  final double? myWage;
  final String? myWageUnit;
  final String myStatus;
  final DateTime? workStartedAt;
  final bool needsMyAnswer;

  WorkerJobSummary toEntity() => WorkerJobSummary(
    id: id,
    source: source,
    title: title,
    businessName: businessName,
    // Local time on the way in, matching every other model in the app: the server speaks UTC and
    // a worker reads their own clock.
    scheduledDate: scheduledDate.toLocal(),
    location: location,
    myWage: myWage,
    myWageUnit: myWageUnit,
    myStatus: myStatus,
    workStartedAt: workStartedAt?.toLocal(),
    needsMyAnswer: needsMyAnswer,
  );
}

@JsonSerializable(createToJson: false)
class WorkerPendingPaymentModel {
  const WorkerPendingPaymentModel({
    required this.applicationId,
    required this.title,
    required this.businessName,
    required this.amount,
    this.unit,
    this.paymentStatus = '',
    this.workCompletedAt,
  });

  factory WorkerPendingPaymentModel.fromJson(Map<String, dynamic> json) =>
      _$WorkerPendingPaymentModelFromJson(json);

  final String applicationId;
  final String title;
  final String businessName;
  final double amount;
  final String? unit;
  final String paymentStatus;
  final DateTime? workCompletedAt;

  WorkerPendingPayment toEntity() => WorkerPendingPayment(
    applicationId: applicationId,
    title: title,
    businessName: businessName,
    amount: amount,
    unit: unit,
    paymentStatus: paymentStatus,
    workCompletedAt: workCompletedAt?.toLocal(),
  );
}

@JsonSerializable(createToJson: false)
class WorkerMonthlyEarningModel {
  const WorkerMonthlyEarningModel({
    required this.label,
    required this.year,
    required this.month,
    this.jobsCompleted = 0,
    this.earned = 0,
  });

  factory WorkerMonthlyEarningModel.fromJson(Map<String, dynamic> json) =>
      _$WorkerMonthlyEarningModelFromJson(json);

  final String label;
  final int year;
  final int month;
  final int jobsCompleted;
  final double earned;

  WorkerMonthlyEarning toEntity() => WorkerMonthlyEarning(
    label: label,
    year: year,
    month: month,
    jobsCompleted: jobsCompleted,
    earned: earned,
  );
}
