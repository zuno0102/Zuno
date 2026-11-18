/// A customer's order of a product, as the business sees it: what, how paid, where it is on its way.
class MarketplaceOrder {
  const MarketplaceOrder({
    required this.id,
    required this.number,
    required this.postId,
    required this.title,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
    required this.paymentMethod,
    required this.paymentMethodName,
    required this.isPaid,
    required this.status,
    required this.statusName,
    required this.statusTone,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.pincode,
    required this.createdDate,
    this.variantName,
    this.imageUrl,
    this.paidAt,
    this.dueToBusiness = 0,
    this.refundDue = false,
    this.refunded = false,
    this.courierCode,
    this.courierName,
    this.trackingNumber,
    this.trackingUrl,
    this.receiptUrl,
    this.payBy,
    this.shippedAt,
    this.deliveredAt,
    this.closesAt,
    this.closedAt,
    this.cancelledAt,
    this.cancelledBy,
    this.ratingScore,
    this.ratingComment,
    this.actions = const [],
    this.events = const [],
  });

  final String id;

  /// The short number on the card, e.g. "7F21C0A4".
  final String number;
  final String postId;
  final String title;

  /// "Red · M"; null without a colour / size.
  final String? variantName;
  final String? imageUrl;
  final int quantity;
  final double unitPrice;
  final double amount;

  /// `CashOnDelivery` or `Online`.
  final String paymentMethod;
  final String paymentMethodName;
  final bool isPaid;
  final DateTime? paidAt;

  /// What Zuno owes the business for it: paid online and not given back.
  final double dueToBusiness;
  final bool refundDue;
  final bool refunded;
  final String status;
  final String statusName;
  final String statusTone;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final String pincode;
  final String? courierCode;
  final String? courierName;
  final String? trackingNumber;

  /// The courier's own tracking page for this number; null when the courier has none.
  final String? trackingUrl;
  final String? receiptUrl;
  final DateTime? payBy;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;

  /// A delivered order with no review closes by itself then.
  final DateTime? closesAt;
  final DateTime? closedAt;
  final DateTime? cancelledAt;

  /// `Business`, `Customer` or `System`; null unless cancelled.
  final String? cancelledBy;
  final int? ratingScore;
  final String? ratingComment;
  final DateTime createdDate;

  /// The buttons the business may press now, from the server's table.
  final List<MarketplaceOrderAction> actions;

  /// The history, oldest first — on the order's own page only.
  final List<MarketplaceOrderEvent> events;

  bool get isOnline => paymentMethod == 'Online';

  /// "Silk saree · Red".
  String get titleWithVariant =>
      variantName == null ? title : '$title · $variantName';

  /// "DTDC · D45120098871"; null before it ships.
  String? get courierLine => courierName == null || trackingNumber == null
      ? null
      : '$courierName · $trackingNumber';
}

/// A button on an order, e.g. "Mark shipped".
class MarketplaceOrderAction {
  const MarketplaceOrderAction({
    required this.toStatus,
    required this.name,
    this.needsConfirm = false,
    this.needsTracking = false,
  });

  final String toStatus;
  final String name;
  final bool needsConfirm;

  /// Taken through the ship sheet: courier and tracking number first.
  final bool needsTracking;
}

/// One step in an order's history.
class MarketplaceOrderEvent {
  const MarketplaceOrderEvent({
    required this.status,
    required this.statusName,
    required this.actor,
    required this.at,
    this.note,
  });

  final String status;
  final String statusName;

  /// `Business`, `Customer` or `System`.
  final String actor;
  final String? note;
  final DateTime at;
}

/// A count per status, for the chips over a list. Every status comes, zeros too.
class MarketplaceStatusCount {
  const MarketplaceStatusCount({required this.status, required this.count});

  final String status;
  final int count;
}

class MarketplaceOrderPage {
  const MarketplaceOrderPage({
    required this.items,
    required this.totalCount,
    this.counts = const [],
  });

  final List<MarketplaceOrder> items;
  final int totalCount;
  final List<MarketplaceStatusCount> counts;

  /// Every order, whatever its status.
  int get allCount => counts.fold(0, (sum, c) => sum + c.count);
}

/// A buyer asking for a B2B lot. Contacts are filled in only for whoever may see them.
class MarketplaceB2BRequest {
  const MarketplaceB2BRequest({
    required this.id,
    required this.number,
    required this.postId,
    required this.title,
    required this.quantity,
    required this.status,
    required this.statusName,
    required this.statusTone,
    required this.buyerName,
    required this.createdDate,
    this.unit,
    this.unitPrice,
    this.total,
    this.minOrderQuantity,
    this.message,
    this.buyerPhone,
    this.sellerName,
    this.respondedAt,
  });

  final String id;
  final String number;
  final String postId;
  final String title;
  final int quantity;

  /// E.g. "kg"; null when the lot has none.
  final String? unit;
  final double? unitPrice;
  final double? total;
  final int? minOrderQuantity;
  final String? message;

  /// `Requested`, `Accepted` or `Declined`.
  final String status;
  final String statusName;
  final String statusTone;
  final String buyerName;

  /// Shown once the business accepts.
  final String? buyerPhone;
  final String? sellerName;
  final DateTime createdDate;
  final DateTime? respondedAt;

  bool get isNew => status == 'Requested';

  bool get isAccepted => status == 'Accepted';

  /// "500 kg".
  String get quantityLine => unit == null ? '$quantity' : '$quantity $unit';
}

class MarketplaceB2BRequestPage {
  const MarketplaceB2BRequestPage({
    required this.items,
    required this.totalCount,
    this.counts = const [],
  });

  final List<MarketplaceB2BRequest> items;
  final int totalCount;
  final List<MarketplaceStatusCount> counts;

  int get allCount => counts.fold(0, (sum, c) => sum + c.count);
}

/// How the business lets customers pay for orders.
class MarketplacePaymentSettings {
  const MarketplacePaymentSettings({
    required this.acceptsCashOnDelivery,
    required this.acceptsOnlinePay,
    this.onlinePayAvailable = true,
  });

  final bool acceptsCashOnDelivery;
  final bool acceptsOnlinePay;

  /// Whether online pay can be taken on the server at all just now.
  final bool onlinePayAvailable;
}

/// A courier the ship sheet offers.
class MarketplaceCourier {
  const MarketplaceCourier({
    required this.code,
    required this.name,
    this.takesCustomName = false,
    this.hasTrackingLink = false,
  });

  final String code;
  final String name;

  /// "Other": the business types the courier's name.
  final bool takesCustomName;
  final bool hasTrackingLink;
}
