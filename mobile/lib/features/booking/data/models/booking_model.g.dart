// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BookingModel _$BookingModelFromJson(Map<String, dynamic> json) => BookingModel(
  id: json['id'] as String,
  reference: json['reference'] as String? ?? '',
  crewStatus: json['crewStatus'] as String? ?? 'NotStaffed',
  activeCrewCount: (json['activeCrewCount'] as num?)?.toInt() ?? 0,
  wageStatus: json['wageStatus'] as String? ?? '',
  wagePayeeCount: (json['wagePayeeCount'] as num?)?.toInt() ?? 0,
  wagePaidPayeeCount: (json['wagePaidPayeeCount'] as num?)?.toInt() ?? 0,
  wageTotalPayable: (json['wageTotalPayable'] as num?)?.toDouble() ?? 0,
  wageOutstandingAmount:
      (json['wageOutstandingAmount'] as num?)?.toDouble() ?? 0,
  workStartedAt: json['workStartedAt'] == null
      ? null
      : DateTime.parse(json['workStartedAt'] as String),
  businessOwnerProfileId: json['businessOwnerProfileId'] as String,
  businessName: json['businessName'] as String,
  customerProfileId: json['customerProfileId'] as String,
  customerName: json['customerName'] as String,
  businessServiceId: json['businessServiceId'] as String,
  serviceName: json['serviceName'] as String,
  serviceCategoryName: json['serviceCategoryName'] as String,
  variantName: json['variantName'] as String?,
  serviceSubCategoryId: json['serviceSubCategoryId'] as String?,
  serviceSubCategoryName: json['serviceSubCategoryName'] as String?,
  imageUrl: json['imageUrl'] as String?,
  status: json['status'] as String,
  scheduledDate: DateTime.parse(json['scheduledDate'] as String),
  priceQuoted: (json['priceQuoted'] as num).toDouble(),
  priceType: json['priceType'] as String?,
  serviceAnswers:
      (json['serviceAnswers'] as List<dynamic>?)
          ?.map(
            (e) =>
                BookingServiceAnswerModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  agreementStatus: json['agreementStatus'] as String? ?? 'NotRequired',
  proposals:
      (json['proposals'] as List<dynamic>?)
          ?.map(
            (e) =>
                BookingTermsProposalModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  businessLogoUrl: json['businessLogoUrl'] as String?,
  businessPhone: json['businessPhone'] as String?,
  customerPhone: json['customerPhone'] as String?,
  requiredWorkerCount: (json['requiredWorkerCount'] as num?)?.toInt() ?? 1,
  assignedWorkers:
      (json['assignedWorkers'] as List<dynamic>?)
          ?.map(
            (e) => BookingWorkerAssignmentModel.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList() ??
      const [],
  myAssignmentStatus: json['myAssignmentStatus'] as String?,
  myRole: json['myRole'] as String?,
  myPaymentStatus: json['myPaymentStatus'] as String?,
  myWageAmount: (json['myWageAmount'] as num?)?.toDouble(),
  notes: json['notes'] as String?,
  addressLine1: json['addressLine1'] as String?,
  city: json['city'] as String?,
  state: json['state'] as String?,
  postalCode: json['postalCode'] as String?,
  completedAt: json['completedAt'] == null
      ? null
      : DateTime.parse(json['completedAt'] as String),
  cancelledAt: json['cancelledAt'] == null
      ? null
      : DateTime.parse(json['cancelledAt'] as String),
  cancellationReason: json['cancellationReason'] as String?,
  rating: json['rating'] == null
      ? null
      : RatingModel.fromJson(json['rating'] as Map<String, dynamic>),
);
