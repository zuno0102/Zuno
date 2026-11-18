import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_order.dart';

part 'marketplace_order_models.g.dart';

@JsonSerializable(createToJson: false)
class MarketplaceOrderActionModel {
  const MarketplaceOrderActionModel({
    required this.toStatus,
    required this.name,
    this.needsConfirm = false,
    this.needsTracking = false,
  });

  factory MarketplaceOrderActionModel.fromJson(Map<String, dynamic> json) =>
      _$MarketplaceOrderActionModelFromJson(json);

  final String toStatus;
  final String name;
  final bool needsConfirm;
  final bool needsTracking;

  MarketplaceOrderAction toEntity() => MarketplaceOrderAction(
    toStatus: toStatus,
    name: name,
    needsConfirm: needsConfirm,
    needsTracking: needsTracking,
  );
}

@JsonSerializable(createToJson: false)
class MarketplaceOrderEventModel {
  const MarketplaceOrderEventModel({
    required this.status,
    required this.statusName,
    required this.actor,
    required this.at,
    this.note,
  });

  factory MarketplaceOrderEventModel.fromJson(Map<String, dynamic> json) =>
      _$MarketplaceOrderEventModelFromJson(json);

  final String status;
  final String statusName;
  final String actor;
  final String? note;
  final DateTime at;

  MarketplaceOrderEvent toEntity() => MarketplaceOrderEvent(
    status: status,
    statusName: statusName,
    actor: actor,
    note: note,
    at: at.toLocal(),
  );
}

@JsonSerializable(createToJson: false)
class MarketplaceOrderModel {
  const MarketplaceOrderModel({
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

  factory MarketplaceOrderModel.fromJson(Map<String, dynamic> json) =>
      _$MarketplaceOrderModelFromJson(json);

  final String id;
  final String number;
  final String postId;
  final String title;
  final String? variantName;
  final String? imageUrl;
  final int quantity;
  final double unitPrice;
  final double amount;
  final String paymentMethod;
  final String paymentMethodName;
  final bool isPaid;
  final DateTime? paidAt;
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
  final String? trackingUrl;
  final String? receiptUrl;
  final DateTime? payBy;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final DateTime? closesAt;
  final DateTime? closedAt;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final int? ratingScore;
  final String? ratingComment;
  final DateTime createdDate;
  final List<MarketplaceOrderActionModel> actions;
  final List<MarketplaceOrderEventModel> events;

  MarketplaceOrder toEntity() => MarketplaceOrder(
    id: id,
    number: number,
    postId: postId,
    title: title,
    variantName: variantName,
    imageUrl: imageUrl,
    quantity: quantity,
    unitPrice: unitPrice,
    amount: amount,
    paymentMethod: paymentMethod,
    paymentMethodName: paymentMethodName,
    isPaid: isPaid,
    paidAt: paidAt?.toLocal(),
    dueToBusiness: dueToBusiness,
    refundDue: refundDue,
    refunded: refunded,
    status: status,
    statusName: statusName,
    statusTone: statusTone,
    customerName: customerName,
    customerPhone: customerPhone,
    deliveryAddress: deliveryAddress,
    pincode: pincode,
    courierCode: courierCode,
    courierName: courierName,
    trackingNumber: trackingNumber,
    trackingUrl: trackingUrl,
    receiptUrl: receiptUrl,
    payBy: payBy?.toLocal(),
    shippedAt: shippedAt?.toLocal(),
    deliveredAt: deliveredAt?.toLocal(),
    closesAt: closesAt?.toLocal(),
    closedAt: closedAt?.toLocal(),
    cancelledAt: cancelledAt?.toLocal(),
    cancelledBy: cancelledBy,
    ratingScore: ratingScore,
    ratingComment: ratingComment,
    createdDate: createdDate.toLocal(),
    actions: [for (final a in actions) a.toEntity()],
    events: [for (final e in events) e.toEntity()],
  );
}

@JsonSerializable(createToJson: false)
class MarketplaceStatusCountModel {
  const MarketplaceStatusCountModel({
    required this.status,
    required this.count,
  });

  factory MarketplaceStatusCountModel.fromJson(Map<String, dynamic> json) =>
      _$MarketplaceStatusCountModelFromJson(json);

  final String status;
  final int count;

  MarketplaceStatusCount toEntity() =>
      MarketplaceStatusCount(status: status, count: count);
}

@JsonSerializable(createToJson: false)
class MarketplaceOrderPageModel {
  const MarketplaceOrderPageModel({
    required this.items,
    required this.totalCount,
    this.counts = const [],
  });

  factory MarketplaceOrderPageModel.fromJson(Map<String, dynamic> json) =>
      _$MarketplaceOrderPageModelFromJson(json);

  final List<MarketplaceOrderModel> items;
  final int totalCount;
  final List<MarketplaceStatusCountModel> counts;

  MarketplaceOrderPage toEntity() => MarketplaceOrderPage(
    items: [for (final o in items) o.toEntity()],
    totalCount: totalCount,
    counts: [for (final c in counts) c.toEntity()],
  );
}

@JsonSerializable(createToJson: false)
class MarketplaceB2BRequestModel {
  const MarketplaceB2BRequestModel({
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

  factory MarketplaceB2BRequestModel.fromJson(Map<String, dynamic> json) =>
      _$MarketplaceB2BRequestModelFromJson(json);

  final String id;
  final String number;
  final String postId;
  final String title;
  final int quantity;
  final String? unit;
  final double? unitPrice;
  final double? total;
  final int? minOrderQuantity;
  final String? message;
  final String status;
  final String statusName;
  final String statusTone;
  final String buyerName;
  final String? buyerPhone;
  final String? sellerName;
  final DateTime createdDate;
  final DateTime? respondedAt;

  MarketplaceB2BRequest toEntity() => MarketplaceB2BRequest(
    id: id,
    number: number,
    postId: postId,
    title: title,
    quantity: quantity,
    unit: unit,
    unitPrice: unitPrice,
    total: total,
    minOrderQuantity: minOrderQuantity,
    message: message,
    status: status,
    statusName: statusName,
    statusTone: statusTone,
    buyerName: buyerName,
    buyerPhone: buyerPhone,
    sellerName: sellerName,
    createdDate: createdDate.toLocal(),
    respondedAt: respondedAt?.toLocal(),
  );
}

@JsonSerializable(createToJson: false)
class MarketplaceB2BRequestPageModel {
  const MarketplaceB2BRequestPageModel({
    required this.items,
    required this.totalCount,
    this.counts = const [],
  });

  factory MarketplaceB2BRequestPageModel.fromJson(Map<String, dynamic> json) =>
      _$MarketplaceB2BRequestPageModelFromJson(json);

  final List<MarketplaceB2BRequestModel> items;
  final int totalCount;
  final List<MarketplaceStatusCountModel> counts;

  MarketplaceB2BRequestPage toEntity() => MarketplaceB2BRequestPage(
    items: [for (final r in items) r.toEntity()],
    totalCount: totalCount,
    counts: [for (final c in counts) c.toEntity()],
  );
}

@JsonSerializable(createToJson: false)
class MarketplacePaymentSettingsModel {
  const MarketplacePaymentSettingsModel({
    required this.acceptsCashOnDelivery,
    required this.acceptsOnlinePay,
    this.onlinePayAvailable = true,
  });

  factory MarketplacePaymentSettingsModel.fromJson(Map<String, dynamic> json) =>
      _$MarketplacePaymentSettingsModelFromJson(json);

  final bool acceptsCashOnDelivery;
  final bool acceptsOnlinePay;
  final bool onlinePayAvailable;

  MarketplacePaymentSettings toEntity() => MarketplacePaymentSettings(
    acceptsCashOnDelivery: acceptsCashOnDelivery,
    acceptsOnlinePay: acceptsOnlinePay,
    onlinePayAvailable: onlinePayAvailable,
  );
}

@JsonSerializable(createToJson: false)
class MarketplaceCourierModel {
  const MarketplaceCourierModel({
    required this.code,
    required this.name,
    this.takesCustomName = false,
    this.hasTrackingLink = false,
  });

  factory MarketplaceCourierModel.fromJson(Map<String, dynamic> json) =>
      _$MarketplaceCourierModelFromJson(json);

  final String code;
  final String name;
  final bool takesCustomName;
  final bool hasTrackingLink;

  MarketplaceCourier toEntity() => MarketplaceCourier(
    code: code,
    name: name,
    takesCustomName: takesCustomName,
    hasTrackingLink: hasTrackingLink,
  );
}
