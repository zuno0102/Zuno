// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'marketplace_order_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MarketplaceOrderActionModel _$MarketplaceOrderActionModelFromJson(
  Map<String, dynamic> json,
) => MarketplaceOrderActionModel(
  toStatus: json['toStatus'] as String,
  name: json['name'] as String,
  needsConfirm: json['needsConfirm'] as bool? ?? false,
  needsTracking: json['needsTracking'] as bool? ?? false,
);

MarketplaceOrderEventModel _$MarketplaceOrderEventModelFromJson(
  Map<String, dynamic> json,
) => MarketplaceOrderEventModel(
  status: json['status'] as String,
  statusName: json['statusName'] as String,
  actor: json['actor'] as String,
  at: DateTime.parse(json['at'] as String),
  note: json['note'] as String?,
);

MarketplaceOrderModel _$MarketplaceOrderModelFromJson(
  Map<String, dynamic> json,
) => MarketplaceOrderModel(
  id: json['id'] as String,
  number: json['number'] as String,
  postId: json['postId'] as String,
  title: json['title'] as String,
  quantity: (json['quantity'] as num).toInt(),
  unitPrice: (json['unitPrice'] as num).toDouble(),
  amount: (json['amount'] as num).toDouble(),
  paymentMethod: json['paymentMethod'] as String,
  paymentMethodName: json['paymentMethodName'] as String,
  isPaid: json['isPaid'] as bool,
  status: json['status'] as String,
  statusName: json['statusName'] as String,
  statusTone: json['statusTone'] as String,
  customerName: json['customerName'] as String,
  customerPhone: json['customerPhone'] as String,
  deliveryAddress: json['deliveryAddress'] as String,
  pincode: json['pincode'] as String,
  createdDate: DateTime.parse(json['createdDate'] as String),
  variantName: json['variantName'] as String?,
  imageUrl: json['imageUrl'] as String?,
  paidAt: json['paidAt'] == null
      ? null
      : DateTime.parse(json['paidAt'] as String),
  dueToBusiness: (json['dueToBusiness'] as num?)?.toDouble() ?? 0,
  refundDue: json['refundDue'] as bool? ?? false,
  refunded: json['refunded'] as bool? ?? false,
  courierCode: json['courierCode'] as String?,
  courierName: json['courierName'] as String?,
  trackingNumber: json['trackingNumber'] as String?,
  trackingUrl: json['trackingUrl'] as String?,
  receiptUrl: json['receiptUrl'] as String?,
  payBy: json['payBy'] == null ? null : DateTime.parse(json['payBy'] as String),
  shippedAt: json['shippedAt'] == null
      ? null
      : DateTime.parse(json['shippedAt'] as String),
  deliveredAt: json['deliveredAt'] == null
      ? null
      : DateTime.parse(json['deliveredAt'] as String),
  closesAt: json['closesAt'] == null
      ? null
      : DateTime.parse(json['closesAt'] as String),
  closedAt: json['closedAt'] == null
      ? null
      : DateTime.parse(json['closedAt'] as String),
  cancelledAt: json['cancelledAt'] == null
      ? null
      : DateTime.parse(json['cancelledAt'] as String),
  cancelledBy: json['cancelledBy'] as String?,
  ratingScore: (json['ratingScore'] as num?)?.toInt(),
  ratingComment: json['ratingComment'] as String?,
  actions:
      (json['actions'] as List<dynamic>?)
          ?.map(
            (e) =>
                MarketplaceOrderActionModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  events:
      (json['events'] as List<dynamic>?)
          ?.map(
            (e) =>
                MarketplaceOrderEventModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  sellerName: json['sellerName'] as String?,
  track:
      (json['track'] as List<dynamic>?)
          ?.map(
            (e) =>
                MarketplaceTrackStepModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);

MarketplaceTrackStepModel _$MarketplaceTrackStepModelFromJson(
  Map<String, dynamic> json,
) => MarketplaceTrackStepModel(
  name: json['name'] as String,
  reachedAt: json['reachedAt'] == null
      ? null
      : DateTime.parse(json['reachedAt'] as String),
);

MarketplaceStatusCountModel _$MarketplaceStatusCountModelFromJson(
  Map<String, dynamic> json,
) => MarketplaceStatusCountModel(
  status: json['status'] as String,
  count: (json['count'] as num).toInt(),
  name: json['name'] as String?,
  tone: json['tone'] as String?,
);

MarketplaceOrderPageModel _$MarketplaceOrderPageModelFromJson(
  Map<String, dynamic> json,
) => MarketplaceOrderPageModel(
  items: (json['items'] as List<dynamic>)
      .map((e) => MarketplaceOrderModel.fromJson(e as Map<String, dynamic>))
      .toList(),
  totalCount: (json['totalCount'] as num).toInt(),
  counts:
      (json['counts'] as List<dynamic>?)
          ?.map(
            (e) =>
                MarketplaceStatusCountModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);

MarketplaceB2BRequestModel _$MarketplaceB2BRequestModelFromJson(
  Map<String, dynamic> json,
) => MarketplaceB2BRequestModel(
  id: json['id'] as String,
  number: json['number'] as String,
  postId: json['postId'] as String,
  title: json['title'] as String,
  quantity: (json['quantity'] as num).toInt(),
  status: json['status'] as String,
  statusName: json['statusName'] as String,
  statusTone: json['statusTone'] as String,
  buyerName: json['buyerName'] as String,
  createdDate: DateTime.parse(json['createdDate'] as String),
  unit: json['unit'] as String?,
  unitPrice: (json['unitPrice'] as num?)?.toDouble(),
  total: (json['total'] as num?)?.toDouble(),
  minOrderQuantity: (json['minOrderQuantity'] as num?)?.toInt(),
  message: json['message'] as String?,
  buyerPhone: json['buyerPhone'] as String?,
  sellerName: json['sellerName'] as String?,
  sellerPhone: json['sellerPhone'] as String?,
  contactNeedsPlan: json['contactNeedsPlan'] as bool? ?? false,
  respondedAt: json['respondedAt'] == null
      ? null
      : DateTime.parse(json['respondedAt'] as String),
);

MarketplaceB2BRequestPageModel _$MarketplaceB2BRequestPageModelFromJson(
  Map<String, dynamic> json,
) => MarketplaceB2BRequestPageModel(
  items: (json['items'] as List<dynamic>)
      .map(
        (e) => MarketplaceB2BRequestModel.fromJson(e as Map<String, dynamic>),
      )
      .toList(),
  totalCount: (json['totalCount'] as num).toInt(),
  counts:
      (json['counts'] as List<dynamic>?)
          ?.map(
            (e) =>
                MarketplaceStatusCountModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);

MarketplacePaymentSettingsModel _$MarketplacePaymentSettingsModelFromJson(
  Map<String, dynamic> json,
) => MarketplacePaymentSettingsModel(
  acceptsCashOnDelivery: json['acceptsCashOnDelivery'] as bool,
  acceptsOnlinePay: json['acceptsOnlinePay'] as bool,
  onlinePayAvailable: json['onlinePayAvailable'] as bool? ?? true,
);

MarketplaceCourierModel _$MarketplaceCourierModelFromJson(
  Map<String, dynamic> json,
) => MarketplaceCourierModel(
  code: json['code'] as String,
  name: json['name'] as String,
  takesCustomName: json['takesCustomName'] as bool? ?? false,
  hasTrackingLink: json['hasTrackingLink'] as bool? ?? false,
);

MarketplaceCheckoutModel _$MarketplaceCheckoutModelFromJson(
  Map<String, dynamic> json,
) => MarketplaceCheckoutModel(
  providerOrderId: json['providerOrderId'] as String,
  keyId: json['keyId'] as String,
  amount: (json['amount'] as num).toDouble(),
  description: json['description'] as String,
  nothingToCollect: json['nothingToCollect'] as bool? ?? false,
);
