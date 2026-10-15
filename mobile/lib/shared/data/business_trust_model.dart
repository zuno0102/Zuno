import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/shared/domain/business_trust.dart';

part 'business_trust_model.g.dart';

@JsonSerializable(createToJson: false)
class BusinessTrustModel {
  const BusinessTrustModel({required this.customers, required this.workers});

  factory BusinessTrustModel.fromJson(Map<String, dynamic> json) =>
      _$BusinessTrustModelFromJson(json);

  final CustomerFacingTrustModel customers;
  final WorkerFacingTrustModel workers;

  BusinessTrust toEntity() =>
      BusinessTrust(customers: customers.toEntity(), workers: workers.toEntity());
}

@JsonSerializable(createToJson: false)
class CustomerFacingTrustModel {
  const CustomerFacingTrustModel({
    this.eventsCompleted = 0,
    this.ratingAverage,
    this.reviewCount = 0,
    this.repeatCustomers = 0,
  });

  factory CustomerFacingTrustModel.fromJson(Map<String, dynamic> json) =>
      _$CustomerFacingTrustModelFromJson(json);

  final int eventsCompleted;
  final double? ratingAverage;
  final int reviewCount;
  final int repeatCustomers;

  CustomerFacingTrust toEntity() => CustomerFacingTrust(
    eventsCompleted: eventsCompleted,
    ratingAverage: ratingAverage,
    reviewCount: reviewCount,
    repeatCustomers: repeatCustomers,
  );
}

@JsonSerializable(createToJson: false)
class WorkerFacingTrustModel {
  const WorkerFacingTrustModel({
    this.averageSalary,
    this.lowestSalary,
    this.highestSalary,
    this.salaryUnit,
    this.totalHires = 0,
    this.paidPostedRateCount = 0,
    this.raisedPayCount = 0,
    this.crewsPaid = 0,
    this.crewsAwaitingPayment = 0,
    this.typicalHoursToPay,
    this.distinctWorkers = 0,
    this.repeatHires = 0,
    this.openDisputes = 0,
    this.overdueWages = 0,
  });

  factory WorkerFacingTrustModel.fromJson(Map<String, dynamic> json) =>
      _$WorkerFacingTrustModelFromJson(json);

  final double? averageSalary;
  final double? lowestSalary;
  final double? highestSalary;
  final String? salaryUnit;
  final int totalHires;
  final int paidPostedRateCount;
  final int raisedPayCount;
  final int crewsPaid;
  final int crewsAwaitingPayment;
  final double? typicalHoursToPay;
  final int distinctWorkers;
  final int repeatHires;
  final int openDisputes;
  final double overdueWages;

  WorkerFacingTrust toEntity() => WorkerFacingTrust(
    averageSalary: averageSalary,
    lowestSalary: lowestSalary,
    highestSalary: highestSalary,
    salaryUnit: salaryUnit,
    totalHires: totalHires,
    paidPostedRateCount: paidPostedRateCount,
    raisedPayCount: raisedPayCount,
    crewsPaid: crewsPaid,
    crewsAwaitingPayment: crewsAwaitingPayment,
    typicalHoursToPay: typicalHoursToPay,
    distinctWorkers: distinctWorkers,
    repeatHires: repeatHires,
    openDisputes: openDisputes,
    overdueWages: overdueWages,
  );
}
