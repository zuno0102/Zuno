import 'package:zuno/features/rental/domain/entities/rental_payment.dart';

/// One item's stock on the Stock page — chairs: 700 in, 100 booked, 300 out, 1000 in total.
class RentalStockLine {
  const RentalStockLine({
    required this.rentalItemId,
    required this.name,
    required this.rentalCategoryName,
    required this.isAvailable,
    required this.quantityTotal,
    required this.quantityOut,
    required this.quantityIn,
    this.quantityBooked = 0,
    this.rentalSubCategoryName,
    this.imageUrl,
  });

  final String rentalItemId;
  final String name;
  final String rentalCategoryName;
  final String? rentalSubCategoryName;
  final bool isAvailable;

  /// What the business owns: in + out.
  final int quantityTotal;

  /// With customers now.
  final int quantityOut;

  /// On hand.
  final int quantityIn;

  /// Promised to customers but not yet sent — on hand, already spoken for.
  final int quantityBooked;

  final String? imageUrl;
}

/// A step the business may take on an order — "Send out", "Mark returned". From the server's
/// transition table.
class RentalOrderAction {
  const RentalOrderAction({
    required this.toStatus,
    required this.label,
    this.confirmFirst = false,
    this.disabledReason,
  });

  final String toStatus;
  final String label;

  /// Ask "are you sure?" first, e.g. before cancelling.
  final bool confirmFirst;

  /// Why the step cannot be taken yet — "Collect ₹1,500 first"; null when it can.
  final String? disabledReason;
}

/// A customer renting some of an item: who, how many, when, where the pieces went, and what the
/// business can do next.
class RentalOrder {
  const RentalOrder({
    required this.id,
    required this.customerName,
    required this.quantity,
    required this.startDate,
    required this.endDate,
    required this.deliveryAddress,
    required this.status,
    required this.statusName,
    required this.statusTone,
    required this.isOut,
    this.rentalItemId = '',
    this.itemName = '',
    this.customerPhone,
    this.districtName,
    this.unreadMessages = 0,
    this.actions = const [],
    this.parentOrderId,
    this.addOns = const [],
    this.canAddPieces = false,
    this.businessName,
    this.source = '',
    this.answers = const [],
    this.priceType = '',
    this.unitPrice = 0,
    this.units = 1,
    this.amount = 0,
    this.advanceDue = 0,
    this.paid = 0,
    this.balance = 0,
    this.paymentStatus,
    this.paymentStatusName,
    this.paymentStatusTone,
    this.payments = const [],
    this.holdUntil,
    this.payNowAmount = 0,
    this.canCollect = false,
    this.canRefund = false,
    this.canPayOnline = false,
    this.upiId,
  });

  final String id;
  final String rentalItemId;
  final String itemName;

  /// The business renting it out, as customers see it.
  final String? businessName;

  /// `App` (the customer booked it) or `Offline` (the business took it).
  final String source;

  /// The customer's answers to the item's questions, as asked.
  final List<RentalOrderAnswer> answers;

  bool get isFromApp => source == 'App';
  final String customerName;
  final String? customerPhone;
  final int quantity;
  final DateTime startDate;
  final DateTime endDate;
  final String deliveryAddress;
  final String? districtName;

  /// `Booked`, `OnRent`, `Returned` or `Cancelled`.
  final String status;

  /// From the server's status table, e.g. "On rent".
  final String statusName;

  /// The colour name from the status table: `success`, `progress`, `waiting`, `danger`.
  final String statusTone;

  /// Whether these pieces are out with the customer now.
  final bool isOut;

  /// Messages from the customer not opened yet.
  final int unreadMessages;

  /// What the business can do next — empty once the order is finished.
  final List<RentalOrderAction> actions;

  /// The order this one adds pieces to, when it is an add-on.
  final String? parentOrderId;

  /// Extra pieces added to this order later, each its own order.
  final List<RentalOrderAddOn> addOns;

  /// Whether more pieces can still be added: the order is booked or out.
  final bool canAddPieces;

  bool get isAddOn => parentOrderId != null;

  /// `Daily`, `Hourly` or `Fixed` — the rate the order was booked at.
  final String priceType;
  final double unitPrice;

  /// Days or hours charged.
  final int units;

  /// What the order costs: rate × pieces × days or hours.
  final double amount;

  /// The advance the order asks; 0 when none.
  final double advanceDue;

  /// Paid so far, refunds taken off.
  final double paid;

  /// Still to be paid.
  final double balance;

  /// From the server's payment-status table, e.g. `AdvancePaid`; null when there is nothing to say.
  final String? paymentStatus;
  final String? paymentStatusName;
  final String? paymentStatusTone;

  /// Every payment and refund, oldest first.
  final List<RentalOrderPayment> payments;

  /// Until when an order awaiting its advance holds the pieces.
  final DateTime? holdUntil;

  /// What the customer pays online now: the advance while awaited, otherwise what is due.
  final double payNowAmount;

  /// The business may take money in — cash or UPI QR.
  final bool canCollect;

  /// The business may record money given back on this cancelled order.
  final bool canRefund;

  /// The customer may pay online now.
  final bool canPayOnline;

  /// The business's UPI ID for the payment QR — for the business only.
  final String? upiId;

  bool get isAwaitingAdvance => status == 'AwaitingAdvance';

  /// Whether the order carries a price — orders from before prices were kept do not.
  bool get isPriced => amount > 0;

  /// "300 + 200 extra" — all the pieces this customer has on this order and its add-ons.
  int get quantityWithAddOns =>
      quantity + addOns.fold<int>(0, (sum, a) => sum + a.quantity);

  /// "St. Mary's Hall, Kakkanad · Ernakulam".
  String get placeLine => [
    deliveryAddress,
    districtName,
  ].whereType<String>().where((p) => p.trim().isNotEmpty).join(' · ');
}

/// One step in an order's history — "30 Oct 08:30 · On rent · 300". Never edited.
class RentalOrderEvent {
  const RentalOrderEvent({
    required this.id,
    required this.at,
    required this.title,
    required this.tone,
    required this.quantity,
    this.onAddOn = false,
    this.relatedOrderId,
    this.amount,
    this.paymentMethodName,
  });

  final String id;
  final DateTime at;

  /// "Booked", "Extra pieces added", or the status moved to ("On rent").
  final String title;
  final String tone;
  final int quantity;

  /// Whether the step belongs to one of the order's add-ons.
  final bool onAddOn;
  final String? relatedOrderId;

  /// For a payment step: how much, and how — "₹500 · Cash".
  final double? amount;
  final String? paymentMethodName;
}

/// A customer's answer to one of the item's questions, with the wording as it was asked.
class RentalOrderAnswer {
  const RentalOrderAnswer({required this.prompt, required this.answer});

  final String prompt;
  final String answer;
}

/// Extra pieces on an order, as the order lists them.
class RentalOrderAddOn {
  const RentalOrderAddOn({
    required this.id,
    required this.quantity,
    required this.statusName,
    required this.statusTone,
  });

  final String id;
  final int quantity;
  final String statusName;
  final String statusTone;
}

/// How many of an item a new order for some dates can take.
class RentalAvailability {
  const RentalAvailability({
    required this.total,
    required this.held,
    required this.available,
  });

  /// What the business owns.
  final int total;

  /// On orders that overlap the dates.
  final int held;

  /// What a new order can take — 0 while the item is switched off.
  final int available;
}

/// What the business fills in to book pieces for a customer who phoned or came in.
class RentalOrderInput {
  const RentalOrderInput({
    required this.rentalItemId,
    required this.quantity,
    required this.startDate,
    required this.endDate,
    required this.customerName,
    required this.deliveryAddress,
    this.customerPhone,
    this.advanceMethod,
    this.advanceAmount,
  });

  final String rentalItemId;
  final int quantity;
  final DateTime startDate;
  final DateTime endDate;

  /// How the advance was paid — [RentalPaymentMethod.cash] or [RentalPaymentMethod.upiQr]. Needed
  /// whenever an advance is taken.
  final String? advanceMethod;

  /// The advance taken now, as the business typed it; null takes the item's own.
  final double? advanceAmount;
  final String customerName;
  final String? customerPhone;
  final String deliveryAddress;

  Map<String, dynamic> toJson() => {
    'rentalItemId': rentalItemId,
    'quantity': quantity,
    'startDate': rentalApiDate(startDate),
    'endDate': rentalApiDate(endDate),
    'customerName': customerName,
    'customerPhone': customerPhone,
    'deliveryAddress': deliveryAddress,
    'advanceMethod': ?advanceMethod,
    'advanceAmount': ?advanceAmount,
  };
}

/// A moment as the Rent server takes it: ISO 8601 with the business's own offset, so the server
/// can name the dates back in the business's day ("Only 300 available for 1 Nov – 3 Nov").
String rentalApiDate(DateTime moment) {
  final local = moment.toLocal();
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final hours = offset.inHours.abs().toString().padLeft(2, '0');
  final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
  final base = local.toIso8601String().split('.').first;
  return '$base$sign$hours:$minutes';
}

/// How many orders sit in one status — a filter chip.
class RentalOrderStatusCount {
  const RentalOrderStatusCount({
    required this.status,
    required this.name,
    required this.tone,
    required this.count,
  });

  final String status;
  final String name;
  final String tone;
  final int count;
}

/// A rent order with a conversation on it, as the Rent Messages list shows it.
class RentalOrderThread {
  const RentalOrderThread({
    required this.rentalOrderId,
    required this.customerName,
    required this.itemName,
    required this.quantity,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastFromCustomer,
    required this.unreadCount,
    this.businessName,
  });

  final String rentalOrderId;
  final String customerName;

  /// The business, for the customer's list.
  final String? businessName;
  final String itemName;
  final int quantity;
  final String lastMessage;
  final DateTime lastMessageAt;
  final bool lastFromCustomer;
  final int unreadCount;
}
