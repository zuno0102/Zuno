import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/booking/domain/entities/booking_terms_proposal.dart';

part 'booking_terms_proposal_model.g.dart';

@JsonSerializable(createToJson: false)
class BookingTermsProposalModel {
  const BookingTermsProposalModel({
    required this.id,
    required this.proposedByRole,
    required this.workerCount,
    required this.price,
    required this.proposalStatus,
    required this.createdDate,
    this.message,
    this.respondedAt,
  });

  factory BookingTermsProposalModel.fromJson(Map<String, dynamic> json) =>
      _$BookingTermsProposalModelFromJson(json);

  final String id;
  final String proposedByRole;
  final int workerCount;
  final double price;
  final String? message;
  final String proposalStatus;
  final DateTime createdDate;
  final DateTime? respondedAt;

  BookingTermsProposal toEntity() => BookingTermsProposal(
    id: id,
    proposedByRole: proposedByRole,
    workerCount: workerCount,
    price: price,
    message: message,
    proposalStatus: proposalStatus,
    createdDate: createdDate,
    respondedAt: respondedAt,
  );
}
