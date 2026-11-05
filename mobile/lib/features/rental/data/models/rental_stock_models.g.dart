// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rental_stock_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RentalStockLineModel _$RentalStockLineModelFromJson(
  Map<String, dynamic> json,
) => RentalStockLineModel(
  rentalItemId: json['rentalItemId'] as String,
  name: json['name'] as String,
  rentalCategoryName: json['rentalCategoryName'] as String,
  isAvailable: json['isAvailable'] as bool,
  quantityTotal: (json['quantityTotal'] as num).toInt(),
  quantityOut: (json['quantityOut'] as num).toInt(),
  quantityIn: (json['quantityIn'] as num).toInt(),
  quantityBooked: (json['quantityBooked'] as num?)?.toInt() ?? 0,
  rentalSubCategoryName: json['rentalSubCategoryName'] as String?,
  imageUrl: json['imageUrl'] as String?,
);

RentalStockPageModel _$RentalStockPageModelFromJson(
  Map<String, dynamic> json,
) => RentalStockPageModel(
  items: (json['items'] as List<dynamic>)
      .map((e) => RentalStockLineModel.fromJson(e as Map<String, dynamic>))
      .toList(),
  totalCount: (json['totalCount'] as num).toInt(),
);

RentalOrderActionModel _$RentalOrderActionModelFromJson(
  Map<String, dynamic> json,
) => RentalOrderActionModel(
  toStatus: json['toStatus'] as String,
  label: json['label'] as String,
  confirmFirst: json['confirmFirst'] as bool? ?? false,
  disabledReason: json['disabledReason'] as String?,
);

RentalOrderAnswerModel _$RentalOrderAnswerModelFromJson(
  Map<String, dynamic> json,
) => RentalOrderAnswerModel(
  prompt: json['prompt'] as String,
  answer: json['answer'] as String,
);

RentalOrderAddOnModel _$RentalOrderAddOnModelFromJson(
  Map<String, dynamic> json,
) => RentalOrderAddOnModel(
  id: json['id'] as String,
  quantity: (json['quantity'] as num).toInt(),
  statusName: json['statusName'] as String,
  statusTone: json['statusTone'] as String,
);

RentalOrderEventModel _$RentalOrderEventModelFromJson(
  Map<String, dynamic> json,
) => RentalOrderEventModel(
  id: json['id'] as String,
  at: DateTime.parse(json['at'] as String),
  title: json['title'] as String,
  tone: json['tone'] as String,
  quantity: (json['quantity'] as num).toInt(),
  onAddOn: json['onAddOn'] as bool? ?? false,
  relatedOrderId: json['relatedOrderId'] as String?,
  amount: (json['amount'] as num?)?.toDouble(),
  paymentMethodName: json['paymentMethodName'] as String?,
);

RentalAvailabilityModel _$RentalAvailabilityModelFromJson(
  Map<String, dynamic> json,
) => RentalAvailabilityModel(
  total: (json['total'] as num).toInt(),
  held: (json['held'] as num).toInt(),
  available: (json['available'] as num).toInt(),
);

RentalOrderModel _$RentalOrderModelFromJson(
  Map<String, dynamic> json,
) => RentalOrderModel(
  id: json['id'] as String,
  customerName: json['customerName'] as String,
  quantity: (json['quantity'] as num).toInt(),
  startDate: DateTime.parse(json['startDate'] as String),
  endDate: DateTime.parse(json['endDate'] as String),
  deliveryAddress: json['deliveryAddress'] as String,
  status: json['status'] as String,
  statusName: json['statusName'] as String,
  statusTone: json['statusTone'] as String,
  isOut: json['isOut'] as bool,
  rentalItemId: json['rentalItemId'] as String? ?? '',
  itemName: json['itemName'] as String? ?? '',
  customerPhone: json['customerPhone'] as String?,
  districtName: json['districtName'] as String?,
  unreadMessages: (json['unreadMessages'] as num?)?.toInt() ?? 0,
  actions:
      (json['actions'] as List<dynamic>?)
          ?.map(
            (e) => RentalOrderActionModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  parentOrderId: json['parentOrderId'] as String?,
  addOns:
      (json['addOns'] as List<dynamic>?)
          ?.map(
            (e) => RentalOrderAddOnModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  canAddPieces: json['canAddPieces'] as bool? ?? false,
  businessName: json['businessName'] as String?,
  source: json['source'] as String? ?? '',
  answers:
      (json['answers'] as List<dynamic>?)
          ?.map(
            (e) => RentalOrderAnswerModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  priceType: json['priceType'] as String? ?? '',
  unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
  units: (json['units'] as num?)?.toInt() ?? 1,
  amount: (json['amount'] as num?)?.toDouble() ?? 0,
  advanceDue: (json['advanceDue'] as num?)?.toDouble() ?? 0,
  paid: (json['paid'] as num?)?.toDouble() ?? 0,
  balance: (json['balance'] as num?)?.toDouble() ?? 0,
  paymentStatus: json['paymentStatus'] as String?,
  paymentStatusName: json['paymentStatusName'] as String?,
  paymentStatusTone: json['paymentStatusTone'] as String?,
  payments:
      (json['payments'] as List<dynamic>?)
          ?.map(
            (e) => RentalOrderPaymentModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  holdUntil: json['holdUntil'] == null
      ? null
      : DateTime.parse(json['holdUntil'] as String),
  payNowAmount: (json['payNowAmount'] as num?)?.toDouble() ?? 0,
  canCollect: json['canCollect'] as bool? ?? false,
  canRefund: json['canRefund'] as bool? ?? false,
  canPayOnline: json['canPayOnline'] as bool? ?? false,
  upiId: json['upiId'] as String?,
  cancelSteps:
      (json['cancelSteps'] as List<dynamic>?)
          ?.map(
            (e) => RentalCancelStepModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  cancelUnit: json['cancelUnit'] as String? ?? RentalCancelUnit.day,
  cancelledBy: json['cancelledBy'] as String?,
  cancellationCharge: (json['cancellationCharge'] as num?)?.toDouble() ?? 0,
  refundOwed: (json['refundOwed'] as num?)?.toDouble() ?? 0,
  refundMode: json['refundMode'] as String?,
  refundModeName: json['refundModeName'] as String?,
  refundModeText: json['refundModeText'] as String?,
  canChooseRefundMode: json['canChooseRefundMode'] as bool? ?? false,
  refundModes:
      (json['refundModes'] as List<dynamic>?)
          ?.map(
            (e) =>
                RentalRefundModeChoiceModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  needsRefund: json['needsRefund'] as bool? ?? false,
  cancelChargeType:
      json['cancelChargeType'] as String? ?? RentalCancelChargeType.byTimeLeft,
  cancelPercentPerDay: (json['cancelPercentPerDay'] as num?)?.toDouble(),
  cancelPercentCap: (json['cancelPercentCap'] as num?)?.toDouble() ?? 0,
  canRate: json['canRate'] as bool? ?? false,
  myRating: (json['myRating'] as num?)?.toInt(),
  myRatingComment: json['myRatingComment'] as String?,
  customerRating: (json['customerRating'] as num?)?.toInt(),
  customerRatingComment: json['customerRatingComment'] as String?,
);

RentalOrderPageModel _$RentalOrderPageModelFromJson(
  Map<String, dynamic> json,
) => RentalOrderPageModel(
  items: (json['items'] as List<dynamic>)
      .map((e) => RentalOrderModel.fromJson(e as Map<String, dynamic>))
      .toList(),
  totalCount: (json['totalCount'] as num).toInt(),
);

RentalOrderStatusCountModel _$RentalOrderStatusCountModelFromJson(
  Map<String, dynamic> json,
) => RentalOrderStatusCountModel(
  status: json['status'] as String,
  name: json['name'] as String,
  tone: json['tone'] as String,
  count: (json['count'] as num).toInt(),
  countsInAll: json['countsInAll'] as bool? ?? true,
);

RentalOrderThreadModel _$RentalOrderThreadModelFromJson(
  Map<String, dynamic> json,
) => RentalOrderThreadModel(
  rentalOrderId: json['rentalOrderId'] as String,
  customerName: json['customerName'] as String,
  itemName: json['itemName'] as String,
  quantity: (json['quantity'] as num).toInt(),
  lastMessage: json['lastMessage'] as String,
  lastMessageAt: DateTime.parse(json['lastMessageAt'] as String),
  lastFromCustomer: json['lastFromCustomer'] as bool,
  unreadCount: (json['unreadCount'] as num).toInt(),
  businessName: json['businessName'] as String?,
);

RentalOrderMessageModel _$RentalOrderMessageModelFromJson(
  Map<String, dynamic> json,
) => RentalOrderMessageModel(
  id: json['id'] as String,
  rentalOrderId: json['rentalOrderId'] as String,
  senderRole: json['senderRole'] as String,
  isMine: json['isMine'] as bool,
  senderName: json['senderName'] as String,
  body: json['body'] as String,
  sentAt: DateTime.parse(json['sentAt'] as String),
  readAt: json['readAt'] == null
      ? null
      : DateTime.parse(json['readAt'] as String),
);

RentalOrderPaymentModel _$RentalOrderPaymentModelFromJson(
  Map<String, dynamic> json,
) => RentalOrderPaymentModel(
  id: json['id'] as String,
  at: DateTime.parse(json['at'] as String),
  kind: json['kind'] as String,
  methodName: json['methodName'] as String,
  amount: (json['amount'] as num).toDouble(),
  reference: json['reference'] as String?,
);

RentalCheckoutModel _$RentalCheckoutModelFromJson(Map<String, dynamic> json) =>
    RentalCheckoutModel(
      providerOrderId: json['providerOrderId'] as String,
      keyId: json['keyId'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String,
      nothingToCollect: json['nothingToCollect'] as bool? ?? false,
    );

RentalPaymentOptionModel _$RentalPaymentOptionModelFromJson(
  Map<String, dynamic> json,
) => RentalPaymentOptionModel(
  code: json['code'] as String,
  name: json['name'] as String,
  detail: json['detail'] as String? ?? '',
);

RentalPaymentOptionsModel _$RentalPaymentOptionsModelFromJson(
  Map<String, dynamic> json,
) => RentalPaymentOptionsModel(
  advanceTypes:
      (json['advanceTypes'] as List<dynamic>?)
          ?.map(
            (e) => RentalPaymentOptionModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  methods:
      (json['methods'] as List<dynamic>?)
          ?.map(
            (e) => RentalPaymentOptionModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  cancelChargeTypes:
      (json['cancelChargeTypes'] as List<dynamic>?)
          ?.map(
            (e) => RentalPaymentOptionModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);

RentalRefundModeChoiceModel _$RentalRefundModeChoiceModelFromJson(
  Map<String, dynamic> json,
) => RentalRefundModeChoiceModel(
  code: json['code'] as String,
  name: json['name'] as String,
  text: json['text'] as String? ?? '',
  disabledReason: json['disabledReason'] as String?,
);

RentalCancelQuoteModel _$RentalCancelQuoteModelFromJson(
  Map<String, dynamic> json,
) => RentalCancelQuoteModel(
  unitsBefore: (json['unitsBefore'] as num).toInt(),
  unit: json['unit'] as String,
  percent: (json['percent'] as num).toDouble(),
  charge: (json['charge'] as num).toDouble(),
  paid: (json['paid'] as num).toDouble(),
  refund: (json['refund'] as num).toDouble(),
  refundModes:
      (json['refundModes'] as List<dynamic>?)
          ?.map(
            (e) =>
                RentalRefundModeChoiceModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  basis: json['basis'] as String? ?? RentalCancelChargeType.byTimeLeft,
  rentalUnits: (json['rentalUnits'] as num?)?.toInt() ?? 1,
);
