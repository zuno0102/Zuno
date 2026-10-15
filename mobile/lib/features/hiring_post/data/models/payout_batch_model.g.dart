// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payout_batch_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PayoutBatchItemModel _$PayoutBatchItemModelFromJson(
  Map<String, dynamic> json,
) => PayoutBatchItemModel(
  id: json['id'] as String,
  workerName: json['workerName'] as String,
  amount: (json['amount'] as num).toDouble(),
  paymentStatus: json['paymentStatus'] as String,
  destination: json['destination'] as String?,
  failureReason: json['failureReason'] as String?,
  paidAt: json['paidAt'] == null
      ? null
      : DateTime.parse(json['paidAt'] as String),
);

PayoutBatchModel _$PayoutBatchModelFromJson(Map<String, dynamic> json) =>
    PayoutBatchModel(
      id: json['id'] as String,
      hiringPostId: json['hiringPostId'] as String,
      totalAmount: (json['totalAmount'] as num).toDouble(),
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0,
      batchStatus: json['batchStatus'] as String,
      providerOrderId: json['providerOrderId'] as String?,
      providerPaymentId: json['providerPaymentId'] as String?,
      razorpayKeyId: json['razorpayKeyId'] as String?,
      nothingToCollect: json['nothingToCollect'] as bool? ?? false,
      fundedAt: json['fundedAt'] == null
          ? null
          : DateTime.parse(json['fundedAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      items:
          (json['items'] as List<dynamic>?)
              ?.map(
                (e) => PayoutBatchItemModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      isReconciled: json['isReconciled'] as bool? ?? true,
    );
