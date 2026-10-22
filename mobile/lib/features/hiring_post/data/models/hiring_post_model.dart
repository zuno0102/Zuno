import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/hiring_post/data/models/hiring_post_application_model.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';

part 'hiring_post_model.g.dart';

@JsonSerializable(createToJson: false)
class HiringPostModel {
  const HiringPostModel({
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
    this.stage = '',
    required this.createdDate,
    this.myApplicationStatus,
    this.myApplicationId,
    this.myAgreedSalaryAmount,
    this.myPaymentStatus,
    this.myPaidAt,
    this.myDisputeReason,
    this.applications = const [],
  });

  factory HiringPostModel.fromJson(Map<String, dynamic> json) =>
      _$HiringPostModelFromJson(json);

  final String id;
  final String businessOwnerProfileId;

  /// The customer order this crew was hired for, when the post came from one.
  final String? bookingId;

  /// "Catering · 28 Sep" — what the hire is for, named by the server.
  final String? bookingReference;

  /// Where that order stands. Null when the post answers to no order.
  final String? bookingStatus;
  final String businessName;
  final String? businessLogoUrl;
  final String? businessPhone;
  final String title;
  final String? description;
  final String? imageUrl;
  final DateTime eventDate;
  final int durationMinutes;
  final DateTime? workStartedAt;
  final DateTime? workCompletedAt;
  final DateTime? hiringStoppedAt;
  final DateTime? settledAt;
  final double totalPayable;
  final double outstandingAmount;
  final int payeeCount;
  final int paidPayeeCount;
  final bool hasDisputedPayment;
  final bool isFullyComplete;

  /// The kind of work, inside the category — "Interior wall painting".
  final String? serviceSubCategoryId;
  final String? serviceSubCategoryName;
  final String? location;
  final String? districtName;
  final double? latitude;
  final double? longitude;
  final String locationPrecision;
  final double? distanceKm;
  final int workersNeeded;
  final double salaryAmount;
  final String salaryUnit;
  final int confirmedCount;
  final int pendingOfferCount;
  final int filledCount;
  final String status;
  final String stage;
  final DateTime createdDate;
  final String? myApplicationStatus;
  final String? myApplicationId;
  final double? myAgreedSalaryAmount;
  final String? myPaymentStatus;
  final DateTime? myPaidAt;
  final String? myDisputeReason;
  final List<HiringPostApplicationModel> applications;

  HiringPost toEntity() => HiringPost(
    id: id,
    businessOwnerProfileId: businessOwnerProfileId,
    bookingId: bookingId,
    bookingReference: bookingReference,
    bookingStatus: bookingStatus,
    businessName: businessName,
    businessLogoUrl: businessLogoUrl,
    businessPhone: businessPhone,
    title: title,
    description: description,
    imageUrl: imageUrl,
    eventDate: eventDate,
    durationMinutes: durationMinutes,
    workStartedAt: workStartedAt,
    workCompletedAt: workCompletedAt,
    hiringStoppedAt: hiringStoppedAt,
    settledAt: settledAt,
    totalPayable: totalPayable,
    outstandingAmount: outstandingAmount,
    payeeCount: payeeCount,
    paidPayeeCount: paidPayeeCount,
    hasDisputedPayment: hasDisputedPayment,
    isFullyComplete: isFullyComplete,
    serviceSubCategoryId: serviceSubCategoryId,
    serviceSubCategoryName: serviceSubCategoryName,
    location: location,
    districtName: districtName,
    latitude: latitude,
    longitude: longitude,
    locationPrecision: locationPrecision,
    distanceKm: distanceKm,
    workersNeeded: workersNeeded,
    salaryAmount: salaryAmount,
    salaryUnit: salaryUnit,
    confirmedCount: confirmedCount,
    pendingOfferCount: pendingOfferCount,
    filledCount: filledCount,
    status: status,
    stage: stage,
    createdDate: createdDate,
    myApplicationStatus: myApplicationStatus,
    myApplicationId: myApplicationId,
    myAgreedSalaryAmount: myAgreedSalaryAmount,
    myPaymentStatus: myPaymentStatus,
    myPaidAt: myPaidAt,
    myDisputeReason: myDisputeReason,
    applications: applications.map((a) => a.toEntity()).toList(),
  );
}
