// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worker_dashboard_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WorkerDashboardModel _$WorkerDashboardModelFromJson(
  Map<String, dynamic> json,
) => WorkerDashboardModel(
  profile: json['profile'] == null
      ? null
      : WorkerProfileModel.fromJson(json['profile'] as Map<String, dynamic>),
  inProgressCount: (json['inProgressCount'] as num?)?.toInt() ?? 0,
  upcomingCount: (json['upcomingCount'] as num?)?.toInt() ?? 0,
  openHiringPostCount: (json['openHiringPostCount'] as num?)?.toInt() ?? 0,
  inProgress:
      (json['inProgress'] as List<dynamic>?)
          ?.map(
            (e) => WorkerJobSummaryModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  upcoming:
      (json['upcoming'] as List<dynamic>?)
          ?.map(
            (e) => WorkerJobSummaryModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  completed:
      (json['completed'] as List<dynamic>?)
          ?.map(
            (e) => WorkerJobSummaryModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  pendingPayments:
      (json['pendingPayments'] as List<dynamic>?)
          ?.map(
            (e) =>
                WorkerPendingPaymentModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  pendingPaymentTotal: (json['pendingPaymentTotal'] as num?)?.toDouble() ?? 0,
  trend:
      (json['trend'] as List<dynamic>?)
          ?.map(
            (e) =>
                WorkerMonthlyEarningModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);

WorkerJobSummaryModel _$WorkerJobSummaryModelFromJson(
  Map<String, dynamic> json,
) => WorkerJobSummaryModel(
  id: json['id'] as String,
  source: json['source'] as String,
  title: json['title'] as String,
  businessName: json['businessName'] as String,
  scheduledDate: DateTime.parse(json['scheduledDate'] as String),
  location: json['location'] as String?,
  myWage: (json['myWage'] as num?)?.toDouble(),
  myWageUnit: json['myWageUnit'] as String?,
  myStatus: json['myStatus'] as String? ?? '',
  workStartedAt: json['workStartedAt'] == null
      ? null
      : DateTime.parse(json['workStartedAt'] as String),
  needsMyAnswer: json['needsMyAnswer'] as bool? ?? false,
);

WorkerPendingPaymentModel _$WorkerPendingPaymentModelFromJson(
  Map<String, dynamic> json,
) => WorkerPendingPaymentModel(
  applicationId: json['applicationId'] as String,
  title: json['title'] as String,
  businessName: json['businessName'] as String,
  amount: (json['amount'] as num).toDouble(),
  unit: json['unit'] as String?,
  paymentStatus: json['paymentStatus'] as String? ?? '',
  workCompletedAt: json['workCompletedAt'] == null
      ? null
      : DateTime.parse(json['workCompletedAt'] as String),
);

WorkerMonthlyEarningModel _$WorkerMonthlyEarningModelFromJson(
  Map<String, dynamic> json,
) => WorkerMonthlyEarningModel(
  label: json['label'] as String,
  year: (json['year'] as num).toInt(),
  month: (json['month'] as num).toInt(),
  jobsCompleted: (json['jobsCompleted'] as num?)?.toInt() ?? 0,
  earned: (json['earned'] as num?)?.toDouble() ?? 0,
);
