// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hiring_post_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HiringPostModel _$HiringPostModelFromJson(Map<String, dynamic> json) =>
    HiringPostModel(
      id: json['id'] as String,
      businessOwnerProfileId: json['businessOwnerProfileId'] as String,
      bookingId: json['bookingId'] as String?,
      bookingReference: json['bookingReference'] as String?,
      bookingStatus: json['bookingStatus'] as String?,
      businessName: json['businessName'] as String,
      businessLogoUrl: json['businessLogoUrl'] as String?,
      businessPhone: json['businessPhone'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      eventDate: DateTime.parse(json['eventDate'] as String),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 120,
      workStartedAt: json['workStartedAt'] == null
          ? null
          : DateTime.parse(json['workStartedAt'] as String),
      workCompletedAt: json['workCompletedAt'] == null
          ? null
          : DateTime.parse(json['workCompletedAt'] as String),
      settledAt: json['settledAt'] == null
          ? null
          : DateTime.parse(json['settledAt'] as String),
      totalPayable: (json['totalPayable'] as num?)?.toDouble() ?? 0,
      outstandingAmount: (json['outstandingAmount'] as num?)?.toDouble() ?? 0,
      payeeCount: (json['payeeCount'] as num?)?.toInt() ?? 0,
      paidPayeeCount: (json['paidPayeeCount'] as num?)?.toInt() ?? 0,
      hasDisputedPayment: json['hasDisputedPayment'] as bool? ?? false,
      isFullyComplete: json['isFullyComplete'] as bool? ?? false,
      serviceSubCategoryId: json['serviceSubCategoryId'] as String?,
      serviceSubCategoryName: json['serviceSubCategoryName'] as String?,
      location: json['location'] as String?,
      districtName: json['districtName'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationPrecision: json['locationPrecision'] as String? ?? 'None',
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      workersNeeded: (json['workersNeeded'] as num).toInt(),
      salaryAmount: (json['salaryAmount'] as num).toDouble(),
      salaryUnit: json['salaryUnit'] as String? ?? 'PerEvent',
      confirmedCount: (json['confirmedCount'] as num).toInt(),
      pendingOfferCount: (json['pendingOfferCount'] as num?)?.toInt() ?? 0,
      filledCount: (json['filledCount'] as num?)?.toInt() ?? 0,
      status: json['status'] as String,
      createdDate: DateTime.parse(json['createdDate'] as String),
      myApplicationStatus: json['myApplicationStatus'] as String?,
      myApplicationId: json['myApplicationId'] as String?,
      myAgreedSalaryAmount: (json['myAgreedSalaryAmount'] as num?)?.toDouble(),
      myPaymentStatus: json['myPaymentStatus'] as String?,
      myPaidAt: json['myPaidAt'] == null
          ? null
          : DateTime.parse(json['myPaidAt'] as String),
      myDisputeReason: json['myDisputeReason'] as String?,
      applications:
          (json['applications'] as List<dynamic>?)
              ?.map(
                (e) => HiringPostApplicationModel.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          const [],
    );
