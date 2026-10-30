import 'package:zuno/features/rental/domain/entities/rental_item.dart';

/// Whether a rent item asks an advance, and how it is counted — the server's enum names.
class RentalAdvanceType {
  const RentalAdvanceType._();

  static const none = 'None';

  /// One amount for the whole order, e.g. ₹500 however many chairs.
  static const perOrder = 'PerOrder';

  /// An amount for each piece, e.g. ₹2 a chair.
  static const perPiece = 'PerPiece';
}

/// How money on a rent order changed hands — the server's enum names.
class RentalPaymentMethod {
  const RentalPaymentMethod._();

  static const upiQr = 'UpiQr';
  static const cash = 'Cash';
}

/// One choice the server's tables offer — an advance type or a payment method — with its words.
class RentalPaymentOption {
  const RentalPaymentOption({
    required this.code,
    required this.name,
    this.detail = '',
  });

  final String code;
  final String name;
  final String detail;
}

/// The words for the item form's advance and the collect sheet's methods, from the server's tables.
class RentalPaymentOptions {
  const RentalPaymentOptions({
    this.advanceTypes = const [],
    this.methods = const [],
  });

  final List<RentalPaymentOption> advanceTypes;

  /// The ways the business may record money taken — UPI QR first.
  final List<RentalPaymentOption> methods;
}

/// One payment line on an order: the advance, a later payment, or a refund.
class RentalOrderPayment {
  const RentalOrderPayment({
    required this.id,
    required this.at,
    required this.kind,
    required this.methodName,
    required this.amount,
  });

  final String id;
  final DateTime at;

  /// `Advance`, `Balance` or `Refund`.
  final String kind;

  /// From the server's method table, e.g. "UPI QR".
  final String methodName;
  final double amount;

  bool get isRefund => kind == 'Refund';
  bool get isAdvance => kind == 'Advance';
}

/// What the payment window opens with, from the server.
class RentalCheckout {
  const RentalCheckout({
    required this.providerOrderId,
    required this.keyId,
    required this.amount,
    required this.description,
    this.nothingToCollect = false,
  });

  final String providerOrderId;
  final String keyId;
  final double amount;
  final String description;

  /// Development only: no money moves, so the app confirms without opening the window.
  final bool nothingToCollect;
}

/// Money the business took for an order — or gave back on a cancelled one.
class RentalPaymentInput {
  const RentalPaymentInput({
    required this.method,
    required this.amount,
    this.isRefund = false,
  });

  /// [RentalPaymentMethod.upiQr] or [RentalPaymentMethod.cash].
  final String method;
  final double amount;
  final bool isRefund;

  Map<String, dynamic> toJson() => {
    'method': method,
    'amount': amount,
    'isRefund': isRefund,
  };
}

/// Days or hours charged — rounded up, never less than one; one for a per-item rate. The server's
/// rule, so the sheet shows what the order will cost before it is saved.
int rentalUnits(String priceType, DateTime start, DateTime end) {
  final length = end.difference(start);
  final units = switch (priceType) {
    RentalPriceType.daily => (length.inMinutes / Duration.minutesPerDay).ceil(),
    RentalPriceType.hourly =>
      (length.inMinutes / Duration.minutesPerHour).ceil(),
    _ => 1,
  };
  return units < 1 ? 1 : units;
}

/// What an order costs: rate × pieces × days or hours.
double rentalAmount(
  String priceType,
  double unitPrice,
  int quantity,
  DateTime start,
  DateTime end,
) => unitPrice * quantity * rentalUnits(priceType, start, end);

/// The advance an order asks: fixed or per piece, never more than the order costs.
double rentalAdvance(
  String advanceType,
  double? advanceAmount,
  int quantity,
  double orderAmount,
) {
  final advance = switch (advanceType) {
    RentalAdvanceType.perOrder => advanceAmount ?? 0,
    RentalAdvanceType.perPiece => (advanceAmount ?? 0) * quantity,
    _ => 0.0,
  };
  return advance < orderAmount ? advance : orderAmount;
}

/// A UPI payment link for a QR: any UPI app that scans it opens a payment of [amount] to [upiId].
String rentalUpiUri({
  required String upiId,
  required String payee,
  required double amount,
  required String note,
}) => Uri(
  scheme: 'upi',
  host: 'pay',
  queryParameters: {
    'pa': upiId,
    'pn': payee,
    'am': amount.toStringAsFixed(2),
    'cu': 'INR',
    'tn': note,
  },
).toString();

/// An amount as it is typed into a field: 500, or 499.50 when it has paise.
String rentalPlainAmount(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);
