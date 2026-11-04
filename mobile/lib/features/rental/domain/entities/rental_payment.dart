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
    this.cancelChargeTypes = const [],
  });

  final List<RentalPaymentOption> advanceTypes;

  /// The ways the business may record money taken — UPI QR first.
  final List<RentalPaymentOption> methods;

  /// The ways a cancellation charge can be worked out, for the item form.
  final List<RentalPaymentOption> cancelChargeTypes;
}

/// One payment line on an order: the advance, a later payment, or a refund.
class RentalOrderPayment {
  const RentalOrderPayment({
    required this.id,
    required this.at,
    required this.kind,
    required this.methodName,
    required this.amount,
    this.reference,
  });

  final String id;
  final DateTime at;

  /// `Advance`, `Balance` or `Refund`.
  final String kind;

  /// From the server's method table, e.g. "UPI QR".
  final String methodName;
  final double amount;

  /// The UPI transaction reference, when one was recorded.
  final String? reference;

  bool get isRefund => kind == 'Refund';
  bool get isAdvance => kind == 'Advance';
}

/// One step of the cancellation charge: cancelling [unitsBefore] or more days (hours for an hourly
/// item) before the start costs [percent] of the order. 0 is the start day itself.
class RentalCancelStep {
  const RentalCancelStep({required this.unitsBefore, required this.percent});

  final int unitsBefore;
  final double percent;

  Map<String, dynamic> toJson() => {
    'unitsBefore': unitsBefore,
    'percent': percent,
  };
}

/// What the cancellation steps count — the server's names.
class RentalCancelUnit {
  const RentalCancelUnit._();

  static const day = 'Day';
  static const hour = 'Hour';

  /// What an item charged by [priceType] counts its steps in.
  static String of(String priceType) =>
      priceType == RentalPriceType.hourly ? hour : day;
}

/// How a cancellation charge is worked out — the server's names.
class RentalCancelChargeType {
  const RentalCancelChargeType._();

  /// Steps by time left before the start: 5+ days 0.5%, on the day 2%.
  static const byTimeLeft = 'ByTimeLeft';

  /// One percent for each day (hour, for an hourly item) rented: 1% a day, a 2-day order 2%.
  static const perRentalDay = 'PerRentalDay';
}

/// The percent a per-rental-day charge comes to: [perDay] for each of [units], at most [cap].
double rentalPerDayPercent(double perDay, int units, double cap) {
  final total = perDay * (units < 1 ? 1 : units);
  return total < cap ? total : cap;
}

/// "5+ days before", "1+ hour before", "On the day" — how a step reads.
String rentalCancelStepWhen(int unitsBefore, String unit) {
  if (unitsBefore == 0) {
    return unit == RentalCancelUnit.hour ? 'In the last hour' : 'On the day';
  }
  final noun = unit == RentalCancelUnit.hour ? 'hour' : 'day';
  return '$unitsBefore+ $noun${unitsBefore == 1 ? '' : 's'} before';
}

/// "0.5%", "2%".
String rentalPercent(double value) =>
    '${value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '')}%';

/// The policy in one line, farthest step first: "5+ days before: 0.5% · On the day: 2%", or
/// "Free cancellation" with no steps.
String rentalCancelPolicy(List<RentalCancelStep> steps, String unit) {
  if (steps.isEmpty || steps.every((s) => s.percent == 0)) {
    return 'Free cancellation';
  }
  final ordered = [...steps]
    ..sort((a, b) => b.unitsBefore.compareTo(a.unitsBefore));
  return ordered
      .map(
        (s) =>
            '${rentalCancelStepWhen(s.unitsBefore, unit)}: ${rentalPercent(s.percent)}',
      )
      .join(' · ');
}

/// What cancelling an order now would cost and give back, from the server.
class RentalCancelQuote {
  const RentalCancelQuote({
    required this.unitsBefore,
    required this.unit,
    required this.percent,
    required this.charge,
    required this.paid,
    required this.refund,
    this.refundModes = const [],
    this.basis = RentalCancelChargeType.byTimeLeft,
    this.rentalUnits = 1,
  });

  final int unitsBefore;

  /// [RentalCancelUnit.day] or [RentalCancelUnit.hour].
  final String unit;
  final double percent;

  /// What the business keeps.
  final double charge;
  final double paid;

  /// What goes back to the customer.
  final double refund;

  /// For the business cancelling a paid order: the ways the money can go back, one of which is
  /// chosen in the cancel step. Empty when nothing would be owed back, and for the customer.
  final List<RentalRefundModeChoice> refundModes;

  /// [RentalCancelChargeType.byTimeLeft] or [RentalCancelChargeType.perRentalDay]: how [percent] was reached.
  final String basis;

  /// Days (hours, for an hourly order) the order is for — what a per-day charge counts.
  final int rentalUnits;
}

/// How a refund goes back — the server's names.
class RentalRefundMode {
  const RentalRefundMode._();

  static const online = 'Online';
  static const inHand = 'InHand';
}

/// One way the business may send a refund back, with what it means, from the server's table.
class RentalRefundModeChoice {
  const RentalRefundModeChoice({
    required this.code,
    required this.name,
    required this.text,
    this.disabledReason,
  });

  /// [RentalRefundMode.online] or [RentalRefundMode.inHand].
  final String code;
  final String name;
  final String text;

  /// Why it cannot be chosen — the customer paid in cash; null when it can.
  final String? disabledReason;
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
    this.reference,
    this.payeeUpiId,
  });

  /// [RentalPaymentMethod.upiQr] or [RentalPaymentMethod.cash].
  final String method;
  final double amount;
  final bool isRefund;

  /// The UPI transaction reference the UPI app reported, when paid by UPI.
  final String? reference;

  /// The customer's UPI ID a refund was paid to.
  final String? payeeUpiId;

  Map<String, dynamic> toJson() => {
    'method': method,
    'amount': amount,
    'isRefund': isRefund,
    'reference': ?reference,
    'payeeUpiId': ?payeeUpiId,
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

/// A UPI ID like `rahul@okaxis` — the Rent server's `RentalPaymentFields.UpiIdPattern`.
final rentalUpiIdPattern = RegExp(
  r'^[a-zA-Z0-9._-]{2,256}@[a-zA-Z][a-zA-Z0-9]{1,63}$',
);

/// The UPI ID in what was scanned or typed: a UPI QR (`upi://pay?pa=rahul@okaxis&pn=Rahul…`) or
/// the ID itself. Null when it is neither — a shop's website QR, say.
String? rentalUpiIdFrom(String raw) {
  final text = raw.trim();
  if (text.toLowerCase().startsWith('upi://')) {
    final payee = Uri.tryParse(text)?.queryParameters['pa']?.trim();
    return payee != null && rentalUpiIdPattern.hasMatch(payee) ? payee : null;
  }
  return rentalUpiIdPattern.hasMatch(text) ? text : null;
}
