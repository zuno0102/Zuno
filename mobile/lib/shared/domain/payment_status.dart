/// How one worker's wage state reads on screen, or null while there is nothing to say (unpaid,
/// nothing tried yet).
///
/// One list for every crew row — a hiring post's and an order's — so "Payment failed" reads the
/// same wherever the business sees it, and explains why Raise salary is no longer offered.
String? paymentStatusLabel(String paymentStatus) => switch (paymentStatus) {
  'Paid' => 'Paid',
  'Failed' => 'Payment failed',
  'Disputed' => 'Disputed',
  'Processing' => 'Sending',
  'AwaitingWorkerConfirmation' => 'Awaiting confirmation',
  _ => null,
};
