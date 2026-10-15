/// What Razorpay hands back once a payment completes.
///
/// The signature is the point of this object. The other two ids are just labels until the
/// server has checked them against a secret only it holds — a browser can claim anything.
class RazorpayResult {
  const RazorpayResult({
    required this.paymentId,
    required this.orderId,
    required this.signature,
  });

  final String paymentId;
  final String orderId;
  final String signature;
}

/// Raised when the business closes the payment window, or Razorpay refuses the payment.
class RazorpayCancelled implements Exception {
  const RazorpayCancelled([this.reason]);

  final String? reason;

  @override
  String toString() => reason ?? 'Payment was cancelled.';
}
