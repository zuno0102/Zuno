/// One recorded raise to a confirmed worker's agreed salary. Append-only on the server,
/// so together these form the worker's proof of what was promised and when.
class HiringPostSalaryAdjustment {
  const HiringPostSalaryAdjustment({
    required this.id,
    required this.previousAmount,
    required this.newAmount,
    this.reason,
    required this.adjustedAt,
  });

  final String id;
  final double previousAmount;
  final double newAmount;
  final String? reason;
  final DateTime adjustedAt;

  double get increase => newAmount - previousAmount;
}
