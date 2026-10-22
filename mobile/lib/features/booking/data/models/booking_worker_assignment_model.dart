import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/booking/domain/entities/booking_worker_assignment.dart';

part 'booking_worker_assignment_model.g.dart';

@JsonSerializable(createToJson: false)
class BookingWorkerAssignmentModel {
  const BookingWorkerAssignmentModel({
    required this.workerProfileId,
    required this.workerName,
    this.workerPhone,
    this.role,
    required this.status,
    this.displayStatus = '',
    this.agreedSalaryAmount,
    this.agreedSalaryUnit,
    this.originalSalaryAmount,
    this.paymentStatus = '',
    this.hasPayoutDetails = false,
  });

  factory BookingWorkerAssignmentModel.fromJson(Map<String, dynamic> json) =>
      _$BookingWorkerAssignmentModelFromJson(json);

  final String workerProfileId;
  final String workerName;
  final String? workerPhone;
  final String? role;
  final String status;
  final String displayStatus;
  final double? agreedSalaryAmount;
  final String? agreedSalaryUnit;
  final double? originalSalaryAmount;
  final String paymentStatus;
  final bool hasPayoutDetails;

  BookingWorkerAssignment toEntity() => BookingWorkerAssignment(
    workerProfileId: workerProfileId,
    workerName: workerName,
    workerPhone: workerPhone,
    role: role,
    status: status,
    displayStatus: displayStatus,
    agreedSalaryAmount: agreedSalaryAmount,
    agreedSalaryUnit: agreedSalaryUnit,
    originalSalaryAmount: originalSalaryAmount,
    paymentStatus: paymentStatus,
    hasPayoutDetails: hasPayoutDetails,
  );
}
