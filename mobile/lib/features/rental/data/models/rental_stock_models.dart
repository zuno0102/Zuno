import 'package:json_annotation/json_annotation.dart';
import 'package:zuno/features/booking/domain/entities/booking_message.dart';
import 'package:zuno/features/rental/domain/entities/rental_payment.dart';
import 'package:zuno/features/rental/domain/entities/rental_stock.dart';

part 'rental_stock_models.g.dart';

@JsonSerializable(createToJson: false)
class RentalStockLineModel {
  const RentalStockLineModel({
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

  factory RentalStockLineModel.fromJson(Map<String, dynamic> json) =>
      _$RentalStockLineModelFromJson(json);

  final String rentalItemId;
  final String name;
  final String rentalCategoryName;
  final String? rentalSubCategoryName;
  final bool isAvailable;
  final int quantityTotal;
  final int quantityOut;
  final int quantityIn;
  final int quantityBooked;
  final String? imageUrl;

  RentalStockLine toEntity() => RentalStockLine(
    rentalItemId: rentalItemId,
    name: name,
    rentalCategoryName: rentalCategoryName,
    rentalSubCategoryName: rentalSubCategoryName,
    isAvailable: isAvailable,
    quantityTotal: quantityTotal,
    quantityOut: quantityOut,
    quantityIn: quantityIn,
    quantityBooked: quantityBooked,
    imageUrl: imageUrl,
  );
}

@JsonSerializable(createToJson: false)
class RentalStockPageModel {
  const RentalStockPageModel({required this.items, required this.totalCount});

  factory RentalStockPageModel.fromJson(Map<String, dynamic> json) =>
      _$RentalStockPageModelFromJson(json);

  final List<RentalStockLineModel> items;
  final int totalCount;
}

@JsonSerializable(createToJson: false)
class RentalOrderActionModel {
  const RentalOrderActionModel({
    required this.toStatus,
    required this.label,
    this.confirmFirst = false,
    this.disabledReason,
  });

  factory RentalOrderActionModel.fromJson(Map<String, dynamic> json) =>
      _$RentalOrderActionModelFromJson(json);

  final String toStatus;
  final String label;
  final bool confirmFirst;
  final String? disabledReason;

  RentalOrderAction toEntity() => RentalOrderAction(
    toStatus: toStatus,
    label: label,
    confirmFirst: confirmFirst,
    disabledReason: disabledReason,
  );
}

@JsonSerializable(createToJson: false)
class RentalOrderAnswerModel {
  const RentalOrderAnswerModel({required this.prompt, required this.answer});

  factory RentalOrderAnswerModel.fromJson(Map<String, dynamic> json) =>
      _$RentalOrderAnswerModelFromJson(json);

  final String prompt;
  final String answer;

  RentalOrderAnswer toEntity() =>
      RentalOrderAnswer(prompt: prompt, answer: answer);
}

@JsonSerializable(createToJson: false)
class RentalOrderAddOnModel {
  const RentalOrderAddOnModel({
    required this.id,
    required this.quantity,
    required this.statusName,
    required this.statusTone,
  });

  factory RentalOrderAddOnModel.fromJson(Map<String, dynamic> json) =>
      _$RentalOrderAddOnModelFromJson(json);

  final String id;
  final int quantity;
  final String statusName;
  final String statusTone;

  RentalOrderAddOn toEntity() => RentalOrderAddOn(
    id: id,
    quantity: quantity,
    statusName: statusName,
    statusTone: statusTone,
  );
}

@JsonSerializable(createToJson: false)
class RentalOrderEventModel {
  const RentalOrderEventModel({
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

  factory RentalOrderEventModel.fromJson(Map<String, dynamic> json) =>
      _$RentalOrderEventModelFromJson(json);

  final String id;
  final DateTime at;
  final String title;
  final String tone;
  final int quantity;
  final bool onAddOn;
  final String? relatedOrderId;
  final double? amount;
  final String? paymentMethodName;

  RentalOrderEvent toEntity() => RentalOrderEvent(
    id: id,
    at: at.toLocal(),
    title: title,
    tone: tone,
    quantity: quantity,
    onAddOn: onAddOn,
    relatedOrderId: relatedOrderId,
    amount: amount,
    paymentMethodName: paymentMethodName,
  );
}

@JsonSerializable(createToJson: false)
class RentalAvailabilityModel {
  const RentalAvailabilityModel({
    required this.total,
    required this.held,
    required this.available,
  });

  factory RentalAvailabilityModel.fromJson(Map<String, dynamic> json) =>
      _$RentalAvailabilityModelFromJson(json);

  final int total;
  final int held;
  final int available;

  RentalAvailability toEntity() =>
      RentalAvailability(total: total, held: held, available: available);
}

@JsonSerializable(createToJson: false)
class RentalOrderModel {
  const RentalOrderModel({
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

  factory RentalOrderModel.fromJson(Map<String, dynamic> json) =>
      _$RentalOrderModelFromJson(json);

  final String id;
  final String rentalItemId;
  final String itemName;
  final String customerName;
  final String? customerPhone;
  final int quantity;
  final DateTime startDate;
  final DateTime endDate;
  final String deliveryAddress;
  final String? districtName;
  final String status;
  final String statusName;
  final String statusTone;
  final bool isOut;
  final int unreadMessages;
  final List<RentalOrderActionModel> actions;
  final String? parentOrderId;
  final List<RentalOrderAddOnModel> addOns;
  final bool canAddPieces;
  final String? businessName;
  final String source;
  final List<RentalOrderAnswerModel> answers;
  final String priceType;
  final double unitPrice;
  final int units;
  final double amount;
  final double advanceDue;
  final double paid;
  final double balance;
  final String? paymentStatus;
  final String? paymentStatusName;
  final String? paymentStatusTone;
  final List<RentalOrderPaymentModel> payments;
  final DateTime? holdUntil;
  final double payNowAmount;
  final bool canCollect;
  final bool canRefund;
  final bool canPayOnline;
  final String? upiId;

  RentalOrder toEntity() => RentalOrder(
    id: id,
    rentalItemId: rentalItemId,
    itemName: itemName,
    customerName: customerName,
    customerPhone: customerPhone,
    quantity: quantity,
    // Shown as the business's local dates.
    startDate: startDate.toLocal(),
    endDate: endDate.toLocal(),
    deliveryAddress: deliveryAddress,
    districtName: districtName,
    status: status,
    statusName: statusName,
    statusTone: statusTone,
    isOut: isOut,
    unreadMessages: unreadMessages,
    actions: actions.map((a) => a.toEntity()).toList(),
    parentOrderId: parentOrderId,
    addOns: addOns.map((a) => a.toEntity()).toList(),
    canAddPieces: canAddPieces,
    businessName: businessName,
    source: source,
    answers: answers.map((a) => a.toEntity()).toList(),
    priceType: priceType,
    unitPrice: unitPrice,
    units: units,
    amount: amount,
    advanceDue: advanceDue,
    paid: paid,
    balance: balance,
    paymentStatus: paymentStatus,
    paymentStatusName: paymentStatusName,
    paymentStatusTone: paymentStatusTone,
    payments: payments.map((p) => p.toEntity()).toList(),
    holdUntil: holdUntil?.toLocal(),
    payNowAmount: payNowAmount,
    canCollect: canCollect,
    canRefund: canRefund,
    canPayOnline: canPayOnline,
    upiId: upiId,
  );
}

@JsonSerializable(createToJson: false)
class RentalOrderPageModel {
  const RentalOrderPageModel({required this.items, required this.totalCount});

  factory RentalOrderPageModel.fromJson(Map<String, dynamic> json) =>
      _$RentalOrderPageModelFromJson(json);

  final List<RentalOrderModel> items;
  final int totalCount;
}

@JsonSerializable(createToJson: false)
class RentalOrderStatusCountModel {
  const RentalOrderStatusCountModel({
    required this.status,
    required this.name,
    required this.tone,
    required this.count,
  });

  factory RentalOrderStatusCountModel.fromJson(Map<String, dynamic> json) =>
      _$RentalOrderStatusCountModelFromJson(json);

  final String status;
  final String name;
  final String tone;
  final int count;

  RentalOrderStatusCount toEntity() => RentalOrderStatusCount(
    status: status,
    name: name,
    tone: tone,
    count: count,
  );
}

@JsonSerializable(createToJson: false)
class RentalOrderThreadModel {
  const RentalOrderThreadModel({
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

  factory RentalOrderThreadModel.fromJson(Map<String, dynamic> json) =>
      _$RentalOrderThreadModelFromJson(json);

  final String rentalOrderId;
  final String customerName;
  final String itemName;
  final int quantity;
  final String lastMessage;
  final DateTime lastMessageAt;
  final bool lastFromCustomer;
  final int unreadCount;
  final String? businessName;

  RentalOrderThread toEntity() => RentalOrderThread(
    rentalOrderId: rentalOrderId,
    customerName: customerName,
    itemName: itemName,
    quantity: quantity,
    lastMessage: lastMessage,
    lastMessageAt: lastMessageAt.toLocal(),
    lastFromCustomer: lastFromCustomer,
    unreadCount: unreadCount,
    businessName: businessName,
  );
}

@JsonSerializable(createToJson: false)
class RentalOrderMessageModel {
  const RentalOrderMessageModel({
    required this.id,
    required this.rentalOrderId,
    required this.senderRole,
    required this.isMine,
    required this.senderName,
    required this.body,
    required this.sentAt,
    this.readAt,
  });

  factory RentalOrderMessageModel.fromJson(Map<String, dynamic> json) =>
      _$RentalOrderMessageModelFromJson(json);

  final String id;
  final String rentalOrderId;
  final String senderRole;
  final bool isMine;
  final String senderName;
  final String body;
  final DateTime sentAt;
  final DateTime? readAt;

  /// As the app's shared chat screen draws messages — the same bubbles as a service chat. The rent
  /// order's id stands where a booking's would.
  BookingMessage toEntity() => BookingMessage(
    id: id,
    bookingId: rentalOrderId,
    senderRole: senderRole,
    isMine: isMine,
    senderName: senderName,
    body: body,
    sentAt: sentAt.toLocal(),
    readAt: readAt?.toLocal(),
  );
}

@JsonSerializable(createToJson: false)
class RentalOrderPaymentModel {
  const RentalOrderPaymentModel({
    required this.id,
    required this.at,
    required this.kind,
    required this.methodName,
    required this.amount,
  });

  factory RentalOrderPaymentModel.fromJson(Map<String, dynamic> json) =>
      _$RentalOrderPaymentModelFromJson(json);

  final String id;
  final DateTime at;
  final String kind;
  final String methodName;
  final double amount;

  RentalOrderPayment toEntity() => RentalOrderPayment(
    id: id,
    at: at.toLocal(),
    kind: kind,
    methodName: methodName,
    amount: amount,
  );
}

@JsonSerializable(createToJson: false)
class RentalCheckoutModel {
  const RentalCheckoutModel({
    required this.providerOrderId,
    required this.keyId,
    required this.amount,
    required this.description,
    this.nothingToCollect = false,
  });

  factory RentalCheckoutModel.fromJson(Map<String, dynamic> json) =>
      _$RentalCheckoutModelFromJson(json);

  final String providerOrderId;
  final String keyId;
  final double amount;
  final String description;
  final bool nothingToCollect;

  RentalCheckout toEntity() => RentalCheckout(
    providerOrderId: providerOrderId,
    keyId: keyId,
    amount: amount,
    description: description,
    nothingToCollect: nothingToCollect,
  );
}

@JsonSerializable(createToJson: false)
class RentalPaymentOptionModel {
  const RentalPaymentOptionModel({
    required this.code,
    required this.name,
    this.detail = '',
  });

  factory RentalPaymentOptionModel.fromJson(Map<String, dynamic> json) =>
      _$RentalPaymentOptionModelFromJson(json);

  final String code;
  final String name;
  final String detail;

  RentalPaymentOption toEntity() =>
      RentalPaymentOption(code: code, name: name, detail: detail);
}

@JsonSerializable(createToJson: false)
class RentalPaymentOptionsModel {
  const RentalPaymentOptionsModel({
    this.advanceTypes = const [],
    this.methods = const [],
  });

  factory RentalPaymentOptionsModel.fromJson(Map<String, dynamic> json) =>
      _$RentalPaymentOptionsModelFromJson(json);

  final List<RentalPaymentOptionModel> advanceTypes;
  final List<RentalPaymentOptionModel> methods;

  RentalPaymentOptions toEntity() => RentalPaymentOptions(
    advanceTypes: advanceTypes.map((o) => o.toEntity()).toList(),
    methods: methods.map((o) => o.toEntity()).toList(),
  );
}
