import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/hiring_post/domain/entities/payout_batch.dart';

part 'payout_batch_model.g.dart';

@JsonSerializable(createToJson: false)
class PayoutBatchItemModel {
  const PayoutBatchItemModel({
    required this.id,
    required this.workerName,
    required this.amount,
    required this.paymentStatus,
    this.destination,
    this.failureReason,
    this.paidAt,
  });

  factory PayoutBatchItemModel.fromJson(Map<String, dynamic> json) =>
      _$PayoutBatchItemModelFromJson(json);

  final String id;
  final String workerName;
  final double amount;
  final String paymentStatus;
  final String? destination;
  final String? failureReason;
  final DateTime? paidAt;

  PayoutBatchItem toEntity() => PayoutBatchItem(
    id: id,
    workerName: workerName,
    amount: amount,
    paymentStatus: paymentStatus,
    destination: destination,
    failureReason: failureReason,
    paidAt: paidAt,
  );
}

@JsonSerializable(createToJson: false)
class PayoutBatchModel {
  const PayoutBatchModel({
    required this.id,
    required this.hiringPostId,
    required this.totalAmount,
    this.paidAmount = 0,
    required this.batchStatus,
    this.providerOrderId,
    this.providerPaymentId,
    this.razorpayKeyId,
    this.nothingToCollect = false,
    this.fundedAt,
    this.completedAt,
    this.items = const [],
    this.isReconciled = true,
    this.excludedPayees = const [],
  });

  factory PayoutBatchModel.fromJson(Map<String, dynamic> json) =>
      _$PayoutBatchModelFromJson(json);

  final String id;
  final String hiringPostId;
  final double totalAmount;
  final double paidAmount;
  final String batchStatus;
  final String? providerOrderId;
  final String? providerPaymentId;
  final String? razorpayKeyId;
  final bool nothingToCollect;
  final DateTime? fundedAt;
  final DateTime? completedAt;
  final List<PayoutBatchItemModel> items;
  final bool isReconciled;
  final List<PayoutExclusionModel> excludedPayees;

  PayoutBatch toEntity() => PayoutBatch(
    id: id,
    hiringPostId: hiringPostId,
    totalAmount: totalAmount,
    paidAmount: paidAmount,
    batchStatus: batchStatus,
    providerOrderId: providerOrderId,
    providerPaymentId: providerPaymentId,
    razorpayKeyId: razorpayKeyId,
    nothingToCollect: nothingToCollect,
    fundedAt: fundedAt,
    completedAt: completedAt,
    items: items.map((i) => i.toEntity()).toList(),
    isReconciled: isReconciled,
    excludedPayees: excludedPayees.map((e) => e.toEntity()).toList(),
  );
}

@JsonSerializable(createToJson: false)
class PayoutExclusionModel {
  const PayoutExclusionModel({this.workerName = '', this.reason = ''});

  factory PayoutExclusionModel.fromJson(Map<String, dynamic> json) =>
      _$PayoutExclusionModelFromJson(json);

  final String workerName;
  final String reason;

  PayoutExclusion toEntity() =>
      PayoutExclusion(workerName: workerName, reason: reason);
}
