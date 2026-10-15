// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_dashboard_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BusinessDashboardModel _$BusinessDashboardModelFromJson(
  Map<String, dynamic> json,
) => BusinessDashboardModel(
  eventsCompleted: (json['eventsCompleted'] as num?)?.toInt() ?? 0,
  upcomingEvents: (json['upcomingEvents'] as num?)?.toInt() ?? 0,
  cancelledEvents: (json['cancelledEvents'] as num?)?.toInt() ?? 0,
  totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0,
  crewEventsCompleted: (json['crewEventsCompleted'] as num?)?.toInt() ?? 0,
  activeWorkers: (json['activeWorkers'] as num?)?.toInt() ?? 0,
  byCategory:
      (json['byCategory'] as List<dynamic>?)
          ?.map(
            (e) => CategoryBreakdownModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  trend:
      (json['trend'] as List<dynamic>?)
          ?.map((e) => MonthlyActivityModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  completed:
      (json['completed'] as List<dynamic>?)
          ?.map((e) => DashboardEventModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  upcoming:
      (json['upcoming'] as List<dynamic>?)
          ?.map((e) => DashboardEventModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  cancelled:
      (json['cancelled'] as List<dynamic>?)
          ?.map((e) => DashboardEventModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  crewEvents:
      (json['crewEvents'] as List<dynamic>?)
          ?.map((e) => CrewEventModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  workers:
      (json['workers'] as List<dynamic>?)
          ?.map((e) => DashboardWorkerModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  trust: json['trust'] == null
      ? null
      : BusinessTrustModel.fromJson(json['trust'] as Map<String, dynamic>),
);

DashboardWorkerModel _$DashboardWorkerModelFromJson(
  Map<String, dynamic> json,
) => DashboardWorkerModel(
  workerProfileId: json['workerProfileId'] as String,
  workerName: json['workerName'] as String,
  availabilityStatus: json['availabilityStatus'] as String,
  sinceDate: DateTime.parse(json['sinceDate'] as String),
  workerPhone: json['workerPhone'] as String?,
  jobsCompleted: (json['jobsCompleted'] as num?)?.toInt() ?? 0,
  busyOn: json['busyOn'] == null
      ? null
      : DateTime.parse(json['busyOn'] as String),
);

CategoryBreakdownModel _$CategoryBreakdownModelFromJson(
  Map<String, dynamic> json,
) => CategoryBreakdownModel(
  serviceCategoryId: json['serviceCategoryId'] as String,
  categoryName: json['categoryName'] as String,
  count: (json['count'] as num).toInt(),
  revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
  subCategories:
      (json['subCategories'] as List<dynamic>?)
          ?.map(
            (e) =>
                SubCategoryBreakdownModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);

SubCategoryBreakdownModel _$SubCategoryBreakdownModelFromJson(
  Map<String, dynamic> json,
) => SubCategoryBreakdownModel(
  name: json['name'] as String,
  count: (json['count'] as num).toInt(),
  revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
);

MonthlyActivityModel _$MonthlyActivityModelFromJson(
  Map<String, dynamic> json,
) => MonthlyActivityModel(
  label: json['label'] as String,
  year: (json['year'] as num).toInt(),
  month: (json['month'] as num).toInt(),
  completed: (json['completed'] as num?)?.toInt() ?? 0,
  revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
);

DashboardEventModel _$DashboardEventModelFromJson(Map<String, dynamic> json) =>
    DashboardEventModel(
      id: json['id'] as String,
      serviceName: json['serviceName'] as String,
      categoryName: json['categoryName'] as String,
      customerName: json['customerName'] as String,
      scheduledDate: DateTime.parse(json['scheduledDate'] as String),
      status: json['status'] as String,
      subCategoryName: json['subCategoryName'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      requiredWorkerCount: (json['requiredWorkerCount'] as num?)?.toInt() ?? 1,
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      cancelledAt: json['cancelledAt'] == null
          ? null
          : DateTime.parse(json['cancelledAt'] as String),
      cancellationReason: json['cancellationReason'] as String?,
      city: json['city'] as String?,
    );

CrewEventModel _$CrewEventModelFromJson(Map<String, dynamic> json) =>
    CrewEventModel(
      id: json['id'] as String,
      title: json['title'] as String,
      eventDate: DateTime.parse(json['eventDate'] as String),
      location: json['location'] as String?,
      workersNeeded: (json['workersNeeded'] as num?)?.toInt() ?? 1,
      workersHired: (json['workersHired'] as num?)?.toInt() ?? 0,
      workCompletedAt: json['workCompletedAt'] == null
          ? null
          : DateTime.parse(json['workCompletedAt'] as String),
      isFullySettled: json['isFullySettled'] as bool? ?? false,
      totalWages: (json['totalWages'] as num?)?.toDouble() ?? 0,
      outstandingWages: (json['outstandingWages'] as num?)?.toDouble() ?? 0,
    );
