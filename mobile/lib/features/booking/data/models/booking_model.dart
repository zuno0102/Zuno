import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/booking/data/models/booking_service_answer_model.dart';
import 'package:zuno/features/booking/data/models/booking_terms_proposal_model.dart';
import 'package:zuno/features/booking/data/models/booking_worker_assignment_model.dart';
import 'package:zuno/features/booking/data/models/rating_model.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';

part 'booking_model.g.dart';

@JsonSerializable(createToJson: false)
class BookingModel {
  const BookingModel({
    required this.id,
    this.reference = '',
    this.crewStatus = 'NotStaffed',
    this.activeCrewCount = 0,
    this.wageStatus = '',
    this.wagePayeeCount = 0,
    this.wagePaidPayeeCount = 0,
    this.wageTotalPayable = 0,
    this.wageOutstandingAmount = 0,
    this.workStartedAt,
    required this.businessOwnerProfileId,
    required this.businessName,
    required this.customerProfileId,
    required this.customerName,
    required this.businessServiceId,
    required this.serviceName,
    required this.serviceCategoryName,
    this.variantName,
    this.serviceSubCategoryId,
    this.serviceSubCategoryName,
    this.imageUrl,
    required this.status,
    required this.scheduledDate,
    required this.priceQuoted,
    this.priceType,
    this.serviceAnswers = const [],
    this.agreementStatus = 'NotRequired',
    this.proposals = const [],
    this.businessLogoUrl,
    this.businessPhone,
    this.customerPhone,
    this.requiredWorkerCount = 1,
    this.assignedWorkers = const [],
    this.myAssignmentStatus,
    this.myRole,
    this.myPaymentStatus,
    this.myWageAmount,
    this.notes,
    this.addressLine1,
    this.addressLine2,
    this.latitude,
    this.longitude,
    this.city,
    this.state,
    this.postalCode,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.rating,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) =>
      _$BookingModelFromJson(json);

  final String id;
  /// The short order code — "#7A3F91C2" — for people to quote and match.
  final String reference;

  /// Staffing progress, a separate track from [status]: NotStaffed, PartStaffed,
  /// FullyStaffed, Done.
  final String crewStatus;

  /// People on the job, counted by the server.
  final int activeCrewCount;
  final String wageStatus;
  final int wagePayeeCount;
  final int wagePaidPayeeCount;
  final double wageTotalPayable;
  final double wageOutstandingAmount;

  /// When the business marked the work under way.
  final DateTime? workStartedAt;
  final String businessOwnerProfileId;
  final String businessName;
  final String? businessLogoUrl;
  final String? businessPhone;
  final String customerProfileId;
  final String customerName;
  final String? customerPhone;
  final String businessServiceId;
  final String serviceName;
  final String serviceCategoryName;
  final String? variantName;

  /// The kind of work this order is for, from the package the customer chose.
  final String? serviceSubCategoryId;
  final String? serviceSubCategoryName;
  final String? imageUrl;
  final int requiredWorkerCount;
  final List<BookingWorkerAssignmentModel> assignedWorkers;
  final String? myAssignmentStatus;
  final String? myRole;

  /// The viewing worker's own wage state and amount. Null for every other viewer, and the
  /// amount is null on a mirror assignment that carries no wage.
  final String? myPaymentStatus;
  final double? myWageAmount;

  final String status;
  final DateTime scheduledDate;
  final String? notes;
  final double priceQuoted;
  final String? priceType;
  final List<BookingServiceAnswerModel> serviceAnswers;
  final String agreementStatus;
  final List<BookingTermsProposalModel> proposals;
  final String? addressLine1;
  final String? addressLine2;

  /// The pinned job location. Null on bookings made before pinning existed.
  final double? latitude;
  final double? longitude;
  final String? city;
  final String? state;
  final String? postalCode;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final RatingModel? rating;

  Booking toEntity() => Booking(
    id: id,
    reference: reference,
    crewStatus: crewStatus,
    activeCrewCount: activeCrewCount,
    wageStatus: wageStatus,
    wagePayeeCount: wagePayeeCount,
    wagePaidPayeeCount: wagePaidPayeeCount,
    wageTotalPayable: wageTotalPayable,
    wageOutstandingAmount: wageOutstandingAmount,
    workStartedAt: workStartedAt?.toLocal(),
    businessOwnerProfileId: businessOwnerProfileId,
    businessName: businessName,
    businessLogoUrl: businessLogoUrl,
    businessPhone: businessPhone,
    customerProfileId: customerProfileId,
    customerName: customerName,
    customerPhone: customerPhone,
    businessServiceId: businessServiceId,
    serviceName: serviceName,
    serviceCategoryName: serviceCategoryName,
    variantName: variantName,
    serviceSubCategoryId: serviceSubCategoryId,
    serviceSubCategoryName: serviceSubCategoryName,
    imageUrl: imageUrl,
    requiredWorkerCount: requiredWorkerCount,
    assignedWorkers: assignedWorkers.map((a) => a.toEntity()).toList(),
    myAssignmentStatus: myAssignmentStatus,
    myRole: myRole,
    myPaymentStatus: myPaymentStatus,
    myWageAmount: myWageAmount,
    status: status,
    scheduledDate: scheduledDate,
    notes: notes,
    priceQuoted: priceQuoted,
    priceType: priceType,
    serviceAnswers: serviceAnswers.map((a) => a.toEntity()).toList(),
    agreementStatus: agreementStatus,
    proposals: proposals.map((p) => p.toEntity()).toList(),
    addressLine1: addressLine1,
    addressLine2: addressLine2,
    latitude: latitude,
    longitude: longitude,
    city: city,
    state: state,
    postalCode: postalCode,
    completedAt: completedAt,
    cancelledAt: cancelledAt,
    cancellationReason: cancellationReason,
    rating: rating?.toEntity(),
  );
}
