// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_terms_proposal_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BookingTermsProposalModel _$BookingTermsProposalModelFromJson(
  Map<String, dynamic> json,
) => BookingTermsProposalModel(
  id: json['id'] as String,
  proposedByRole: json['proposedByRole'] as String,
  workerCount: (json['workerCount'] as num).toInt(),
  price: (json['price'] as num).toDouble(),
  proposalStatus: json['proposalStatus'] as String,
  createdDate: DateTime.parse(json['createdDate'] as String),
  message: json['message'] as String?,
  respondedAt: json['respondedAt'] == null
      ? null
      : DateTime.parse(json['respondedAt'] as String),
);
