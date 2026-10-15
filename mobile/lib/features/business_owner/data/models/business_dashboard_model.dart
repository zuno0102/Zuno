import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/business_owner/domain/entities/business_dashboard.dart';
import 'package:zuno/shared/data/business_trust_model.dart';
import 'package:zuno/shared/domain/business_trust.dart';

part 'business_dashboard_model.g.dart';

@JsonSerializable(createToJson: false)
class BusinessDashboardModel {
  const BusinessDashboardModel({
    this.eventsCompleted = 0,
    this.upcomingEvents = 0,
    this.cancelledEvents = 0,
    this.totalRevenue = 0,
    this.crewEventsCompleted = 0,
    this.activeWorkers = 0,
    this.byCategory = const [],
    this.trend = const [],
    this.completed = const [],
    this.upcoming = const [],
    this.cancelled = const [],
    this.crewEvents = const [],
    this.workers = const [],
    this.trust,
  });

  factory BusinessDashboardModel.fromJson(Map<String, dynamic> json) =>
      _$BusinessDashboardModelFromJson(json);

  final int eventsCompleted;
  final int upcomingEvents;
  final int cancelledEvents;
  final double totalRevenue;
  final int crewEventsCompleted;
  final int activeWorkers;
  final List<CategoryBreakdownModel> byCategory;
  final List<MonthlyActivityModel> trend;
  final List<DashboardEventModel> completed;
  final List<DashboardEventModel> upcoming;
  final List<DashboardEventModel> cancelled;
  final List<CrewEventModel> crewEvents;
  final List<DashboardWorkerModel> workers;
  final BusinessTrustModel? trust;

  BusinessDashboard toEntity() => BusinessDashboard(
    eventsCompleted: eventsCompleted,
    upcomingEvents: upcomingEvents,
    cancelledEvents: cancelledEvents,
    totalRevenue: totalRevenue,
    crewEventsCompleted: crewEventsCompleted,
    activeWorkers: activeWorkers,
    byCategory: byCategory.map((c) => c.toEntity()).toList(),
    trend: trend.map((m) => m.toEntity()).toList(),
    completed: completed.map((e) => e.toEntity()).toList(),
    upcoming: upcoming.map((e) => e.toEntity()).toList(),
    cancelled: cancelled.map((e) => e.toEntity()).toList(),
    crewEvents: crewEvents.map((e) => e.toEntity()).toList(),
    workers: workers.map((w) => w.toEntity()).toList(),
    trust: trust?.toEntity() ?? const BusinessTrust(),
  );
}

@JsonSerializable(createToJson: false)
class DashboardWorkerModel {
  const DashboardWorkerModel({
    required this.workerProfileId,
    required this.workerName,
    required this.availabilityStatus,
    required this.sinceDate,
    this.workerPhone,
    this.jobsCompleted = 0,
    this.busyOn,
  });

  factory DashboardWorkerModel.fromJson(Map<String, dynamic> json) =>
      _$DashboardWorkerModelFromJson(json);

  final String workerProfileId;
  final String workerName;
  final String? workerPhone;
  final String availabilityStatus;
  final int jobsCompleted;
  final DateTime sinceDate;
  final DateTime? busyOn;

  DashboardWorker toEntity() => DashboardWorker(
    workerProfileId: workerProfileId,
    workerName: workerName,
    workerPhone: workerPhone,
    availabilityStatus: availabilityStatus,
    jobsCompleted: jobsCompleted,
    sinceDate: sinceDate.toLocal(),
    busyOn: busyOn?.toLocal(),
  );
}

@JsonSerializable(createToJson: false)
class CategoryBreakdownModel {
  const CategoryBreakdownModel({
    required this.serviceCategoryId,
    required this.categoryName,
    required this.count,
    this.revenue = 0,
    this.subCategories = const [],
  });

  factory CategoryBreakdownModel.fromJson(Map<String, dynamic> json) =>
      _$CategoryBreakdownModelFromJson(json);

  final String serviceCategoryId;
  final String categoryName;
  final int count;
  final double revenue;
  final List<SubCategoryBreakdownModel> subCategories;

  CategoryBreakdown toEntity() => CategoryBreakdown(
    serviceCategoryId: serviceCategoryId,
    categoryName: categoryName,
    count: count,
    revenue: revenue,
    subCategories: subCategories.map((s) => s.toEntity()).toList(),
  );
}

@JsonSerializable(createToJson: false)
class SubCategoryBreakdownModel {
  const SubCategoryBreakdownModel({
    required this.name,
    required this.count,
    this.revenue = 0,
  });

  factory SubCategoryBreakdownModel.fromJson(Map<String, dynamic> json) =>
      _$SubCategoryBreakdownModelFromJson(json);

  final String name;
  final int count;
  final double revenue;

  SubCategoryBreakdown toEntity() =>
      SubCategoryBreakdown(name: name, count: count, revenue: revenue);
}

@JsonSerializable(createToJson: false)
class MonthlyActivityModel {
  const MonthlyActivityModel({
    required this.label,
    required this.year,
    required this.month,
    this.completed = 0,
    this.revenue = 0,
  });

  factory MonthlyActivityModel.fromJson(Map<String, dynamic> json) =>
      _$MonthlyActivityModelFromJson(json);

  final String label;
  final int year;
  final int month;
  final int completed;
  final double revenue;

  MonthlyActivity toEntity() => MonthlyActivity(
    label: label,
    year: year,
    month: month,
    completed: completed,
    revenue: revenue,
  );
}

@JsonSerializable(createToJson: false)
class DashboardEventModel {
  const DashboardEventModel({
    required this.id,
    required this.serviceName,
    required this.categoryName,
    required this.customerName,
    required this.scheduledDate,
    required this.status,
    this.subCategoryName,
    this.price = 0,
    this.requiredWorkerCount = 1,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.city,
  });

  factory DashboardEventModel.fromJson(Map<String, dynamic> json) =>
      _$DashboardEventModelFromJson(json);

  final String id;
  final String serviceName;
  final String categoryName;
  final String? subCategoryName;
  final String customerName;
  final DateTime scheduledDate;
  final double price;
  final int requiredWorkerCount;
  final String status;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final String? city;

  DashboardEvent toEntity() => DashboardEvent(
    id: id,
    serviceName: serviceName,
    categoryName: categoryName,
    subCategoryName: subCategoryName,
    customerName: customerName,
    scheduledDate: scheduledDate.toLocal(),
    price: price,
    requiredWorkerCount: requiredWorkerCount,
    status: status,
    completedAt: completedAt?.toLocal(),
    cancelledAt: cancelledAt?.toLocal(),
    cancellationReason: cancellationReason,
    city: city,
  );
}

@JsonSerializable(createToJson: false)
class CrewEventModel {
  const CrewEventModel({
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

  factory CrewEventModel.fromJson(Map<String, dynamic> json) =>
      _$CrewEventModelFromJson(json);

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

  CrewEvent toEntity() => CrewEvent(
    id: id,
    title: title,
    eventDate: eventDate.toLocal(),
    location: location,
    workersNeeded: workersNeeded,
    workersHired: workersHired,
    workCompletedAt: workCompletedAt?.toLocal(),
    isFullySettled: isFullySettled,
    totalWages: totalWages,
    outstandingWages: outstandingWages,
  );
}
