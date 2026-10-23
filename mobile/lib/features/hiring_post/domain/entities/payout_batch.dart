/// One worker's line on a pay run.
class PayoutBatchItem {
  const PayoutBatchItem({
    required this.id,
    required this.workerName,
    required this.amount,
    required this.paymentStatus,
    this.destination,
    this.failureReason,
    this.paidAt,
  });

  final String id;
  final String workerName;
  final double amount;
  final String paymentStatus;

  /// Masked UPI address or account, so a wrong destination is spottable without leaking it.
  final String? destination;
  final String? failureReason;
  final DateTime? paidAt;

  bool get isPaid => paymentStatus == 'Paid';
  bool get isFailed => paymentStatus == 'Failed';
  bool get isDisputed => paymentStatus == 'Disputed';
}

/// A pay run: one amount the business pays, split across the crew.
class PayoutBatch {
  const PayoutBatch({
    required this.id,
    required this.hiringPostId,
    required this.totalAmount,
    required this.paidAmount,
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

  final String id;
  final String hiringPostId;

  /// Crew this run could not include, and why. Nothing was collected for them, and they stay
  /// owed — so the job keeps saying Awaiting payment until a later run covers them.
  final List<PayoutExclusion> excludedPayees;

  /// Always the server's own figure. The app never computes or sends this.
  final double totalAmount;
  final double paidAmount;
  final String batchStatus;

  /// Present only while the run still needs paying — what a real gateway would open.
  final String? providerOrderId;

  /// Razorpay's id once the business has paid. Null while the run still awaits payment.
  final String? providerPaymentId;

  /// Razorpay's publishable key, sent only while Checkout still needs opening.
  final String? razorpayKeyId;

  /// No money is really moving: the server raised this run with simulated payouts on, which
  /// only a development build permits. There is nothing to collect, so nothing to open.
  final bool nothingToCollect;
  final DateTime? fundedAt;
  final DateTime? completedAt;
  final List<PayoutBatchItem> items;

  /// Whether every rupee paid is accounted for by the worker lines.
  final bool isReconciled;

  /// Whether Checkout still has to be opened.
  ///
  /// False for a run already funded — reopening it would charge the business twice for the same
  /// wages — and false for a simulated run, which never raised an order because it is not
  /// collecting anything.
  bool get needsPayment =>
      fundedAt == null &&
      !nothingToCollect &&
      providerOrderId != null &&
      razorpayKeyId != null;
  bool get isCompleted => batchStatus == 'Completed';

  int get paidCount => items.where((i) => i.isPaid).length;

  List<PayoutBatchItem> get failedItems =>
      items.where((i) => i.isFailed).toList();
}

/// A worker a pay run left out, and the reason.
class PayoutExclusion {
  const PayoutExclusion({required this.workerName, required this.reason});

  final String workerName;
  final String reason;
}
