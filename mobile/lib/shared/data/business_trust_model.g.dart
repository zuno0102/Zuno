// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_trust_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BusinessTrustModel _$BusinessTrustModelFromJson(Map<String, dynamic> json) =>
    BusinessTrustModel(
      customers: CustomerFacingTrustModel.fromJson(
        json['customers'] as Map<String, dynamic>,
      ),
      workers: WorkerFacingTrustModel.fromJson(
        json['workers'] as Map<String, dynamic>,
      ),
    );

CustomerFacingTrustModel _$CustomerFacingTrustModelFromJson(
  Map<String, dynamic> json,
) => CustomerFacingTrustModel(
  eventsCompleted: (json['eventsCompleted'] as num?)?.toInt() ?? 0,
  ratingAverage: (json['ratingAverage'] as num?)?.toDouble(),
  reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
  repeatCustomers: (json['repeatCustomers'] as num?)?.toInt() ?? 0,
);

WorkerFacingTrustModel _$WorkerFacingTrustModelFromJson(
  Map<String, dynamic> json,
) => WorkerFacingTrustModel(
  averageSalary: (json['averageSalary'] as num?)?.toDouble(),
  lowestSalary: (json['lowestSalary'] as num?)?.toDouble(),
  highestSalary: (json['highestSalary'] as num?)?.toDouble(),
  salaryUnit: json['salaryUnit'] as String?,
  totalHires: (json['totalHires'] as num?)?.toInt() ?? 0,
  paidPostedRateCount: (json['paidPostedRateCount'] as num?)?.toInt() ?? 0,
  raisedPayCount: (json['raisedPayCount'] as num?)?.toInt() ?? 0,
  crewsPaid: (json['crewsPaid'] as num?)?.toInt() ?? 0,
  crewsAwaitingPayment: (json['crewsAwaitingPayment'] as num?)?.toInt() ?? 0,
  typicalHoursToPay: (json['typicalHoursToPay'] as num?)?.toDouble(),
  distinctWorkers: (json['distinctWorkers'] as num?)?.toInt() ?? 0,
  repeatHires: (json['repeatHires'] as num?)?.toInt() ?? 0,
  openDisputes: (json['openDisputes'] as num?)?.toInt() ?? 0,
  overdueWages: (json['overdueWages'] as num?)?.toDouble() ?? 0,
);
