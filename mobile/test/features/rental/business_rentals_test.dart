import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:zuno/core/payments/upi_pay.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/business_owner/domain/entities/business_profile.dart';
import 'package:zuno/features/business_owner/domain/entities/business_service.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_profile_notifier.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_services_notifier.dart';
import 'package:zuno/features/catalog/domain/entities/app_options.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/features/rental/domain/entities/rental_item.dart';
import 'package:zuno/features/rental/domain/entities/rental_payment.dart';
import 'package:zuno/features/rental/domain/rental_repository.dart';
import 'package:zuno/features/rental/presentation/providers/rental_payment_providers.dart';
import 'package:zuno/features/rental/presentation/providers/rental_providers.dart';
import 'package:zuno/features/rental/presentation/screens/business_catalog_tab.dart';
import 'package:zuno/features/rental/presentation/screens/business_rentals_tab.dart';
import 'package:zuno/features/booking/domain/entities/booking_message.dart';
import 'package:zuno/features/booking/presentation/screens/booking_chat_screen.dart';
import 'package:zuno/features/rental/domain/entities/rental_stock.dart';
import 'package:zuno/features/rental/presentation/screens/business_orders_hub_tab.dart';
import 'package:zuno/features/rental/presentation/screens/business_rent_orders_tab.dart';
import 'package:zuno/features/rental/presentation/screens/rental_stock_item_screen.dart';
import 'package:zuno/features/rental/presentation/screens/rental_stock_screen.dart';
import 'package:zuno/features/rental/presentation/widgets/rent_dashboard_tiles.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_cancel_steps_section.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_collect_sheet.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_order_actions.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_item_form_sheet.dart';
import 'package:zuno/shared/domain/upi_id.dart';
import 'package:zuno/shared/widgets/stat_tile.dart';

const _tools = RentalCategory(
  id: 'cat-tools',
  name: 'Tools & machines',
  subCategories: [
    RentalSubCategory(id: 'sub-cutting', name: 'Cutting machine'),
  ],
);
const _furniture = RentalCategory(
  id: 'cat-furniture',
  name: 'Furniture & seating',
  maxCancelPercent: 5,
  subCategories: [
    RentalSubCategory(
      id: 'sub-chairs',
      name: 'Plastic chairs',
      maxCancelPercent: 2,
    ),
  ],
);

const _ernakulam = RentalItemDistrict(
  id: 'd-ekm',
  name: 'Ernakulam',
  stateId: 's-kl',
  stateName: 'Kerala',
);

/// The Rent server's advance and payment-method tables, as they are seeded.
const _paymentOptions = RentalPaymentOptions(
  advanceTypes: [
    RentalPaymentOption(
      code: RentalAdvanceType.none,
      name: 'No advance',
      detail: 'Everything is paid before the pieces come back',
    ),
    RentalPaymentOption(
      code: RentalAdvanceType.perOrder,
      name: 'Fixed for the order',
      detail: 'One amount, e.g. ₹500 for any number of pieces',
    ),
    RentalPaymentOption(
      code: RentalAdvanceType.perPiece,
      name: 'Per piece',
      detail: 'An amount for each piece, e.g. ₹2 a chair',
    ),
  ],
  methods: [
    RentalPaymentOption(code: RentalPaymentMethod.upiQr, name: 'UPI QR'),
    RentalPaymentOption(code: RentalPaymentMethod.cash, name: 'Cash'),
  ],
  cancelChargeTypes: [
    RentalPaymentOption(
      code: RentalCancelChargeType.byTimeLeft,
      name: 'By time left',
      detail:
          'More as the start comes closer, e.g. 5+ days 0.5%, on the day 2%',
    ),
    RentalPaymentOption(
      code: RentalCancelChargeType.perRentalDay,
      name: 'Per rental day',
      detail:
          'A percent for each day rented, e.g. 1% a day: a 2-day order costs 2%',
    ),
  ],
);

/// The Rent server's rate-type table, as it is seeded.
const _rates = [
  RentalPriceTypeOption(
    code: RentalPriceType.daily,
    name: 'Per day',
    detail: 'Charged for each day',
    unitSuffix: '/day',
  ),
  RentalPriceTypeOption(
    code: RentalPriceType.fixed,
    name: 'Per item',
    detail: 'One price for each item',
    unitSuffix: '/item',
  ),
  RentalPriceTypeOption(
    code: RentalPriceType.hourly,
    name: 'Per hour',
    detail: 'Charged by the hour',
    unitSuffix: '/hr',
  ),
];

RentalItem _item({
  String id = 'item-1',
  String name = 'Plastic chair',
  String priceType = RentalPriceType.daily,
  double price = 12,
  int quantity = 200,
  bool available = true,
  List<RentalItemQuestion> questions = const [],
  String advanceType = RentalAdvanceType.none,
  double? advanceAmount,
  List<RentalCancelStep> cancelSteps = const [],
  String cancelChargeType = RentalCancelChargeType.byTimeLeft,
  double? cancelPercentPerDay,
}) => RentalItem(
  cancelSteps: cancelSteps,
  cancelChargeType: cancelChargeType,
  cancelPercentPerDay: cancelPercentPerDay,
  id: id,
  rentalCategoryId: _furniture.id,
  rentalCategoryName: _furniture.name,
  rentalSubCategoryId: 'sub-chairs',
  rentalSubCategoryName: 'Plastic chairs',
  name: name,
  priceType: priceType,
  price: price,
  quantityOwned: quantity,
  isAvailable: available,
  districts: const [_ernakulam],
  questions: questions,
  advanceType: advanceType,
  advanceAmount: advanceAmount,
);

/// Stands in for the Rent server: keeps the items in memory and records every call.
class _FakeRentalRepository implements RentalRepository {
  _FakeRentalRepository(List<RentalItem> items) : items = [...items];

  final List<RentalItem> items;
  final orders = <String, List<RentalOrder>>{};
  final calls = <String>[];
  RentalItemInput? lastInput;
  Object? failList;

  @override
  Future<List<RentalCategory>> getCategories() async => const [
    _furniture,
    _tools,
  ];

  @override
  Future<List<RentalPriceTypeOption>> getPriceTypes() async => _rates;

  @override
  Future<List<RentalItem>> getMyItems({bool? isAvailable}) async {
    if (failList != null) throw failList!;
    return [
      for (final item in items)
        if (isAvailable == null || item.isAvailable == isAvailable) item,
    ];
  }

  @override
  Future<List<RentalStockLine>> getStock() async {
    if (failList != null) throw failList!;
    return [
      for (final item in [...items]..sort((a, b) => a.name.compareTo(b.name)))
        () {
          final out = (orders[item.id] ?? const <RentalOrder>[])
              .where((o) => o.isOut)
              .fold(0, (sum, o) => sum + o.quantity);
          final booked = (orders[item.id] ?? const <RentalOrder>[])
              .where((o) => o.status == 'Booked')
              .fold(0, (sum, o) => sum + o.quantity);
          return RentalStockLine(
            rentalItemId: item.id,
            name: item.name,
            rentalCategoryName: item.rentalCategoryName,
            isAvailable: item.isAvailable,
            quantityTotal: item.quantityOwned,
            quantityOut: out,
            quantityIn: item.quantityOwned - out,
            quantityBooked: booked,
          );
        }(),
    ];
  }

  @override
  Future<List<RentalOrder>> getItemOrders(String id) async =>
      orders[id] ?? const [];

  /// Customer and business messages per rent order, oldest first.
  final messages = <String, List<BookingMessage>>{};

  /// The transition table, as seeded on the server.
  static const _steps = {
    'Booked': [
      RentalOrderAction(toStatus: 'OnRent', label: 'Send out'),
      RentalOrderAction(
        toStatus: 'Cancelled',
        label: 'Cancel order',
        confirmFirst: true,
      ),
    ],
    'OnRent': [RentalOrderAction(toStatus: 'Returned', label: 'Mark returned')],
  };

  static const _names = {
    'Booked': ('Booked', 'progress'),
    'OnRent': ('On rent', 'danger'),
    'Returned': ('Returned', 'success'),
    'Cancelled': ('Cancelled', 'waiting'),
    'AwaitingAdvance': ('Awaiting advance', 'waiting'),
  };

  /// The order as the server would send it in [status]: its pieces, and its money — paid, what is
  /// still due, the payment standing, and "Mark returned" waiting while anything is due.
  RentalOrder _withState(
    RentalOrder o,
    String status, {
    double? paid,
    List<RentalOrderPayment>? payments,
    String? refundMode,
  }) {
    final paidNow = paid ?? o.paid;
    final lines = payments ?? o.payments;
    final mode = refundMode ?? o.refundMode;
    final owed = status == 'Cancelled'
        ? (paidNow - o.cancellationCharge).clamp(0, double.infinity).toDouble()
        : 0.0;
    final canChoose = owed > 0 && !lines.any((p) => p.isRefund);
    final balance = status == 'Cancelled'
        ? 0.0
        : (o.amount - paidNow).clamp(0, double.infinity).toDouble();
    final standing = !o.isPriced
        ? null
        : status == 'Cancelled'
        ? (owed > 0
              ? 'RefundDue'
              : lines.any((p) => p.isRefund)
              ? 'Refunded'
              : null)
        : paidNow >= o.amount
        ? 'Paid'
        : paidNow <= 0
        ? 'Unpaid'
        : paidNow == o.advanceDue
        ? 'AdvancePaid'
        : 'PartPaid';
    return RentalOrder(
      id: o.id,
      rentalItemId: o.rentalItemId,
      itemName: o.itemName,
      customerName: o.customerName,
      customerPhone: o.customerPhone,
      quantity: o.quantity,
      startDate: o.startDate,
      endDate: o.endDate,
      deliveryAddress: o.deliveryAddress,
      districtName: o.districtName,
      status: status,
      statusName: _names[status]!.$1,
      statusTone: _names[status]!.$2,
      isOut: status == 'OnRent',
      unreadMessages: (messages[o.id] ?? const [])
          .where((m) => !m.isMine && m.readAt == null)
          .length,
      actions: [
        for (final a in _steps[status] ?? const <RentalOrderAction>[])
          a.toStatus == 'Returned' && balance > 0
              ? RentalOrderAction(
                  toStatus: a.toStatus,
                  label: a.label,
                  disabledReason: 'Collect ${rupees(balance)} first',
                )
              : a,
      ],
      parentOrderId: o.parentOrderId,
      addOns: [
        for (final list in orders.values)
          for (final a in list)
            if (a.parentOrderId == o.id)
              RentalOrderAddOn(
                id: a.id,
                quantity: a.quantity,
                statusName: _names[a.status]!.$1,
                statusTone: _names[a.status]!.$2,
              ),
      ],
      canAddPieces: status == 'Booked' || status == 'OnRent',
      priceType: o.priceType,
      unitPrice: o.unitPrice,
      units: o.units,
      amount: o.amount,
      advanceDue: o.advanceDue,
      paid: paidNow,
      balance: balance,
      paymentStatus: standing,
      paymentStatusName: _paymentNames[standing],
      paymentStatusTone: standing == 'Paid' ? 'success' : 'progress',
      payments: payments ?? o.payments,
      payNowAmount: status == 'AwaitingAdvance'
          ? (o.advanceDue - paidNow).clamp(0, double.infinity).toDouble()
          : balance,
      canCollect: balance > 0 && status != 'Returned',
      canRefund: owed > 0 && mode != RentalRefundMode.online,
      upiId: upiId,
      cancelledBy: status == 'Cancelled' ? (o.cancelledBy ?? 'Business') : null,
      cancellationCharge: o.cancellationCharge,
      refundOwed: owed,
      refundMode: mode,
      refundModeName: _refundModes[mode]?.$1,
      refundModeText: _refundModes[mode]?.$2,
      canChooseRefundMode: canChoose,
      needsRefund: owed > 0 && mode != RentalRefundMode.online,
      refundModes: canChoose
          ? [
              for (final entry in _refundModes.entries)
                RentalRefundModeChoice(
                  code: entry.key,
                  name: entry.value.$1,
                  text: entry.value.$2,
                  disabledReason:
                      entry.key == RentalRefundMode.online &&
                          !lines.any((p) => p.methodName == 'Online')
                      ? 'The customer paid in cash or by UPI, so give the refund in hand.'
                      : null,
                ),
            ]
          : const [],
    );
  }

  static const _refundModes = {
    RentalRefundMode.online: (
      'Online',
      "Zuno sends it back to the customer's card or UPI. Nothing for you to hand over.",
    ),
    RentalRefundMode.inHand: (
      'In hand',
      'You give it back yourself, in cash or by UPI, then record it here.',
    ),
  };

  static const _paymentNames = {
    'Unpaid': 'Unpaid',
    'AdvancePaid': 'Advance paid',
    'PartPaid': 'Part paid',
    'Paid': 'Paid',
    'RefundDue': 'Refund due',
    'Refunded': 'Refunded',
  };

  /// The business's UPI ID, as payment settings hold it.
  String? upiId;

  @override
  Future<RentalPaymentOptions> getPaymentOptions() async => _paymentOptions;

  @override
  Future<String?> getUpiId() async => upiId;

  @override
  Future<RentalOrder> recordPayment(String id, RentalPaymentInput input) async {
    calls.add(
      'payment:$id:${input.method}:${input.amount.toStringAsFixed(0)}'
      '${input.isRefund ? ':refund' : ''}'
      '${input.payeeUpiId == null ? '' : ':to=${input.payeeUpiId}'}'
      '${input.reference == null ? '' : ':ref=${input.reference}'}',
    );
    for (final list in orders.values) {
      final index = list.indexWhere((o) => o.id == id);
      if (index >= 0) {
        final o = list[index];
        if (!input.isRefund && input.amount > o.balance) {
          throw Exception('Only ${rupees(o.balance)} is due on this order.');
        }
        list[index] = _withState(
          o,
          o.status,
          paid: input.isRefund ? o.paid - input.amount : o.paid + input.amount,
          // Giving it back by hand settles how it goes back, as on the server.
          refundMode: input.isRefund
              ? (o.refundMode ?? RentalRefundMode.inHand)
              : null,
          payments: [
            ...o.payments,
            RentalOrderPayment(
              id: 'p${o.payments.length + 1}',
              at: DateTime(2026, 11, 1),
              kind: input.isRefund ? 'Refund' : 'Balance',
              methodName: input.method == RentalPaymentMethod.cash
                  ? 'Cash'
                  : 'UPI QR',
              amount: input.amount,
            ),
          ],
        );
        _step(id, input.isRefund ? 'Refunded' : 'Payment received', o.quantity);
        return list[index];
      }
    }
    throw StateError('no order $id');
  }

  List<RentalOrder> get _allOrders => [
    for (final list in orders.values)
      for (final o in list) _withState(o, o.status),
  ];

  @override
  Future<List<RentalOrder>> getOrders({String? status}) async => [
    for (final o in _allOrders)
      if (status == null ||
          o.status == status ||
          (status == RentalOrderStatusCount.refundDue && o.refundOwed > 0))
        o,
  ];

  @override
  Future<List<RentalOrderStatusCount>> getOrderCounts() async => [
    RentalOrderStatusCount(
      status: RentalOrderStatusCount.refundDue,
      name: 'Refund due',
      tone: 'danger',
      count: _allOrders.where((o) => o.refundOwed > 0).length,
      countsInAll: false,
    ),
    for (final entry in _names.entries)
      RentalOrderStatusCount(
        status: entry.key,
        name: entry.value.$1,
        tone: entry.value.$2,
        count: _allOrders.where((o) => o.status == entry.key).length,
      ),
  ];

  @override
  Future<RentalOrder> getOrder(String id) async =>
      _allOrders.firstWhere((o) => o.id == id);

  @override
  Future<RentalCancelQuote> getCancelQuote(String id) async {
    final o = await getOrder(id);
    return RentalCancelQuote(
      unitsBefore: 2,
      unit: RentalCancelUnit.day,
      percent: 0,
      charge: 0,
      paid: o.paid,
      refund: o.paid,
      refundModes: o.paid <= 0
          ? const []
          : [
              for (final entry in _refundModes.entries)
                RentalRefundModeChoice(
                  code: entry.key,
                  name: entry.value.$1,
                  text: entry.value.$2,
                  disabledReason:
                      entry.key == RentalRefundMode.online &&
                          !o.payments.any((p) => p.methodName == 'Online')
                      ? 'The customer paid in cash or by UPI, so give the refund in hand.'
                      : null,
                ),
            ],
    );
  }

  @override
  Future<RentalOrder> setRefundMode(String id, String mode) async {
    calls.add('refund-mode:$id:$mode');
    for (final list in orders.values) {
      final index = list.indexWhere((o) => o.id == id);
      if (index >= 0) {
        list[index] = _withState(
          list[index],
          list[index].status,
          refundMode: mode,
        );
        return list[index];
      }
    }
    throw StateError('no order $id');
  }

  @override
  Future<RentalOrder> changeOrderStatus(
    String id,
    String toStatus, {
    String? refundMode,
  }) async {
    calls.add('order:$id:$toStatus${refundMode == null ? '' : ':$refundMode'}');
    for (final list in orders.values) {
      final index = list.indexWhere((o) => o.id == id);
      if (index >= 0) {
        // As on the server: cancelling a paid order needs the way the money goes back.
        if (toStatus == 'Cancelled' &&
            list[index].paid > 0 &&
            refundMode == null) {
          throw Exception('Choose how it goes back: online or in hand.');
        }
        list[index] = _withState(list[index], toStatus, refundMode: refundMode);
        _step(id, _names[toStatus]!.$1, list[index].quantity);
        return list[index];
      }
    }
    throw StateError('no order $id');
  }

  @override
  Future<List<RentalOrderThread>> getOrderThreads() async => [
    for (final o in _allOrders)
      if (messages[o.id]?.isNotEmpty ?? false)
        RentalOrderThread(
          rentalOrderId: o.id,
          customerName: o.customerName,
          itemName: o.itemName,
          quantity: o.quantity,
          lastMessage: messages[o.id]!.last.body,
          lastMessageAt: messages[o.id]!.last.sentAt,
          lastFromCustomer: !messages[o.id]!.last.isMine,
          unreadCount: o.unreadMessages,
        ),
  ];

  @override
  Future<List<BookingMessage>> getOrderMessages(String id) async {
    // Opening the thread reads the customer's messages, as the server does.
    final list = messages[id] ?? [];
    messages[id] = [
      for (final m in list)
        m.isMine || m.readAt != null
            ? m
            : BookingMessage(
                id: m.id,
                bookingId: m.bookingId,
                senderRole: m.senderRole,
                isMine: m.isMine,
                senderName: m.senderName,
                body: m.body,
                sentAt: m.sentAt,
                readAt: DateTime(2026, 11, 1),
              ),
    ];
    return [...messages[id]!];
  }

  @override
  Future<BookingMessage> sendOrderMessage(String id, String body) async {
    calls.add('message:$id:$body');
    final sent = BookingMessage(
      id: 'm-${DateTime.now().microsecondsSinceEpoch}',
      bookingId: id,
      senderRole: 'Business',
      isMine: true,
      senderName: 'You',
      body: body,
      sentAt: DateTime(2026, 11, 1, 10),
    );
    (messages[id] ??= []).add(sent);
    return sent;
  }

  /// Each order's steps, in the order they happened.
  final history = <String, List<RentalOrderEvent>>{};

  void _step(String orderId, String title, int quantity, {String? related}) =>
      (history[orderId] ??= []).add(
        RentalOrderEvent(
          id: 'h-${history.values.fold<int>(0, (n, l) => n + l.length)}',
          at: DateTime(2026, 11, 1, 9).add(
            Duration(
              minutes: history.values.fold<int>(0, (n, l) => n + l.length),
            ),
          ),
          title: title,
          tone: 'progress',
          quantity: quantity,
          relatedOrderId: related,
        ),
      );

  @override
  Future<List<RentalOrderEvent>> getOrderHistory(String id) async {
    final addOnIds = {
      for (final o in _allOrders)
        if (o.parentOrderId == id) o.id,
    };
    final steps = [
      ...?history[id],
      for (final addOn in addOnIds)
        for (final e in history[addOn] ?? const <RentalOrderEvent>[])
          RentalOrderEvent(
            id: e.id,
            at: e.at,
            title: e.title,
            tone: e.tone,
            quantity: e.quantity,
            onAddOn: true,
          ),
    ]..sort((a, b) => a.at.compareTo(b.at));
    return steps;
  }

  /// Set to make the next booking fail on the server, as if someone took the pieces meanwhile.
  String? refuseNextBooking;

  bool _holds(RentalOrder o) => o.status == 'Booked' || o.status == 'OnRent';

  @override
  Future<RentalAvailability> getAvailability(
    String itemId,
    DateTime start,
    DateTime end,
  ) async {
    final item = items.firstWhere((i) => i.id == itemId);
    final held = (orders[itemId] ?? const <RentalOrder>[])
        .where(
          (o) =>
              _holds(o) &&
              o.startDate.isBefore(end) &&
              o.endDate.isAfter(start),
        )
        .fold<int>(0, (sum, o) => sum + o.quantity);
    return RentalAvailability(
      total: item.quantityOwned,
      held: held,
      available: item.isAvailable
          ? (item.quantityOwned - held).clamp(0, item.quantityOwned)
          : 0,
    );
  }

  /// Sees each offline order as it is sent.
  void Function(RentalOrderInput input)? onCreate;

  @override
  Future<RentalOrder> createOrder(RentalOrderInput input) async {
    onCreate?.call(input);
    calls.add(
      'create-order:${input.rentalItemId}:${input.quantity}'
      '${input.advanceMethod == null ? '' : ':${input.advanceMethod}'}'
      '${input.advanceReceived ? ':received' : ''}',
    );
    if (refuseNextBooking case final reason?) {
      refuseNextBooking = null;
      throw Exception(reason);
    }
    final item = items.firstWhere((i) => i.id == input.rentalItemId);
    final amount = rentalAmount(
      item.priceType,
      item.price,
      input.quantity,
      input.startDate,
      input.endDate,
    );
    final advance =
        input.advanceAmount ??
        rentalAdvance(
          item.advanceType,
          item.advanceAmount,
          input.quantity,
          amount,
        );
    if (advance > 0 && input.advanceMethod == null) {
      throw Exception('${item.name} asks an advance. Say how it was paid.');
    }
    // Like the server: an offline order is always confirmed. An advance not in hand yet is simply
    // not recorded; it stays due and is collected from the order later.
    final held = advance > 0 && !input.advanceReceived;
    final created = RentalOrder(
      id: 'new-${calls.length}',
      rentalItemId: item.id,
      itemName: item.name,
      customerName: input.customerName,
      customerPhone: input.customerPhone,
      quantity: input.quantity,
      startDate: input.startDate,
      endDate: input.endDate,
      deliveryAddress: input.deliveryAddress,
      status: 'Booked',
      statusName: 'Booked',
      statusTone: 'progress',
      isOut: false,
      priceType: item.priceType,
      unitPrice: item.price,
      units: rentalUnits(item.priceType, input.startDate, input.endDate),
      amount: amount,
      advanceDue: advance,
      paid: held ? 0 : advance,
      payments: [
        if (advance > 0 && !held)
          RentalOrderPayment(
            id: 'adv',
            at: DateTime(2026, 11, 1),
            kind: 'Advance',
            methodName: input.advanceMethod == RentalPaymentMethod.cash
                ? 'Cash'
                : 'UPI QR',
            amount: advance,
          ),
      ],
    );
    final stored = _withState(created, created.status);
    (orders[item.id] ??= []).add(stored);
    _step(created.id, 'Booked', created.quantity);
    return stored;
  }

  @override
  Future<RentalOrder> addPieces(
    String orderId,
    int quantity, {
    DateTime? endDate,
  }) async {
    calls.add('add-pieces:$orderId:$quantity');
    final parent = _allOrders.firstWhere((o) => o.id == orderId);
    final addOn = RentalOrder(
      id: 'addon-${calls.length}',
      rentalItemId: parent.rentalItemId,
      itemName: parent.itemName,
      customerName: parent.customerName,
      quantity: quantity,
      startDate: DateTime.now(),
      endDate: endDate ?? parent.endDate,
      deliveryAddress: parent.deliveryAddress,
      status: 'Booked',
      statusName: 'Booked',
      statusTone: 'progress',
      isOut: false,
      parentOrderId: parent.id,
    );
    (orders[parent.rentalItemId] ??= []).add(addOn);
    _step(addOn.id, 'Booked', quantity);
    _step(parent.id, 'Extra pieces added', quantity, related: addOn.id);
    return _withState(addOn, 'Booked');
  }

  @override
  Future<void> syncProfile() async => syncs++;

  /// How often the business list asked for its customer-facing profile to be refreshed.
  int syncs = 0;

  @override
  Future<RentalSummary> getSummary() async {
    if (failList != null) throw failList!;
    final available = items.where((i) => i.isAvailable).toList();
    return RentalSummary(
      totalItems: items.length,
      availableItems: available.length,
      unavailableItems: items.length - available.length,
      unitsAvailable: available.fold(0, (sum, i) => sum + i.quantityOwned),
    );
  }

  @override
  Future<RentalItem> create(RentalItemInput input) async {
    calls.add('create');
    lastInput = input;
    final created = _item(id: 'new', name: input.name);
    items.insert(0, created);
    return created;
  }

  @override
  Future<RentalItem> update(String id, RentalItemInput input) async {
    calls.add('update:$id');
    lastInput = input;
    final updated = _item(
      id: id,
      name: input.name,
      priceType: input.priceType,
      price: input.price,
      quantity: input.quantityOwned,
      available: input.isAvailable,
      questions: [
        for (final (index, q) in input.questions.indexed)
          RentalItemQuestion(
            id: q['id'] as String? ?? 'q-new-$index',
            prompt: q['prompt'] as String,
            isRequired: q['isRequired'] as bool,
          ),
      ],
    );
    items[items.indexWhere((i) => i.id == id)] = updated;
    return updated;
  }

  @override
  Future<RentalItem> updateStock(
    String id, {
    required int quantityOwned,
    required bool isAvailable,
  }) async {
    calls.add('stock:$id:$quantityOwned:$isAvailable');
    final index = items.indexWhere((i) => i.id == id);
    final old = items[index];
    final updated = _item(
      id: id,
      name: old.name,
      priceType: old.priceType,
      price: old.price,
      quantity: quantityOwned,
      available: isAvailable,
    );
    items[index] = updated;
    return updated;
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete:$id');
    items.removeWhere((i) => i.id == id);
  }

  @override
  Future<void> uploadImage(String id, int slot, Uint8List bytes) async =>
      calls.add('image:$id:$slot');

  @override
  Future<void> removeImage(String id, int slot) async =>
      calls.add('removeImage:$id:$slot');

  @override
  Future<void> uploadVideo(
    String id,
    Uint8List bytes,
    String mimeSubtype,
  ) async => calls.add('video:$id');

  @override
  Future<void> removeVideo(String id) async => calls.add('removeVideo:$id');
}

class _NoServices extends BusinessServicesNotifier {
  @override
  Future<List<BusinessService>> build() async => const [];
}

Future<_FakeRentalRepository> _pump(
  WidgetTester tester,
  Widget child, {
  List<RentalItem> items = const [],
  Size size = const Size(400, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repository = _FakeRentalRepository(items);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        rentalRepositoryProvider.overrideWithValue(repository),
        businessServicesProvider.overrideWith(_NoServices.new),
        currentAppOptionsProvider.overrideWithValue(AppOptions.defaults),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  group('Service | Rent tabs', () {
    testWidgets('open on Service, the services screen as before', (
      tester,
    ) async {
      await _pump(tester, const BusinessCatalogTab());

      expect(find.text('Service'), findsOneWidget);
      expect(find.text('Rent'), findsOneWidget);
      expect(find.text('Add service'), findsOneWidget);
      expect(find.text('Add rent item'), findsNothing);
    });

    testWidgets('Rent shows the business rent items', (tester) async {
      await _pump(tester, const BusinessCatalogTab(), items: [_item()]);

      await tester.tap(find.text('Rent'));
      await tester.pumpAndSettle();

      expect(find.text('Plastic chair'), findsOneWidget);
      expect(find.text('Add rent item'), findsOneWidget);
    });
  });

  group('Rent list', () {
    testWidgets('a card shows category, rate and stock', (tester) async {
      await _pump(tester, const BusinessRentalsTab(), items: [_item()]);

      expect(find.text('Furniture & seating › Plastic chairs'), findsOneWidget);
      expect(find.text('${rupees(12)}/day · 200 in stock'), findsOneWidget);
      expect(find.text('Unavailable'), findsNothing);
    });

    testWidgets('an item switched off says Unavailable', (tester) async {
      await _pump(
        tester,
        const BusinessRentalsTab(),
        items: [_item(available: false)],
      );

      expect(find.text('Unavailable'), findsOneWidget);
    });

    testWidgets('opening the list refreshes how customers see the business', (
      tester,
    ) async {
      final repository = await _pump(tester, const BusinessRentalsTab());

      expect(repository.syncs, greaterThan(0));
    });

    testWidgets('nothing listed explains how to start', (tester) async {
      await _pump(tester, const BusinessRentalsTab());

      expect(find.textContaining('Nothing to rent yet'), findsOneWidget);
    });

    testWidgets('a failed load shows the error and can retry', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = _FakeRentalRepository([_item()])
        ..failList = Exception('Rent is down');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [rentalRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: Scaffold(body: BusinessRentalsTab())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Rent is down'), findsOneWidget);

      repository.failList = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Plastic chair'), findsOneWidget);
    });

    testWidgets('Remove asks first, then takes the item off', (tester) async {
      final repository = await _pump(
        tester,
        const BusinessRentalsTab(),
        items: [_item()],
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();
      expect(find.text('Remove rent item?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Remove').last);
      await tester.pumpAndSettle();

      expect(repository.calls, ['delete:item-1']);
      expect(find.text('Plastic chair'), findsNothing);
    });

    test('the card suffix comes from the rate table', () {
      for (final rate in _rates) {
        expect(
          rentalRateAndStock(_item(priceType: rate.code), _rates),
          '${rupees(12)}${rate.unitSuffix} · 200 in stock',
        );
      }
      expect(
        rentalRateAndStock(_item(), const []),
        '${rupees(12)} · 200 in stock',
        reason: 'before the table loads the price shows alone',
      );
    });
  });

  group('Rent item form', () {
    Future<void> openForm(WidgetTester tester, {RentalItem? existing}) async {
      await tester.tap(
        existing == null
            ? find.text('Add rent item')
            : find.byType(PopupMenuButton<String>),
      );
      await tester.pumpAndSettle();
      if (existing != null) {
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
      }
    }

    Future<void> save(WidgetTester tester, String label) async {
      final button = find.widgetWithText(FilledButton, label.toUpperCase());
      // The keyboard closed first, as a person does: a focused box keeps pulling itself into view.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(button.last);
      await tester.tap(button.last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    Future<void> tapAdd(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Add').last);
      await tester.tap(find.text('Add').last);
      await tester.pumpAndSettle();
    }

    Future<void> addQuestion(WidgetTester tester, String prompt) async {
      await tapAdd(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. Enter your dishes count').last,
        prompt,
      );
    }

    testWidgets(
      'has every field: photos, category, area, rate cards, quantity, available, questions',
      (tester) async {
        await _pump(tester, const BusinessRentalsTab());
        await openForm(tester);

        expect(find.text('Photos & video'), findsOneWidget);
        expect(find.text('Category'), findsOneWidget);
        expect(find.text('Service area'), findsOneWidget);
        expect(find.text('Item name'), findsOneWidget);
        expect(find.text('How do you charge?'), findsOneWidget);
        for (final rate in _rates) {
          expect(find.text(rate.name), findsOneWidget);
          expect(find.text(rate.detail), findsOneWidget);
        }
        expect(find.text('Fixed'), findsNothing);
        // One chosen card each: the rate, the advance and how the cancellation charge is worked out.
        expect(find.byIcon(Icons.radio_button_checked), findsNWidgets(3));
        expect(find.text('Advance before renting'), findsOneWidget);
        expect(
          find.text('How the cancellation charge is worked out'),
          findsOneWidget,
        );
        expect(find.text('Rate per day (INR)'), findsOneWidget);
        expect(find.text('Quantity you have'), findsOneWidget);
        expect(find.text('e.g. 1000'), findsOneWidget);
        expect(find.text('Available now'), findsOneWidget);
        expect(find.text('What should the customer tell you?'), findsOneWidget);
        expect(find.textContaining('before you rent this out'), findsOneWidget);
      },
    );

    testWidgets('saving empty says what is missing and calls nothing', (
      tester,
    ) async {
      final repository = await _pump(tester, const BusinessRentalsTab());
      await openForm(tester);

      await save(tester, 'Add rent item');

      expect(find.text('Select a category.'), findsOneWidget);
      expect(find.text('Name is required.'), findsOneWidget);
      expect(find.text('Enter a valid price.'), findsOneWidget);
      expect(repository.calls, isEmpty);
    });

    testWidgets('a category must be chosen before its sub-categories appear', (
      tester,
    ) async {
      await _pump(tester, const BusinessRentalsTab());
      await openForm(tester);
      expect(find.text('Sub-category'), findsNothing);

      await tester.tap(find.text('Select a category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tools & machines'));
      await tester.pumpAndSettle();

      expect(find.text('Sub-category'), findsOneWidget);
      await tester.tap(find.text('Any in this category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cutting machine'));
      await tester.pumpAndSettle();
      expect(find.text('Cutting machine'), findsOneWidget);
    });

    testWidgets('with a category but no district, says to pick a district', (
      tester,
    ) async {
      final repository = await _pump(tester, const BusinessRentalsTab());
      await openForm(tester);
      await tester.tap(find.text('Select a category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tools & machines'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Item name'),
        'Cutting machine',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Rate per day (INR)'),
        '500',
      );

      await save(tester, 'Add rent item');

      expect(find.textContaining('at least one district'), findsOneWidget);
      expect(repository.calls, isEmpty);
    });

    testWidgets('quantity must be at least 1', (tester) async {
      final repository = await _pump(
        tester,
        const BusinessRentalsTab(),
        items: [_item()],
      );
      await openForm(tester, existing: _item());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Quantity you have'),
        '0',
      );
      await save(tester, 'Save changes');

      expect(find.text('At least 1.'), findsOneWidget);
      expect(repository.calls, isEmpty);
    });

    testWidgets('editing rate, quantity and availability saves them', (
      tester,
    ) async {
      final repository = await _pump(
        tester,
        const BusinessRentalsTab(),
        items: [_item()],
      );
      await openForm(tester, existing: _item());

      expect(
        find.widgetWithText(TextFormField, 'Plastic chair'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Per hour'));
      await tester.tap(find.text('Per hour'));
      await tester.pump();
      expect(find.text('Rate per hour (INR)'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, '200'), '50');
      await tester.ensureVisible(find.text('Available now'));
      await tester.tap(find.text('Available now'));
      await tester.pump();
      await save(tester, 'Save changes');

      expect(repository.calls, ['update:item-1']);
      expect(repository.lastInput!.priceType, RentalPriceType.hourly);
      expect(repository.lastInput!.quantityOwned, 50);
      expect(repository.lastInput!.isAvailable, isFalse);
      expect(repository.lastInput!.districtIds, ['d-ekm']);
      expect(
        find.text('Unavailable'),
        findsOneWidget,
        reason: 'the list refreshed',
      );
    });

    testWidgets('Per item changes the rate box and is what gets saved', (
      tester,
    ) async {
      final repository = await _pump(
        tester,
        const BusinessRentalsTab(),
        items: [_item()],
      );
      await openForm(tester, existing: _item());

      await tester.ensureVisible(find.text('Per item'));
      await tester.tap(find.text('Per item'));
      await tester.pump();
      expect(find.text('Rate per item (INR)'), findsOneWidget);

      await save(tester, 'Save changes');

      expect(repository.lastInput!.priceType, RentalPriceType.fixed);
      expect(find.text('${rupees(12)}/item · 200 in stock'), findsOneWidget);
    });

    testWidgets('an advance per piece is chosen from cards and saved', (
      tester,
    ) async {
      final repository = await _pump(
        tester,
        const BusinessRentalsTab(),
        items: [_item()],
      );
      await openForm(tester, existing: _item());

      expect(find.byKey(const ValueKey('advance-amount')), findsNothing);
      await tester.ensureVisible(find.text('Per piece'));
      await tester.tap(find.text('Per piece'));
      await tester.pump();
      expect(find.text('Advance for each piece'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('advance-amount')), '2');

      await save(tester, 'Save changes');

      expect(repository.lastInput!.advanceType, RentalAdvanceType.perPiece);
      expect(repository.lastInput!.advanceAmount, 2);
    });

    testWidgets('an advance with no amount is refused before any call', (
      tester,
    ) async {
      final repository = await _pump(
        tester,
        const BusinessRentalsTab(),
        items: [_item()],
      );
      await openForm(tester, existing: _item());

      await tester.ensureVisible(find.text('Fixed for the order'));
      await tester.tap(find.text('Fixed for the order'));
      await tester.pump();
      await save(tester, 'Save changes');

      expect(
        find.text('Enter the advance, or choose no advance.'),
        findsOneWidget,
      );
      expect(repository.calls, isEmpty);
    });

    testWidgets('choosing no advance again sends none', (tester) async {
      final asking = _item(
        advanceType: RentalAdvanceType.perOrder,
        advanceAmount: 500,
      );
      final repository = await _pump(
        tester,
        const BusinessRentalsTab(),
        items: [asking],
      );
      await openForm(tester, existing: asking);

      await tester.ensureVisible(find.text('No advance'));
      await tester.tap(find.text('No advance'));
      await tester.pump();
      await save(tester, 'Save changes');

      expect(repository.lastInput!.advanceType, RentalAdvanceType.none);
      expect(repository.lastInput!.advanceAmount, isNull);
    });

    testWidgets('a large stock such as 1000 is saved', (tester) async {
      final repository = await _pump(
        tester,
        const BusinessRentalsTab(),
        items: [_item()],
      );
      await openForm(tester, existing: _item());

      await tester.enterText(find.widgetWithText(TextFormField, '200'), '1000');
      await save(tester, 'Save changes');

      expect(repository.lastInput!.quantityOwned, 1000);
      expect(find.text('${rupees(12)}/day · 1000 in stock'), findsOneWidget);
    });

    testWidgets('saving an untouched item makes no call', (tester) async {
      final repository = await _pump(
        tester,
        const BusinessRentalsTab(),
        items: [_item()],
      );
      await openForm(tester, existing: _item());

      await save(tester, 'Save changes');

      expect(repository.calls, isEmpty);
      expect(find.text('Edit rent item'), findsNothing);
    });

    testWidgets('questions are added, marked required and saved in order', (
      tester,
    ) async {
      final repository = await _pump(
        tester,
        const BusinessRentalsTab(),
        items: [_item()],
      );
      await openForm(tester, existing: _item());

      await addQuestion(tester, 'Event date and venue');
      await addQuestion(tester, 'Delivery needed?');
      await tester.tap(find.byIcon(Icons.star_outline_rounded).first);
      await tester.pump();
      expect(
        find.textContaining('Every customer renting this item'),
        findsOneWidget,
      );

      await save(tester, 'Save changes');

      expect(repository.calls, ['update:item-1']);
      expect(repository.lastInput!.questions, [
        {'prompt': 'Event date and venue', 'isRequired': true},
        {'prompt': 'Delivery needed?', 'isRequired': false},
      ]);
    });

    testWidgets('saved questions keep their id; a removed one is left out', (
      tester,
    ) async {
      final existing = _item(
        questions: const [
          RentalItemQuestion(id: 'q1', prompt: 'Event date', isRequired: true),
          RentalItemQuestion(id: 'q2', prompt: 'Floor type', isRequired: false),
        ],
      );
      final repository = await _pump(
        tester,
        const BusinessRentalsTab(),
        items: [existing],
      );
      await openForm(tester, existing: existing);

      expect(find.widgetWithText(TextFormField, 'Event date'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Remove').last);
      await tester.tap(find.byTooltip('Remove').last);
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Event date'),
        'Event date and time',
      );

      await save(tester, 'Save changes');

      expect(repository.lastInput!.questions, [
        {'id': 'q1', 'prompt': 'Event date and time', 'isRequired': true},
      ]);
    });

    testWidgets('a blank question is refused before any call', (tester) async {
      final repository = await _pump(
        tester,
        const BusinessRentalsTab(),
        items: [_item()],
      );
      await openForm(tester, existing: _item());

      await tapAdd(tester);
      await save(tester, 'Save changes');

      expect(
        find.text('Type the question, or remove this row.'),
        findsOneWidget,
      );
      expect(repository.calls, isEmpty);
    });

    testWidgets('an untouched item with questions makes no call', (
      tester,
    ) async {
      final existing = _item(
        questions: const [
          RentalItemQuestion(id: 'q1', prompt: 'Event date', isRequired: true),
        ],
      );
      final repository = await _pump(
        tester,
        const BusinessRentalsTab(),
        items: [existing],
      );
      await openForm(tester, existing: existing);

      await save(tester, 'Save changes');

      expect(repository.calls, isEmpty);
    });

    testWidgets(
      'the cancellation charge shows the admin limit and saves the steps',
      (tester) async {
        final repository = await _pump(
          tester,
          const BusinessRentalsTab(),
          items: [_item()],
        );
        await openForm(tester, existing: _item());

        final limit = find.byKey(const ValueKey('cancel-steps-limit'));
        await tester.ensureVisible(limit);
        expect(
          tester.widget<Text>(limit).data,
          contains('Up to 2% of the order for Plastic chairs'),
        );
        expect(find.textContaining('Free cancellation.'), findsOneWidget);

        // The first step is the start day itself, filled in.
        await tester.tap(find.byKey(const ValueKey('cancel-step-add')));
        await tester.pump();
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const ValueKey('cancel-step-0-units')),
              )
              .controller!
              .text,
          '0',
        );
        await tester.enterText(
          find.byKey(const ValueKey('cancel-step-0-percent')),
          '2',
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('cancel-step-add')),
        );
        await tester.tap(find.byKey(const ValueKey('cancel-step-add')));
        await tester.pump();
        await tester.enterText(
          find.byKey(const ValueKey('cancel-step-1-units')),
          '5',
        );
        await tester.enterText(
          find.byKey(const ValueKey('cancel-step-1-percent')),
          '0.5',
        );

        await save(tester, 'Save changes');

        expect(repository.calls, ['update:item-1']);
        expect(
          [
            for (final s in repository.lastInput!.cancelSteps)
              (s.unitsBefore, s.percent),
          ],
          [(0, 2.0), (5, 0.5)],
        );
        expect(repository.lastInput!.toJson()['cancelSteps'], [
          {'unitsBefore': 0, 'percent': 2.0},
          {'unitsBefore': 5, 'percent': 0.5},
        ]);
      },
    );

    testWidgets('plastic chairs allow 2%, so 5% is refused before any call', (
      tester,
    ) async {
      final repository = await _pump(
        tester,
        const BusinessRentalsTab(),
        items: [_item()],
      );
      await openForm(tester, existing: _item());

      await tester.ensureVisible(find.byKey(const ValueKey('cancel-step-add')));
      await tester.tap(find.byKey(const ValueKey('cancel-step-add')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('cancel-step-0-percent')),
        '5',
      );
      await save(tester, 'Save changes');

      expect(find.text('At most 2%.'), findsOneWidget);
      expect(repository.calls, isEmpty);
    });

    testWidgets('steps without a same-day step are refused', (tester) async {
      final repository = await _pump(
        tester,
        const BusinessRentalsTab(),
        items: [_item()],
      );
      await openForm(tester, existing: _item());

      await tester.ensureVisible(find.byKey(const ValueKey('cancel-step-add')));
      await tester.tap(find.byKey(const ValueKey('cancel-step-add')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('cancel-step-0-units')),
        '3',
      );
      await tester.enterText(
        find.byKey(const ValueKey('cancel-step-0-percent')),
        '1',
      );
      await save(tester, 'Save changes');

      expect(
        find.text('Add a step for cancelling on the start day itself (0).'),
        findsOneWidget,
      );
      expect(repository.calls, isEmpty);
    });

    testWidgets('an hourly item counts its steps in hours', (tester) async {
      final item = _item(
        priceType: RentalPriceType.hourly,
        cancelSteps: const [
          RentalCancelStep(unitsBefore: 0, percent: 2),
          RentalCancelStep(unitsBefore: 6, percent: 1),
        ],
      );
      await _pump(tester, const BusinessRentalsTab(), items: [item]);
      await openForm(tester, existing: item);

      await tester.ensureVisible(
        find.byKey(const ValueKey('cancel-steps-section')),
      );
      expect(find.text('Hours before'), findsNWidgets(2));
      // Farthest first, as the business reads it.
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('cancel-step-0-units')),
            )
            .controller!
            .text,
        '6',
      );
    });

    testWidgets('removing every step saves free cancellation', (tester) async {
      final item = _item(
        cancelSteps: const [RentalCancelStep(unitsBefore: 0, percent: 2)],
      );
      final repository = await _pump(
        tester,
        const BusinessRentalsTab(),
        items: [item],
      );
      await openForm(tester, existing: item);

      await tester.ensureVisible(
        find.byKey(const ValueKey('cancel-step-0-remove')),
      );
      await tester.tap(find.byKey(const ValueKey('cancel-step-0-remove')));
      await tester.pump();
      await save(tester, 'Save changes');

      expect(repository.calls, ['update:item-1']);
      expect(repository.lastInput!.cancelSteps, isEmpty);
    });

    testWidgets(
      'a charge per rental day is one box, checked against the limit',
      (tester) async {
        final repository = await _pump(
          tester,
          const BusinessRentalsTab(),
          items: [_item()],
        );
        await openForm(tester, existing: _item());

        final perDay = find.text('Per rental day');
        await tester.ensureVisible(perDay);
        await tester.tap(perDay);
        await tester.pump();
        expect(
          find.byKey(const ValueKey('cancel-steps-section')),
          findsNothing,
          reason: 'one way of working it out: no steps with a per-day charge',
        );
        final box = find.byKey(const ValueKey('cancel-per-day'));
        expect(box, findsOneWidget);
        expect(
          find.textContaining('a 2-day order cancelled costs 2%'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Never above 2% for Plastic chairs'),
          findsOneWidget,
        );

        await tester.enterText(box, '3');
        await save(tester, 'Save changes');
        expect(find.text('At most 2%.'), findsOneWidget);
        expect(repository.calls, isEmpty);

        await tester.enterText(box, '1');
        await save(tester, 'Save changes');

        expect(repository.calls, ['update:item-1']);
        final input = repository.lastInput!;
        expect(input.cancelChargeType, RentalCancelChargeType.perRentalDay);
        expect(input.cancelPercentPerDay, 1);
        expect(input.cancelSteps, isEmpty);
        expect(input.toJson()['cancelChargeType'], 'PerRentalDay');
      },
    );

    testWidgets('an hourly item is charged per rental hour', (tester) async {
      final item = _item(
        priceType: RentalPriceType.hourly,
        cancelChargeType: RentalCancelChargeType.perRentalDay,
        cancelPercentPerDay: 0.5,
      );
      await _pump(tester, const BusinessRentalsTab(), items: [item]);
      await openForm(tester, existing: item);

      final box = find.byKey(const ValueKey('cancel-per-day'));
      await tester.ensureVisible(box);
      expect(find.text('Charge for each rental hour'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(box).controller!.text,
        '0.5',
        reason: 'the saved per-day charge opens as it was',
      );
    });

    test('a per-day charge adds up by the days, never past the limit', () {
      expect(rentalPerDayPercent(1, 1, 2), 1);
      expect(rentalPerDayPercent(1, 2, 2), 2);
      expect(rentalPerDayPercent(1, 5, 2), 2);
      expect(rentalPerDayPercent(0.5, 3, 2), 1.5);
    });

    test('step rules match the server', () {
      expect(rentalCancelStepsProblem(const []), isNull);
      expect(
        rentalCancelStepsProblem(const [
          RentalCancelStep(unitsBefore: 0, percent: 2),
          RentalCancelStep(unitsBefore: 0, percent: 1),
        ]),
        'Each cancellation step needs its own number of days or hours.',
      );
      expect(
        rentalCancelStepsProblem(const [
          RentalCancelStep(unitsBefore: 0, percent: 1),
          RentalCancelStep(unitsBefore: 3, percent: 2),
        ]),
        'Cancelling earlier cannot cost more than cancelling later.',
      );
      expect(
        rentalCancelStepsProblem(const [
          RentalCancelStep(unitsBefore: 0, percent: 2),
          RentalCancelStep(unitsBefore: 2, percent: 1),
          RentalCancelStep(unitsBefore: 5, percent: 0.5),
        ]),
        isNull,
      );
    });

    test('the rate box is named after the chosen card', () {
      expect(rentalRateFieldLabel(_rates[0]), 'Rate per day (INR)');
      expect(rentalRateFieldLabel(_rates[1]), 'Rate per item (INR)');
      expect(rentalRateFieldLabel(_rates[2]), 'Rate per hour (INR)');
      expect(rentalRateFieldLabel(null), 'Rate (INR)');
    });
  });

  group('Rent tiles on the business home screen', () {
    final stock = [
      _item(id: 'machine', name: 'Cutting machine', quantity: 1),
      _item(id: 'chairs', name: 'Plastic chair', quantity: 200),
      _item(id: 'gen', name: 'Generator', quantity: 2, available: false),
    ];

    String tileValue(WidgetTester tester, String label) =>
        tester.widget<StatTile>(find.widgetWithText(StatTile, label)).value;

    testWidgets('count items, available and unavailable', (tester) async {
      await _pump(tester, const RentDashboardTiles(), items: stock);

      expect(tileValue(tester, 'Rent items'), '3');
      expect(tileValue(tester, 'Available now'), '2');
      expect(tileValue(tester, 'Unavailable'), '1');
      expect(
        tileValue(tester, 'Stock'),
        isEmpty,
        reason: 'Stock is a way in, not a count',
      );
    });

    testWidgets('a business with nothing listed sees zeros', (tester) async {
      await _pump(tester, const RentDashboardTiles());

      for (final label in ['Rent items', 'Available now', 'Unavailable']) {
        expect(tileValue(tester, label), '0');
      }
    });

    testWidgets('Unavailable opens only the switched-off items', (
      tester,
    ) async {
      await _pump(tester, const RentDashboardTiles(), items: stock);

      await tester.tap(find.text('Unavailable'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Unavailable'), findsOneWidget);
      expect(find.text('Generator'), findsOneWidget);
      expect(find.text('Plastic chair'), findsNothing);
      expect(find.text('Add rent item'), findsNothing);
    });

    testWidgets('Available now opens only the items that can be rented', (
      tester,
    ) async {
      await _pump(tester, const RentDashboardTiles(), items: stock);

      await tester.tap(find.text('Available now'));
      await tester.pumpAndSettle();

      expect(find.text('Cutting machine'), findsOneWidget);
      expect(find.text('Plastic chair'), findsOneWidget);
      expect(find.text('Generator'), findsNothing);
    });

    testWidgets('Rent items opens every item', (tester) async {
      await _pump(tester, const RentDashboardTiles(), items: stock);

      await tester.tap(find.text('Rent items'));
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsNWidgets(3));
    });

    testWidgets('removing an item from a tile list updates the counts', (
      tester,
    ) async {
      await _pump(tester, const RentDashboardTiles(), items: stock);
      await tester.tap(find.text('Unavailable'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('none is switched off'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tileValue(tester, 'Rent items'), '2');
      expect(tileValue(tester, 'Unavailable'), '0');
    });

    testWidgets('Rent being down shows an error in its own section', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = _FakeRentalRepository(stock)
        ..failList = Exception('Rent is down');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [rentalRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: Scaffold(body: RentDashboardTiles())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Rent is down'), findsOneWidget);
      expect(find.byType(StatTile), findsNothing);
    });
  });

  group('Stock: one home tile, in / out / total per item, orders', () {
    final stock = [
      _item(id: 'chairs', name: 'Plastic chair', quantity: 1000),
      _item(id: 'bench', name: 'Bench', quantity: 50),
      _item(id: 'sheet', name: 'Sheet', quantity: 300, available: false),
    ];

    RentalOrder order(
      String customer,
      int quantity,
      String status, {
      bool out = false,
      String tone = 'progress',
    }) => RentalOrder(
      id: 'o-$customer',
      customerName: customer,
      customerPhone: '9876543210',
      quantity: quantity,
      startDate: DateTime(2026, 11, 1),
      endDate: DateTime(2026, 11, 3),
      deliveryAddress: "St. Mary's Hall, Kakkanad",
      districtName: 'Ernakulam',
      status: status,
      statusName: status == 'OnRent' ? 'On rent' : status,
      statusTone: tone,
      isOut: out,
    );

    Future<_FakeRentalRepository> pumpStock(
      WidgetTester tester, {
      Widget screen = const RentalStockScreen(),
      Size size = const Size(400, 800),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = _FakeRentalRepository(stock)
        ..orders['chairs'] = [
          order('Rahul', 300, 'OnRent', out: true, tone: 'danger'),
          order('Joseph', 100, 'Booked'),
        ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [rentalRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(home: Scaffold(body: screen)),
        ),
      );
      await tester.pumpAndSettle();
      return repository;
    }

    /// The three figures on one item's stock tile, in order: in, out, total.
    List<String> figures(WidgetTester tester, String itemId) => tester
        .widgetList<StockFigureRow>(
          find.descendant(
            of: find.byKey(ValueKey('stock-$itemId')),
            matching: find.byType(StockFigureRow),
          ),
        )
        .map((r) => '${r.label} ${r.value}')
        .toList();

    Future<void> openChairs(WidgetTester tester) async {
      await tester.tap(find.text('Plastic chair'));
      await tester.pumpAndSettle();
    }

    String shownQuantity(WidgetTester tester) => tester
        .widget<TextField>(find.byKey(const ValueKey('stock-quantity')))
        .controller!
        .text;

    final saveButton = find.widgetWithText(FilledButton, 'SAVE STOCK');

    testWidgets('the home Stock tile has no number and opens the Stock page', (
      tester,
    ) async {
      await _pump(tester, const RentDashboardTiles(), items: stock);

      final tile = tester.widget<StatTile>(
        find.widgetWithText(StatTile, 'Stock'),
      );
      expect(tile.value, isEmpty);
      expect(find.byIcon(Icons.chair_outlined), findsNothing);

      await tester.tap(find.text('Stock'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Stock'), findsOneWidget);
    });

    testWidgets('each item shows in stock, out and total', (tester) async {
      await pumpStock(tester);

      expect(figures(tester, 'chairs'), [
        'In stock 700',
        'Booked 100',
        'Out 300',
        'Total 1000',
      ]);
      expect(figures(tester, 'bench'), [
        'In stock 50',
        'Booked 0',
        'Out 0',
        'Total 50',
      ]);
      expect(find.text('Switched off'), findsOneWidget, reason: 'the sheet');
    });

    testWidgets('nothing listed offers to add an item', (tester) async {
      await _pump(tester, const RentalStockScreen());

      expect(find.textContaining('Nothing to rent yet'), findsOneWidget);
      expect(find.text('Add rent item'), findsOneWidget);
    });

    testWidgets('an item opens on two tabs: Stock and Orders', (tester) async {
      await pumpStock(tester);
      await openChairs(tester);

      expect(find.widgetWithText(Tab, 'Stock'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Orders'), findsOneWidget);
      expect(find.text('Out with customers'), findsOneWidget);
      expect(shownQuantity(tester), '1000');
    });

    testWidgets('Orders lists where the pieces went', (tester) async {
      await pumpStock(tester);
      await openChairs(tester);

      await tester.tap(find.widgetWithText(Tab, 'Orders'));
      await tester.pumpAndSettle();

      expect(find.text('Rahul'), findsOneWidget);
      expect(find.text('On rent'), findsOneWidget);
      expect(find.textContaining('300 pcs'), findsOneWidget);
      expect(
        find.text("St. Mary's Hall, Kakkanad · Ernakulam"),
        findsNWidgets(2),
      );
      expect(find.text('Joseph'), findsOneWidget);
    });

    testWidgets('an item with no orders says how the tab fills', (
      tester,
    ) async {
      await pumpStock(tester);
      await tester.tap(find.text('Bench'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Orders'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No orders yet'), findsOneWidget);
    });

    testWidgets('the count cannot go below what is out', (tester) async {
      final repository = await pumpStock(tester);
      await openChairs(tester);

      await tester.enterText(
        find.byKey(const ValueKey('stock-quantity')),
        '250',
      );
      await tester.pump();

      expect(find.textContaining('300 are out with customers'), findsOneWidget);
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pump();
      expect(repository.calls, isEmpty);
    });

    testWidgets('− / + and the quick chips change the count, never below 1', (
      tester,
    ) async {
      await pumpStock(tester);
      await tester.tap(find.text('Bench'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('One more'));
      await tester.pump();
      expect(shownQuantity(tester), '51');
      await tester.tap(find.text('+50'));
      await tester.pump();
      expect(shownQuantity(tester), '101');
      await tester.tap(find.text('+10'));
      await tester.pump();
      expect(shownQuantity(tester), '111');
      for (var i = 0; i < 12; i++) {
        await tester.tap(find.text('-10'));
        await tester.pump();
      }
      expect(shownQuantity(tester), '1');
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byIcon(Icons.remove),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('Save is off until something changes', (tester) async {
      final repository = await pumpStock(tester);
      await openChairs(tester);

      await tester.ensureVisible(saveButton);
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
      expect(repository.calls, isEmpty);
    });

    testWidgets('saving a new total updates in / out / total', (tester) async {
      final repository = await pumpStock(tester);
      await openChairs(tester);

      await tester.tap(find.text('+50'));
      await tester.pump();
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(repository.calls, ['stock:chairs:1050:true']);
      expect(find.widgetWithText(AppBar, 'Stock'), findsOneWidget);
      expect(figures(tester, 'chairs'), [
        'In stock 750',
        'Booked 100',
        'Out 300',
        'Total 1050',
      ]);
      expect(figures(tester, 'bench').last, 'Total 50');
    });

    testWidgets('leaving with unsaved changes asks first', (tester) async {
      final repository = await pumpStock(tester);
      await openChairs(tester);
      await tester.tap(find.byTooltip('One more'));
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.byType(RentalStockItemScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byType(RentalStockItemScreen), findsNothing);
      expect(repository.calls, isEmpty);
    });

    testWidgets('a change survives a look at the Orders tab', (tester) async {
      await pumpStock(tester);
      await openChairs(tester);
      await tester.tap(find.text('+10'));
      await tester.pump();

      await tester.tap(find.widgetWithText(Tab, 'Orders'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Stock'));
      await tester.pumpAndSettle();

      expect(shownQuantity(tester), '1010');
    });

    testWidgets('a failed save keeps the page and says why', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rentalRepositoryProvider.overrideWithValue(
              _ThrowingStockRepository(stock),
            ),
          ],
          child: const MaterialApp(home: RentalStockScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await openChairs(tester);

      await tester.tap(find.byTooltip('One more'));
      await tester.pump();
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('Rent is down'), findsOneWidget);
      expect(find.byType(RentalStockItemScreen), findsOneWidget);
    });

    testWidgets('fits a 360dp phone', (tester) async {
      await pumpStock(tester, size: const Size(360, 740));
      expect(tester.takeException(), isNull);
      await openChairs(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(Tab, 'Orders'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Orders › Rent: bookings, status management, messages', () {
    RentalOrder order(
      String id,
      String customer,
      int quantity,
      String status, {
      String itemId = 'chairs',
      String item = 'Plastic chair',
    }) => RentalOrder(
      id: id,
      rentalItemId: itemId,
      itemName: item,
      customerName: customer,
      quantity: quantity,
      startDate: DateTime(2026, 11, 1),
      endDate: DateTime(2026, 11, 3),
      deliveryAddress: 'Kakkanad',
      districtName: 'Ernakulam',
      status: status,
      statusName: status,
      statusTone: 'waiting',
      isOut: false,
    );

    BookingMessage fromCustomer(String id, String orderId, String body) =>
        BookingMessage(
          id: id,
          bookingId: orderId,
          senderRole: 'Customer',
          isMine: false,
          senderName: 'Rahul',
          body: body,
          sentAt: DateTime(2026, 11, 1, 9),
        );

    Future<_FakeRentalRepository> pumpOrders(
      WidgetTester tester, {
      Widget screen = const BusinessRentOrdersTab(),
      Size size = const Size(400, 800),
      bool settle = true,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository =
          _FakeRentalRepository([
              _item(id: 'chairs', name: 'Plastic chair', quantity: 1000),
            ])
            ..orders['chairs'] = [
              order('o1', 'Rahul', 300, 'Booked'),
              order('o2', 'Anu', 150, 'OnRent'),
              order('o3', 'Meera', 200, 'Returned'),
            ]
            ..messages['o1'] = [
              fromCustomer('m1', 'o1', 'Can you deliver by 9 am?'),
            ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rentalRepositoryProvider.overrideWithValue(repository),
            businessServicesProvider.overrideWith(_NoServices.new),
            currentAppOptionsProvider.overrideWithValue(AppOptions.defaults),
          ],
          child: MaterialApp(home: Scaffold(body: screen)),
        ),
      );
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump(const Duration(milliseconds: 500));
      }
      return repository;
    }

    /// Lets taps and loads on the Rent side finish while the Service side keeps loading.
    Future<void> frames(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('Orders splits into Service and Rent', (tester) async {
      await pumpOrders(
        tester,
        screen: const BusinessOrdersHubTab(),
        settle: false,
      );

      expect(find.widgetWithText(Tab, 'Service'), findsOneWidget);
      expect(find.text('Rent'), findsOneWidget);
      expect(
        find.byType(BusinessRentOrdersTab),
        findsNothing,
        reason: 'Service, the existing screen, opens first',
      );
    });

    testWidgets('Rent has Bookings, Status management and Messages', (
      tester,
    ) async {
      await pumpOrders(tester);

      expect(find.widgetWithText(Tab, 'Bookings'), findsOneWidget);
      expect(find.text('Status management'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Rahul'), findsOneWidget);
      expect(find.text('Anu'), findsOneWidget);
      expect(find.text('Meera'), findsOneWidget);
    });

    testWidgets('a status chip narrows the bookings', (tester) async {
      await pumpOrders(tester);

      expect(find.text('All · 3'), findsOneWidget);
      await tester.ensureVisible(find.text('On rent · 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('On rent · 1'));
      await tester.pumpAndSettle();

      expect(find.text('Anu'), findsOneWidget);
      expect(find.text('Rahul'), findsNothing);
    });

    testWidgets('Status management shows only orders with a next step', (
      tester,
    ) async {
      await pumpOrders(tester);
      await tester.tap(find.text('Status management'));
      await tester.pumpAndSettle();

      expect(find.text('Send out'), findsOneWidget);
      expect(find.text('Mark returned'), findsOneWidget);
      expect(
        find.text('Meera'),
        findsNothing,
        reason: 'returned: nothing to do',
      );
    });

    testWidgets('Send out moves the order on and says so', (tester) async {
      final repository = await pumpOrders(tester);
      await tester.tap(find.text('Status management'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send out'));
      await tester.pumpAndSettle();

      expect(repository.calls, ['order:o1:OnRent']);
      expect(find.textContaining('on rent.'), findsOneWidget);
      expect(find.text('Send out'), findsNothing);
      expect(find.text('Mark returned'), findsNWidgets(2));
    });

    testWidgets('cancelling asks first', (tester) async {
      final repository = await pumpOrders(tester);
      await tester.tap(find.text('Rahul'));
      await tester.pumpAndSettle();
      expect(find.text('Rent order'), findsOneWidget);

      await tester.tap(find.text('Cancel order'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel order?'), findsOneWidget);
      await tester.tap(find.text('Keep order'));
      await tester.pumpAndSettle();
      expect(repository.calls, isEmpty);

      await tester.tap(find.text('Cancel order'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel order'));
      await tester.pumpAndSettle();
      expect(repository.calls, ['order:o1:Cancelled']);
      expect(find.text('Nothing left to do on this order.'), findsOneWidget);
    });

    testWidgets('the order detail shows where, when and who', (tester) async {
      await pumpOrders(tester);
      await tester.tap(find.text('Anu'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('order-total'))).data,
        '150',
      );
      expect(find.text('Kakkanad · Ernakulam'), findsOneWidget);
      expect(find.text('Mark returned'), findsOneWidget);
      expect(find.text('Message Anu'), findsOneWidget);
    });

    testWidgets('an unread customer message counts on the Messages tab', (
      tester,
    ) async {
      await pumpOrders(tester);

      expect(
        find.descendant(
          of: find.widgetWithText(Tab, 'Messages'),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Messages lists the thread; opening it reads and replies', (
      tester,
    ) async {
      final repository = await pumpOrders(tester);
      await tester.tap(find.text('Messages'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Can you deliver by 9 am?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rent-thread-o1')));
      await tester.pumpAndSettle();

      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.text('Can you deliver by 9 am?'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'Yes, 8:30.');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      if (repository.calls.isEmpty) {
        await tester.tap(find.byIcon(Icons.send_rounded).last);
        await tester.pumpAndSettle();
      }

      expect(repository.calls, ['message:o1:Yes, 8:30.']);
      expect(find.text('Yes, 8:30.'), findsOneWidget);
    });

    testWidgets('no orders yet explains what will show', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rentalRepositoryProvider.overrideWithValue(
              _FakeRentalRepository(const []),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: BusinessRentOrdersTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No rent orders yet'), findsOneWidget);
    });

    testWidgets('fits a 360dp phone', (tester) async {
      await pumpOrders(
        tester,
        screen: const BusinessOrdersHubTab(),
        size: const Size(360, 740),
        settle: false,
      );
      await tester.tap(find.text('Rent'));
      await frames(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Status management'));
      await frames(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('Booking by dates: what is left, and extra pieces', () {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    RentalOrder running(
      String id,
      String customer,
      int quantity,
      String status,
    ) => RentalOrder(
      id: id,
      rentalItemId: 'chairs',
      itemName: 'Plastic chair',
      customerName: customer,
      quantity: quantity,
      startDate: today,
      endDate: today.add(const Duration(days: 2)),
      deliveryAddress: 'Kakkanad',
      status: status,
      statusName: status,
      statusTone: 'waiting',
      isOut: status == 'OnRent',
    );

    /// Scenario 2: 2000 chairs, A has 1000 and B 700 for these dates — 300 are left.
    Future<_FakeRentalRepository> pumpScenario(
      WidgetTester tester, {
      Size size = const Size(400, 900),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository =
          _FakeRentalRepository([
              _item(id: 'chairs', name: 'Plastic chair', quantity: 2000),
            ])
            ..orders['chairs'] = [
              running('a', 'A', 1000, 'Booked'),
              running('b', 'B', 700, 'OnRent'),
              running('old', 'Old', 500, 'Returned'),
            ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [rentalRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(
            home: Scaffold(body: BusinessRentOrdersTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return repository;
    }

    Future<void> openNewOrder(WidgetTester tester) async {
      await tester.tap(find.text('Offline order'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose the item'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plastic chair').last);
      await tester.pumpAndSettle();
    }

    Future<void> setQuantity(WidgetTester tester, String value) async {
      await tester.enterText(
        find.byKey(const ValueKey('order-quantity')),
        value,
      );
      await tester.pumpAndSettle();
    }

    final bookButton = find.widgetWithText(FilledButton, 'BOOK');

    testWidgets(
      '500 when only 300 are left shows "Only 300" and cannot be booked',
      (tester) async {
        final repository = await pumpScenario(tester);
        await openNewOrder(tester);

        await setQuantity(tester, '500');

        expect(find.textContaining('Only 300 available for'), findsOneWidget);
        expect(find.textContaining('you asked for 500'), findsOneWidget);
        await tester.ensureVisible(bookButton);
        expect(tester.widget<FilledButton>(bookButton).onPressed, isNull);
        expect(repository.calls, isEmpty);
      },
    );

    testWidgets('300 fits: shown as available, and books', (tester) async {
      final repository = await pumpScenario(tester);
      await openNewOrder(tester);

      await setQuantity(tester, '300');
      expect(find.textContaining('300 available for'), findsOneWidget);
      expect(find.textContaining('Only'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Customer name'),
        'C',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Where it goes'),
        'Town Hall',
      );
      await tester.ensureVisible(bookButton);
      await tester.tap(bookButton);
      await tester.pumpAndSettle();

      expect(repository.calls, ['create-order:chairs:300']);
      expect(
        find.textContaining('Order confirmed: 300 × Plastic chair for C'),
        findsOneWidget,
      );
    });

    testWidgets('returned orders free their pieces; switching dates rechecks', (
      tester,
    ) async {
      await pumpScenario(tester);
      await openNewOrder(tester);
      await setQuantity(tester, '1');

      expect(
        find.textContaining('300 available'),
        findsOneWidget,
        reason: "Old's returned 500 do not count",
      );
    });

    testWidgets('the server refusing (someone booked meanwhile) is shown', (
      tester,
    ) async {
      final repository = await pumpScenario(tester);
      repository.refuseNextBooking =
          'Only 100 Plastic chair available for these dates; this order needs 300.';
      await openNewOrder(tester);
      await setQuantity(tester, '300');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Customer name'),
        'C',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Where it goes'),
        'Town Hall',
      );
      await tester.ensureVisible(bookButton);
      await tester.tap(bookButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('Only 100 Plastic chair'), findsOneWidget);
      expect(
        find.text('Offline order'),
        findsWidgets,
        reason: 'the sheet stays open',
      );
    });

    testWidgets('name and place are required before booking', (tester) async {
      final repository = await pumpScenario(tester);
      await openNewOrder(tester);
      await setQuantity(tester, '10');

      await tester.ensureVisible(bookButton);
      await tester.tap(bookButton);
      await tester.pumpAndSettle();

      expect(find.text("Give the customer's name."), findsOneWidget);
      expect(find.text('Say where the pieces go.'), findsOneWidget);
      expect(repository.calls, isEmpty);
    });

    testWidgets('B, already delivered, gets 200 more as a linked add-on', (
      tester,
    ) async {
      final repository = await pumpScenario(tester);
      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Add more pieces'));
      await tester.tap(find.text('Add more pieces'));
      await tester.pumpAndSettle();
      expect(find.textContaining('B has 700 × Plastic chair'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('order-quantity')),
        '200',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('300 available'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'ADD PIECES'));
      await tester.pumpAndSettle();

      expect(repository.calls, ['add-pieces:b:200']);
      expect(
        find.textContaining('Added 200 more Plastic chair for B'),
        findsOneWidget,
      );
      // The total sits at the top: 900, with how it adds up and each part's status.
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('order-total'))).data,
        '900',
      );
      expect(find.text('700 + 200 = 900'), findsOneWidget);
      expect(find.text('First order'), findsOneWidget);
      expect(find.text('Extra'), findsOneWidget);
      // History is right under it, before the details and buttons.
      expect(
        tester.getTopLeft(find.text('History')).dy,
        lessThan(tester.getTopLeft(find.text('Where it goes')).dy),
      );
    });

    testWidgets('more than is left cannot be added', (tester) async {
      await pumpScenario(tester);
      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add more pieces'));
      await tester.tap(find.text('Add more pieces'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('order-quantity')),
        '400',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Only 300 available'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'ADD PIECES'),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets(
      'B\'s record keeps 700, then +200, then each step — never one 900',
      (tester) async {
        final repository = await pumpScenario(tester);
        repository.history['b'] = [
          RentalOrderEvent(
            id: 'h-b1',
            at: DateTime(2026, 10, 29, 10, 5),
            title: 'Booked',
            tone: 'progress',
            quantity: 700,
          ),
          RentalOrderEvent(
            id: 'h-b2',
            at: DateTime(2026, 10, 30, 8, 30),
            title: 'On rent',
            tone: 'danger',
            quantity: 700,
          ),
        ];
        await tester.tap(find.text('B'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Add more pieces'));
        await tester.tap(find.text('Add more pieces'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('order-quantity')),
          '200',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'ADD PIECES'));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('History'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(find.text('Booked · 700'), findsOneWidget);
        expect(find.text('On rent · 700'), findsOneWidget);
        expect(find.text('Extra pieces added · 200'), findsOneWidget);
        expect(find.text('Extra pieces · Booked · 200'), findsOneWidget);
        expect(find.textContaining('· 900'), findsNothing);
        expect(find.text('29 Oct, 10:05'), findsOneWidget);
      },
    );

    testWidgets('a finished order offers no extra pieces', (tester) async {
      await pumpScenario(tester);
      await tester.tap(find.text('Old'));
      await tester.pumpAndSettle();

      expect(find.text('Add more pieces'), findsNothing);
    });

    testWidgets('the booking sheet fits a 360dp phone', (tester) async {
      await pumpScenario(tester, size: const Size(360, 740));
      await openNewOrder(tester);
      await setQuantity(tester, '500');
      expect(tester.takeException(), isNull);
    });
  });

  group('Price and advance rules, as the server has them', () {
    final start = DateTime(2026, 11, 1);

    test('days and hours round up and never go below one', () {
      final day = start.add(const Duration(hours: 23, minutes: 59));
      expect(rentalUnits(RentalPriceType.daily, start, day), 1);
      expect(
        rentalUnits(
          RentalPriceType.daily,
          start,
          day.add(const Duration(days: 2)),
        ),
        3,
      );
      expect(
        rentalUnits(
          RentalPriceType.hourly,
          start,
          start.add(const Duration(hours: 2, minutes: 30)),
        ),
        3,
      );
      expect(
        rentalUnits(
          RentalPriceType.fixed,
          start,
          day.add(const Duration(days: 5)),
        ),
        1,
      );
      expect(
        rentalAmount(
          RentalPriceType.daily,
          10,
          100,
          start,
          start.add(const Duration(days: 2, minutes: -1)),
        ),
        2000,
      );
    });

    test('the advance is fixed or per piece, never more than the order', () {
      expect(rentalAdvance(RentalAdvanceType.none, null, 100, 2000), 0);
      expect(rentalAdvance(RentalAdvanceType.perOrder, 500, 100, 2000), 500);
      expect(rentalAdvance(RentalAdvanceType.perPiece, 2, 300, 6000), 600);
      expect(rentalAdvance(RentalAdvanceType.perOrder, 5000, 10, 2000), 2000);
    });

    test('the UPI link pays the amount to the business', () {
      final link = Uri.parse(
        rentalUpiUri(
          upiId: 'joy@okhdfcbank',
          payee: 'Joy Rentals',
          amount: 1500,
          note: 'Rent 100 chairs',
        ),
      );
      expect(link.scheme, 'upi');
      expect(link.host, 'pay');
      expect(link.queryParameters, {
        'pa': 'joy@okhdfcbank',
        'pn': 'Joy Rentals',
        'am': '1500.00',
        'cu': 'INR',
        'tn': 'Rent 100 chairs',
      });
    });

    test(
      'the UPI link keeps the @ and writes spaces as %20, as UPI apps read it',
      () {
        expect(
          rentalUpiUri(
            upiId: 'joy.rentals@okhdfcbank',
            payee: 'Joy Rentals & Co',
            amount: 1500,
            note: 'Rent 100 chairs',
          ),
          'upi://pay?pa=joy.rentals@okhdfcbank&pn=Joy%20Rentals%20%26%20Co'
          '&am=1500.00&cu=INR&tn=Rent%20100%20chairs',
        );
      },
    );

    test('a scanned business QR gives back its UPI ID', () {
      final link = rentalUpiUri(
        upiId: 'ravi-99@ybl',
        payee: 'Ravi',
        amount: 10.5,
        note: 'Advance',
      );
      expect(rentalUpiIdFrom(link), 'ravi-99@ybl');
      expect(Uri.parse(link).queryParameters['am'], '10.50');
    });
  });

  group('Payments: advance, collect by UPI QR or cash, paid before return', () {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    /// 100 chairs at ₹10 a day for 2 days: ₹2,000, with ₹500 advance paid in cash.
    RentalOrder priced(String id, String status, {double paid = 500}) =>
        RentalOrder(
          id: id,
          rentalItemId: 'chairs',
          itemName: 'Plastic chair',
          customerName: 'Rahul',
          quantity: 100,
          startDate: today,
          endDate: today.add(const Duration(days: 2)),
          deliveryAddress: 'Kakkanad',
          status: status,
          statusName: status,
          statusTone: 'waiting',
          isOut: status == 'OnRent',
          priceType: RentalPriceType.daily,
          unitPrice: 10,
          units: 2,
          amount: 2000,
          advanceDue: 500,
          paid: paid,
          payments: [
            if (paid > 0)
              RentalOrderPayment(
                id: 'adv',
                at: today,
                kind: 'Advance',
                methodName: 'Cash',
                amount: paid,
              ),
          ],
        );

    Future<_FakeRentalRepository> pumpPayments(
      WidgetTester tester,
      List<RentalOrder> list, {
      RentalUpiPay? upiPay,
      String? upiId = 'joy@okhdfcbank',
      List<RentalItem>? items,
      Size size = const Size(400, 900),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = _FakeRentalRepository(
        items ??
            [
              _item(
                id: 'chairs',
                name: 'Plastic chair',
                quantity: 1000,
                price: 10,
              ),
            ],
      )..upiId = upiId;
      repository.orders['chairs'] = [
        for (final o in list) repository._withState(o, o.status),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rentalRepositoryProvider.overrideWithValue(repository),
            businessProfileProvider.overrideWith(
              () => _FakeBusinessProfile(repository),
            ),
            rentalUpiPayProvider.overrideWithValue(
              upiPay ??
                  (_) async => throw StateError('No UPI app should open here.'),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: BusinessRentOrdersTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return repository;
    }

    Future<void> openOrder(WidgetTester tester) async {
      await tester.tap(find.text('Rahul'));
      await tester.pumpAndSettle();
    }

    Future<void> openCollect(WidgetTester tester) async {
      await openOrder(tester);
      final collect = find.byKey(const ValueKey('collect-payment'));
      await tester.ensureVisible(collect);
      await tester.tap(collect);
      await tester.pumpAndSettle();
    }

    Finder primary(String label) =>
        find.widgetWithText(FilledButton, label.toUpperCase());

    testWidgets('the order card says what is paid and what is due', (
      tester,
    ) async {
      await pumpPayments(tester, [priced('o1', 'Booked')]);

      expect(
        find.text('${rupees(500)} paid · ${rupees(1500)} due'),
        findsOneWidget,
      );
    });

    testWidgets('the order page shows the total, advance, paid and balance', (
      tester,
    ) async {
      await pumpPayments(tester, [priced('o1', 'Booked')]);
      await openOrder(tester);

      expect(find.byKey(const ValueKey('rental-payment-card')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('payment-amount'))).data,
        rupees(2000),
      );
      expect(find.text('100 × ${rupees(10)} × 2 days'), findsOneWidget);
      expect(find.text('${rupees(500)} · paid'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('payment-balance'))).data,
        rupees(1500),
      );
      expect(find.text('Advance paid'), findsOneWidget);
    });

    testWidgets('Mark returned waits for the balance and says why', (
      tester,
    ) async {
      final repository = await pumpPayments(tester, [priced('o1', 'OnRent')]);
      await openOrder(tester);

      final returned = find.widgetWithText(FilledButton, 'Mark returned');
      await tester.ensureVisible(returned);
      expect(tester.widget<FilledButton>(returned).onPressed, isNull);
      expect(
        find.byKey(const ValueKey('action-reason-Returned')),
        findsOneWidget,
      );
      expect(find.text('Collect ${rupees(1500)} first'), findsOneWidget);
      expect(repository.calls, isEmpty);
    });

    testWidgets(
      'collect opens on the UPI QR for what is due; marking it received settles the order',
      (tester) async {
        final repository = await pumpPayments(tester, [priced('o1', 'OnRent')]);
        await openCollect(tester);

        expect(find.text('Collect payment'), findsOneWidget);
        final qr = tester.widget<RentalUpiQr>(find.byType(RentalUpiQr));
        expect(qr.upiId, 'joy@okhdfcbank');
        expect(qr.amount, 1500);
        expect(find.byType(QrImageView), findsOneWidget);
        expect(find.text('Scan to pay ${rupees(1500)}'), findsOneWidget);

        final mark = primary('Mark ${rupees(1500)} received');
        await tester.ensureVisible(mark);
        await tester.tap(mark);
        await tester.pumpAndSettle();

        expect(repository.calls, ['payment:o1:UpiQr:1500']);
        expect(find.textContaining('has paid in full'), findsOneWidget);
        final returned = find.widgetWithText(FilledButton, 'Mark returned');
        await tester.ensureVisible(returned);
        expect(tester.widget<FilledButton>(returned).onPressed, isNotNull);
      },
    );

    testWidgets(
      'cash can be part of what is due; more than is due is refused',
      (tester) async {
        final repository = await pumpPayments(tester, [priced('o1', 'Booked')]);
        await openCollect(tester);

        await tester.tap(find.text('Cash'));
        await tester.pumpAndSettle();
        expect(find.byType(QrImageView), findsNothing);

        await tester.enterText(
          find.byKey(const ValueKey('payment-amount-field')),
          '5000',
        );
        await tester.pumpAndSettle();
        final tooMuch = primary('Mark ${rupees(5000)} received');
        await tester.ensureVisible(tooMuch);
        await tester.tap(tooMuch);
        await tester.pumpAndSettle();
        expect(find.text('At most ${rupees(1500)}.'), findsOneWidget);
        expect(repository.calls, isEmpty);

        await tester.enterText(
          find.byKey(const ValueKey('payment-amount-field')),
          '600',
        );
        await tester.pumpAndSettle();
        final part = primary('Mark ${rupees(600)} received');
        await tester.ensureVisible(part);
        await tester.tap(part);
        await tester.pumpAndSettle();

        expect(repository.calls, ['payment:o1:Cash:600']);
        expect(find.textContaining('${rupees(900)} still due'), findsOneWidget);
      },
    );

    testWidgets('with no UPI ID the sheet offers to add one, then shows the QR', (
      tester,
    ) async {
      final repository = await pumpPayments(tester, [
        priced('o1', 'Booked'),
      ], upiId: null);
      await openCollect(tester);

      expect(find.byType(QrImageView), findsNothing);
      await tester.tap(find.byKey(const ValueKey('add-upi-id')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('upi-id-field')),
        'not a upi',
      );
      await tester.tap(primary('Save'));
      await tester.pumpAndSettle();
      expect(find.text(upiIdHint), findsOneWidget);

      // Required: an empty ID is not "remove it", it is refused.
      await tester.enterText(find.byKey(const ValueKey('upi-id-field')), '');
      await tester.tap(primary('Save'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter your UPI ID — customers pay you by scanning it.'),
        findsOneWidget,
      );
      expect(repository.calls, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('upi-id-field')),
        'joy@okhdfcbank',
      );
      await tester.tap(primary('Save'));
      await tester.pumpAndSettle();

      // Saved on the business profile — the one place it is kept — and the QR follows.
      expect(repository.calls, ['profile-upi:joy@okhdfcbank']);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(
        find.textContaining('UPI ID saved on your business profile'),
        findsOneWidget,
      );
    });

    testWidgets('a cancelled order holding the advance records the refund', (
      tester,
    ) async {
      final repository = await pumpPayments(tester, [
        priced('o1', 'Cancelled'),
      ]);
      await openOrder(tester);

      expect(find.text('Refund due'), findsOneWidget);
      final refund = find.byKey(const ValueKey('record-refund'));
      await tester.ensureVisible(refund);
      await tester.tap(refund);
      await tester.pumpAndSettle();

      expect(find.text('Give money back'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      // Cash: handed over, then recorded.
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('payment-method')),
          matching: find.text('Cash'),
        ),
      );
      await tester.pumpAndSettle();
      final record = primary('Record ${rupees(500)} given back');
      await tester.ensureVisible(record);
      await tester.tap(record);
      await tester.pumpAndSettle();

      expect(repository.calls, ['payment:o1:Cash:500:refund']);
    });

    /// Paid ₹2,000 online, then cancelled by the customer the day before: ₹40 (2%) kept.
    RentalOrder cancelledByCustomer({String method = 'Online'}) => RentalOrder(
      id: 'o1',
      rentalItemId: 'chairs',
      itemName: 'Plastic chair',
      customerName: 'Rahul',
      quantity: 100,
      startDate: today,
      endDate: today.add(const Duration(days: 2)),
      deliveryAddress: 'Kakkanad',
      status: 'Cancelled',
      statusName: 'Cancelled',
      statusTone: 'waiting',
      isOut: false,
      priceType: RentalPriceType.daily,
      unitPrice: 10,
      units: 2,
      amount: 2000,
      paid: 2000,
      payments: [
        RentalOrderPayment(
          id: 'pay',
          at: today,
          kind: 'Balance',
          methodName: method,
          amount: 2000,
        ),
      ],
      cancelledBy: 'Customer',
      cancellationCharge: 40,
    );

    testWidgets(
      'a customer cancellation shows the charge kept and what to give back',
      (tester) async {
        await pumpPayments(tester, [cancelledByCustomer()]);
        await openOrder(tester);

        final owed = find.byKey(const ValueKey('payment-refund-owed'));
        await tester.ensureVisible(owed);
        expect(tester.widget<Text>(owed).data, rupees(1960));
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('payment-cancel-charge')))
              .data,
          rupees(40),
        );
        expect(
          find.text(
            'The customer cancelled: you keep ${rupees(40)} as the cancellation charge.',
          ),
          findsOneWidget,
        );
        expect(find.text('How will ${rupees(1960)} go back?'), findsOneWidget);
        expect(
          find.text('Record refund of ${rupees(1960)}'),
          findsOneWidget,
          reason: 'until online is chosen, it can be given back by hand',
        );
      },
    );

    testWidgets(
      'choosing online: Zuno sends it, and nothing is recorded by hand',
      (tester) async {
        final repository = await pumpPayments(tester, [cancelledByCustomer()]);
        await openOrder(tester);

        final online = find.byKey(const ValueKey('refund-mode-Online'));
        await tester.ensureVisible(online);
        await tester.tap(online);
        await tester.pumpAndSettle();

        // Asked first: what happens to the money, and to whom.
        expect(find.text('Refund ${rupees(1960)} online?'), findsOneWidget);
        expect(
          find.textContaining('${rupees(1960)} to Rahul. Zuno sends it back'),
          findsOneWidget,
        );
        expect(repository.calls, isEmpty, reason: 'nothing is set before yes');
        await tester.tap(find.widgetWithText(FilledButton, 'Refund online'));
        await tester.pumpAndSettle();

        expect(repository.calls, ['refund-mode:o1:Online']);
        expect(
          find.textContaining('Nothing for you to hand over'),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('record-refund')), findsNothing);
        expect(
          tester.widget<ChoiceChip>(online).selected,
          isTrue,
          reason: 'it can still be changed until money goes back',
        );
      },
    );

    testWidgets('choosing in hand records the refund owed, not all paid', (
      tester,
    ) async {
      final opened = <String>[];
      final repository = await pumpPayments(
        tester,
        [cancelledByCustomer()],
        upiPay: (uri) async {
          opened.add(uri);
          return const UpiPayResult(
            UpiPayStatus.success,
            reference: '431256789012',
          );
        },
      );
      await openOrder(tester);

      final inHand = find.byKey(const ValueKey('refund-mode-InHand'));
      await tester.ensureVisible(inHand);
      await tester.tap(inHand);
      await tester.pumpAndSettle();
      expect(find.text('Give ${rupees(1960)} back in hand?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Give in hand'));
      await tester.pumpAndSettle();
      final refund = find.byKey(const ValueKey('record-refund'));
      await tester.ensureVisible(refund);
      await tester.tap(refund);
      await tester.pumpAndSettle();
      // UPI: pay the customer's UPI ID from the business's UPI app; SUCCESS records it.
      await tester.enterText(
        find.byKey(const ValueKey('refund-upi-id')),
        'rahul@okaxis',
      );
      final pay = primary('Pay ${rupees(1960)} by UPI');
      await tester.ensureVisible(pay);
      await tester.tap(pay);
      await tester.pumpAndSettle();

      final uri = Uri.parse(opened.single);
      expect(uri.queryParameters['pa'], 'rahul@okaxis');
      expect(uri.queryParameters['am'], '1960.00');
      expect(repository.calls, [
        'refund-mode:o1:InHand',
        'payment:o1:UpiQr:1960:refund:to=rahul@okaxis:ref=431256789012',
      ]);
      expect(find.byKey(const ValueKey('refund-mode-InHand')), findsNothing);
    });

    testWidgets('backing out of the refund question sets nothing', (
      tester,
    ) async {
      final repository = await pumpPayments(tester, [cancelledByCustomer()]);
      await openOrder(tester);

      final online = find.byKey(const ValueKey('refund-mode-Online'));
      await tester.ensureVisible(online);
      await tester.tap(online);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(repository.calls, isEmpty);
      expect(tester.widget<ChoiceChip>(online).selected, isFalse);
      expect(find.byKey(const ValueKey('record-refund')), findsOneWidget);
    });

    testWidgets('changing the refund method asks again', (tester) async {
      final repository = await pumpPayments(tester, [cancelledByCustomer()]);
      await openOrder(tester);

      final online = find.byKey(const ValueKey('refund-mode-Online'));
      await tester.ensureVisible(online);
      await tester.tap(online);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Refund online'));
      await tester.pumpAndSettle();

      final inHand = find.byKey(const ValueKey('refund-mode-InHand'));
      await tester.ensureVisible(inHand);
      await tester.tap(inHand);
      await tester.pumpAndSettle();

      expect(find.text('Change the refund to in hand?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Give in hand'));
      await tester.pumpAndSettle();
      expect(repository.calls, [
        'refund-mode:o1:Online',
        'refund-mode:o1:InHand',
      ]);
    });

    testWidgets(
      'cancelling a paid order asks online or in hand, and waits for a choice',
      (tester) async {
        final repository = await pumpPayments(tester, [
          priced('o1', 'Booked'),
        ], size: const Size(400, 1400));
        await openOrder(tester);

        await tester.ensureVisible(find.text('Cancel order'));
        await tester.tap(find.text('Cancel order'));
        await tester.pumpAndSettle();

        expect(find.text('How will ${rupees(500)} go back?'), findsOneWidget);
        expect(find.text('Choose one to cancel the order.'), findsOneWidget);
        final confirm = find.byKey(const ValueKey('cancel-refund-confirm'));
        expect(
          tester.widget<FilledButton>(confirm).onPressed,
          isNull,
          reason: 'cancel stays off until a way back is chosen',
        );
        // Paid in cash: online is not offered, and says why.
        expect(
          tester
              .widget<ListTile>(
                find.byKey(const ValueKey('cancel-refund-Online')),
              )
              .enabled,
          isFalse,
        );
        expect(
          find.text(
            'The customer paid in cash or by UPI, so give the refund in hand.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('cancel-refund-Online')));
        await tester.pump();
        expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

        await tester.tap(find.byKey(const ValueKey('cancel-refund-InHand')));
        await tester.pump();
        expect(find.text('Choose one to cancel the order.'), findsNothing);
        await tester.tap(confirm);
        await tester.pumpAndSettle();

        expect(repository.calls, ['order:o1:Cancelled:InHand']);
      },
    );

    testWidgets('keeping the order from the refund question changes nothing', (
      tester,
    ) async {
      final repository = await pumpPayments(tester, [
        priced('o1', 'Booked'),
      ], size: const Size(400, 1400));
      await openOrder(tester);

      await tester.ensureVisible(find.text('Cancel order'));
      await tester.tap(find.text('Cancel order'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cancel-refund-InHand')));
      await tester.pump();
      await tester.tap(find.text('Keep order'));
      await tester.pumpAndSettle();

      expect(repository.calls, isEmpty);
    });

    testWidgets('an unpaid order cancels with the plain question', (
      tester,
    ) async {
      final repository = await pumpPayments(tester, [
        priced('o1', 'Booked', paid: 0),
      ], size: const Size(400, 1400));
      await openOrder(tester);

      await tester.ensureVisible(find.text('Cancel order'));
      await tester.tap(find.text('Cancel order'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('cancel-refund-confirm')), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel order'));
      await tester.pumpAndSettle();
      expect(repository.calls, ['order:o1:Cancelled']);
    });

    /// S7-like: in hand chosen, the refund sheet open on UPI.
    Future<_FakeRentalRepository> openUpiRefund(
      WidgetTester tester,
      RentalUpiPay upiPay,
    ) async {
      final repository = await pumpPayments(tester, [
        cancelledByCustomer(),
      ], upiPay: upiPay);
      await openOrder(tester);
      final inHand = find.byKey(const ValueKey('refund-mode-InHand'));
      await tester.ensureVisible(inHand);
      await tester.tap(inHand);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Give in hand'));
      await tester.pumpAndSettle();
      final refund = find.byKey(const ValueKey('record-refund'));
      await tester.ensureVisible(refund);
      await tester.tap(refund);
      await tester.pumpAndSettle();
      repository.calls.clear();
      return repository;
    }

    Future<void> payToRahul(WidgetTester tester) async {
      await tester.enterText(
        find.byKey(const ValueKey('refund-upi-id')),
        'rahul@okaxis',
      );
      final pay = primary('Pay ${rupees(1960)} by UPI');
      await tester.ensureVisible(pay);
      await tester.tap(pay);
      await tester.pumpAndSettle();
    }

    testWidgets('a UPI refund needs the customer UPI ID before paying', (
      tester,
    ) async {
      var opened = 0;
      final repository = await openUpiRefund(tester, (_) async {
        opened++;
        return const UpiPayResult(UpiPayStatus.success);
      });

      final pay = primary('Pay ${rupees(1960)} by UPI');
      await tester.ensureVisible(pay);
      await tester.tap(pay);
      await tester.pumpAndSettle();
      expect(find.text("Scan or type the customer's UPI ID."), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('refund-upi-id')),
        'rahul',
      );
      await tester.tap(pay);
      await tester.pumpAndSettle();
      expect(find.text('Enter a UPI ID like name@bank.'), findsOneWidget);
      expect(opened, 0);
      expect(repository.calls, isEmpty);
      expect(
        find.byKey(const ValueKey('refund-upi-scan')),
        findsOneWidget,
        reason: 'the camera can read it off the customer\'s UPI QR',
      );
    });

    testWidgets('an unclear UPI answer asks the business to confirm', (
      tester,
    ) async {
      final repository = await openUpiRefund(
        tester,
        (_) async =>
            const UpiPayResult(UpiPayStatus.unknown, reference: 'AXI98765'),
      );

      await payToRahul(tester);

      expect(repository.calls, isEmpty, reason: 'nothing recorded unasked');
      expect(
        find.text(
          'Did ${rupees(1960)} reach Rahul? Check your UPI app before you confirm.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('refund-upi-reference')),
            )
            .controller!
            .text,
        'AXI98765',
      );
      final yes = primary('Yes, record ${rupees(1960)} given back');
      await tester.ensureVisible(yes);
      await tester.tap(yes);
      await tester.pumpAndSettle();

      expect(repository.calls, [
        'payment:o1:UpiQr:1960:refund:to=rahul@okaxis:ref=AXI98765',
      ]);
    });

    testWidgets('a failed UPI payment records nothing', (tester) async {
      final repository = await openUpiRefund(
        tester,
        (_) async => const UpiPayResult(UpiPayStatus.failure),
      );

      await payToRahul(tester);

      expect(
        find.text(
          'The UPI app says ${rupees(1960)} did not go. Nothing was recorded.',
        ),
        findsOneWidget,
      );
      expect(repository.calls, isEmpty);
      expect(primary('Pay ${rupees(1960)} by UPI'), findsOneWidget);
    });

    test('UPI app answers are read leniently', () {
      final ok = UpiPay.parse(
        'txnId=AXI123456&responseCode=00&Status=SUCCESS&txnRef=ZR42',
      );
      expect(ok.status, UpiPayStatus.success);
      expect(ok.reference, 'AXI123456');
      expect(
        UpiPay.parse('status=success&ApprovalRefNo=431256789012').reference,
        '431256789012',
        reason: 'the bank approval number wins',
      );
      expect(
        UpiPay.parse('Status=FAILURE&txnId=AXI1').status,
        UpiPayStatus.failure,
      );
      expect(UpiPay.parse(null).status, UpiPayStatus.unknown);
      expect(UpiPay.parse(null, cancelled: true).status, UpiPayStatus.failure);
      expect(
        UpiPay.parse('Status=SUBMITTED&txnId=AXI9').status,
        UpiPayStatus.unknown,
      );
      expect(
        UpiPay.parse('Status=SUCCESS&txnId=a b').reference,
        isNull,
        reason: 'only a usable reference is kept',
      );
    });

    test('the customer UPI ID is read from their QR or as typed', () {
      expect(
        rentalUpiIdFrom('upi://pay?pa=rahul@okaxis&pn=Rahul%20Nair&cu=INR'),
        'rahul@okaxis',
      );
      expect(rentalUpiIdFrom(' anu.k@ybl '), 'anu.k@ybl');
      expect(rentalUpiIdFrom('https://example.com/menu'), isNull);
      expect(rentalUpiIdFrom('upi://pay?pn=NoId'), isNull);
    });

    testWidgets('money paid in cash cannot go back online', (tester) async {
      final repository = await pumpPayments(tester, [
        cancelledByCustomer(method: 'Cash'),
      ]);
      await openOrder(tester);

      final online = find.byKey(const ValueKey('refund-mode-Online'));
      await tester.ensureVisible(online);
      expect(tester.widget<ChoiceChip>(online).onSelected, isNull);
      expect(
        find.text(
          'The customer paid in cash or by UPI, so give the refund in hand.',
        ),
        findsOneWidget,
      );
      await tester.tap(online);
      await tester.pumpAndSettle();
      expect(repository.calls, isEmpty);
    });

    testWidgets('the business cancelling is told everything goes back', (
      tester,
    ) async {
      await pumpPayments(tester, [
        priced('o1', 'Booked'),
      ], size: const Size(400, 1400));
      await openOrder(tester);

      await tester.ensureVisible(find.text('Cancel order'));
      await tester.tap(find.text('Cancel order'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'The customer gets back all ${rupees(500)} they paid.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'a paid order the business cancels is easy to find and give back',
      (tester) async {
        await pumpPayments(tester, [
          priced('o1', 'Booked'),
        ], size: const Size(400, 1400));
        expect(
          find.byKey(const ValueKey('rent-filter-RefundDue')),
          findsNothing,
          reason: 'the filter shows only while money is owed back',
        );
        await openOrder(tester);

        await tester.ensureVisible(find.text('Cancel order'));
        await tester.tap(find.text('Cancel order'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('cancel-refund-InHand')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('cancel-refund-confirm')));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Order cancelled. Give back ${rupees(500)} to Rahul: it waits '
            'under Status management and the Refund due filter.',
          ),
          findsOneWidget,
        );

        await tester.pageBack();
        await tester.pumpAndSettle();
        final filter = find.byKey(const ValueKey('rent-filter-RefundDue'));
        expect(
          find.descendant(of: filter, matching: find.text('Refund due · 1')),
          findsOneWidget,
        );
        expect(
          find.text('All · 1'),
          findsOneWidget,
          reason: 'Refund due is not added into All',
        );
        await tester.tap(filter);
        await tester.pumpAndSettle();
        expect(
          find.text('Give back ${rupees(500)} · you cancelled'),
          findsOneWidget,
        );

        await tester.tap(find.text('Status management'));
        await tester.pumpAndSettle();
        final giveBack = find.byKey(const ValueKey('give-back-o1'));
        expect(giveBack, findsOneWidget);
        await tester.tap(giveBack);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('refund-mode-InHand')),
          findsOneWidget,
          reason: 'the button opens the order, where the refund is given',
        );
      },
    );

    testWidgets(
      'once the refund goes online it leaves the to-do but stays refund due',
      (tester) async {
        await pumpPayments(tester, [
          cancelledByCustomer(),
        ], size: const Size(400, 1400));

        await tester.tap(find.text('Status management'));
        await tester.pumpAndSettle();
        expect(
          find.text('Choose how to refund ${rupees(1960)}'),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('give-back-o1')));
        await tester.pumpAndSettle();
        final online = find.byKey(const ValueKey('refund-mode-Online'));
        await tester.ensureVisible(online);
        await tester.tap(online);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Refund online'));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('give-back-o1')), findsNothing);
        await tester.tap(find.text('Bookings'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Refund ${rupees(1960)} goes back online · customer cancelled',
          ),
          findsOneWidget,
        );
        expect(find.text('Refund due · 1'), findsOneWidget);
      },
    );

    test('the customer is told what comes back right after cancelling', () {
      RentalOrder cancelled({double charge = 0}) => RentalOrder(
        id: 'o1',
        customerName: 'Rahul',
        quantity: 1,
        startDate: DateTime(2026, 11, 5),
        endDate: DateTime(2026, 11, 6),
        deliveryAddress: 'Hall',
        status: 'Cancelled',
        statusName: 'Cancelled',
        statusTone: 'waiting',
        isOut: false,
        refundOwed: 380,
        cancellationCharge: charge,
      );

      expect(
        rentalCancelledMoneyNote(
          cancelled(charge: 120),
          RentalAudience.customer,
        ),
        'Cancelled. ${rupees(380)} comes back to you; ${rupees(120)} is kept '
        'as the cancellation charge.',
      );
      expect(
        rentalCancelledMoneyNote(cancelled(), RentalAudience.customer),
        'Cancelled. All ${rupees(380)} you paid comes back to you.',
      );
    });

    testWidgets(
      'an offline order shows its total and takes the items advance as cash',
      (tester) async {
        final repository = await pumpPayments(
          tester,
          const [],
          items: [
            _item(
              id: 'chairs',
              name: 'Plastic chair',
              quantity: 1000,
              price: 10,
              advanceType: RentalAdvanceType.perOrder,
              advanceAmount: 500,
            ),
          ],
        );
        await tester.tap(find.text('Offline order'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Choose the item'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Plastic chair').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('order-quantity')),
          '100',
        );
        await tester.pumpAndSettle();

        // Today to tomorrow: 100 × ₹10 × 2 days.
        expect(find.text('Total ${rupees(2000)}'), findsOneWidget);
        expect(
          find.text(
            'Advance ${rupees(500)} now · ${rupees(1500)} before the return',
          ),
          findsOneWidget,
        );
        expect(
          find.byType(QrImageView),
          findsOneWidget,
          reason: 'UPI QR first',
        );

        await tester.ensureVisible(find.text('Cash'));
        await tester.tap(find.text('Cash'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Customer name'),
          'Anu',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Where it goes'),
          'Town Hall',
        );
        final book = primary('Book');
        await tester.ensureVisible(book);
        await tester.tap(book);
        await tester.pumpAndSettle();

        // Never booked as paid on a guess: the business is asked first.
        expect(find.text('Received ${rupees(500)}?'), findsOneWidget);
        expect(repository.calls, isEmpty);
        await tester.tap(find.byKey(const ValueKey('advance-received')));
        await tester.pumpAndSettle();

        expect(repository.calls, ['create-order:chairs:100:Cash:received']);
        expect(
          find.textContaining('Advance ${rupees(500)} received.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'an advance not yet received still confirms the order, to collect later',
      (tester) async {
        final repository = await pumpPayments(
          tester,
          const [],
          items: [
            _item(
              id: 'chairs',
              name: 'Plastic chair',
              quantity: 1000,
              price: 10,
              advanceType: RentalAdvanceType.perOrder,
              advanceAmount: 500,
            ),
          ],
        );
        await tester.tap(find.text('Offline order'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Choose the item'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Plastic chair').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('order-quantity')),
          '100',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Customer name'),
          'Anu',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Where it goes'),
          'Town Hall',
        );
        await tester.pumpAndSettle();
        final book = primary('Book');
        await tester.ensureVisible(book);
        await tester.tap(book);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Check your UPI app shows ${rupees(500)}'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('advance-not-yet')));
        await tester.pumpAndSettle();

        expect(repository.calls, ['create-order:chairs:100:UpiQr']);
        expect(
          find.textContaining(
            'Order confirmed: 100 × Plastic chair for Anu. '
            'Advance ${rupees(500)} to collect from the order.',
          ),
          findsOneWidget,
        );
        final booked = repository.orders['chairs']!.single;
        expect(booked.status, 'Booked', reason: 'confirmed, not held');
        expect(booked.holdUntil, isNull);
        expect(booked.paid, 0);
        expect(booked.payments, isEmpty);

        // The business takes the money from the order once it arrives.
        await tester.tap(find.text('Anu'));
        await tester.pumpAndSettle();
        final collect = find.byKey(const ValueKey('collect-payment'));
        await tester.ensureVisible(collect);
        // The whole order is due — the advance with the rest.
        expect(find.text('Collect ${rupees(booked.amount)}'), findsOneWidget);
      },
    );

    testWidgets(
      'an item with no advance books without asking how it was paid',
      (tester) async {
        final repository = await pumpPayments(tester, const []);
        await tester.tap(find.text('Offline order'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Choose the item'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Plastic chair').last);
        await tester.pumpAndSettle();

        expect(
          find.text('No advance: everything is paid before the return.'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('offline-advance-method')),
          findsNothing,
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Customer name'),
          'Anu',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Where it goes'),
          'Town Hall',
        );
        final book = primary('Book');
        await tester.ensureVisible(book);
        await tester.tap(book);
        await tester.pumpAndSettle();

        expect(repository.calls, ['create-order:chairs:1']);
      },
    );

    /// Opens the offline order for 100 chairs at ₹10 a day, today to tomorrow: ₹2,000.
    Future<_FakeRentalRepository> offlineChairs(
      WidgetTester tester, {
      String advanceType = RentalAdvanceType.none,
      double? advanceAmount,
    }) async {
      final repository = await pumpPayments(
        tester,
        const [],
        items: [
          _item(
            id: 'chairs',
            name: 'Plastic chair',
            quantity: 1000,
            price: 10,
            advanceType: advanceType,
            advanceAmount: advanceAmount,
          ),
        ],
      );
      await tester.tap(find.text('Offline order'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose the item'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plastic chair').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('order-quantity')),
        '100',
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Customer name'),
        'Anu',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Where it goes'),
        'Town Hall',
      );
      await tester.pumpAndSettle();
      return repository;
    }

    final advanceField = find.byKey(const ValueKey('offline-advance-amount'));

    String typedAdvance(WidgetTester tester) =>
        tester.widget<TextFormField>(advanceField).controller!.text;

    /// Taps Book and, when asked whether the advance is in hand, answers [received].
    Future<void> book(WidgetTester tester, {bool received = true}) async {
      final button = primary('Book');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      final answer = find.byKey(
        ValueKey(received ? 'advance-received' : 'advance-not-yet'),
      );
      if (answer.evaluate().isNotEmpty) {
        await tester.tap(answer);
        await tester.pumpAndSettle();
      }
    }

    testWidgets(
      'the advance is filled in with the items own and follows the pieces',
      (tester) async {
        await offlineChairs(
          tester,
          advanceType: RentalAdvanceType.perPiece,
          advanceAmount: 2,
        );

        expect(typedAdvance(tester), '200');
        await tester.enterText(
          find.byKey(const ValueKey('order-quantity')),
          '150',
        );
        await tester.pumpAndSettle();
        expect(typedAdvance(tester), '300');
      },
    );

    testWidgets(
      'an advance typed for an item that asks none shows the QR for that amount',
      (tester) async {
        final repository = await offlineChairs(tester);
        expect(typedAdvance(tester), isEmpty);

        await tester.enterText(advanceField, '750');
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Advance ${rupees(750)} now · ${rupees(1250)} before the return',
          ),
          findsOneWidget,
        );
        // Scanned, the customer's UPI app opens with ₹750 already filled in.
        final qr = tester.widget<RentalUpiQr>(find.byType(RentalUpiQr));
        expect(qr.amount, 750);
        expect(qr.upiId, 'joy@okhdfcbank');
        // The business's own name, as the customer's UPI app shows it.
        expect(qr.payee, 'Joy Rentals');

        // Typing on: the pieces no longer reset it.
        await tester.enterText(
          find.byKey(const ValueKey('order-quantity')),
          '120',
        );
        await tester.pumpAndSettle();
        expect(typedAdvance(tester), '750');

        await book(tester);
        expect(repository.calls, ['create-order:chairs:120:UpiQr:received']);
      },
    );

    testWidgets(
      'an advance below what the item asks or above the total is refused',
      (tester) async {
        final repository = await offlineChairs(
          tester,
          advanceType: RentalAdvanceType.perOrder,
          advanceAmount: 500,
        );

        await tester.enterText(advanceField, '400');
        await book(tester);
        expect(
          find.text('At least ${rupees(500)}: the item asks it.'),
          findsOneWidget,
        );
        // No QR to scan, nor a summary, for an amount the order cannot take.
        expect(find.byType(RentalUpiQr), findsNothing);
        expect(find.byKey(const ValueKey('offline-advance')), findsNothing);

        await tester.enterText(advanceField, '2500');
        await book(tester);
        expect(find.byType(RentalUpiQr), findsNothing);
        expect(find.byKey(const ValueKey('offline-advance')), findsNothing);
        expect(
          find.text('Not more than the total, ${rupees(2000)}.'),
          findsOneWidget,
        );
        expect(repository.calls, isEmpty);

        await tester.enterText(advanceField, '800');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Cash'));
        await tester.tap(find.text('Cash'));
        await tester.pumpAndSettle();
        await book(tester);
        expect(repository.calls, ['create-order:chairs:100:Cash:received']);
        expect(
          find.textContaining('Advance ${rupees(800)} received.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('the advance amount is sent as typed', (tester) async {
      final input = <RentalOrderInput>[];
      final repository = await offlineChairs(tester);
      repository.onCreate = input.add;

      await tester.enterText(advanceField, '99.50');
      await tester.pumpAndSettle();
      await book(tester);

      expect(input.single.advanceAmount, 99.5);
      expect(input.single.toJson()['advanceAmount'], 99.5);
      expect(input.single.toJson()['advanceMethod'], RentalPaymentMethod.upiQr);
    });

    testWidgets('the collect sheet fits a 360dp phone', (tester) async {
      await pumpPayments(tester, [
        priced('o1', 'Booked'),
      ], size: const Size(360, 640));
      await openCollect(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(QrImageView), findsOneWidget);
    });
  });

  group('fits a 360dp phone', () {
    testWidgets('list and form lay out without overflow', (tester) async {
      await _pump(
        tester,
        const BusinessCatalogTab(),
        items: [
          _item(
            name: 'Very long rent item name for a narrow phone screen',
            available: false,
          ),
        ],
        size: const Size(360, 740),
      );
      await tester.tap(find.text('Rent'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Add rent item'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Per hour'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add').last);
      await tester.tap(find.text('Add').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}

class _ThrowingStockRepository extends _FakeRentalRepository {
  _ThrowingStockRepository(super.items);

  @override
  Future<RentalItem> updateStock(
    String id, {
    required int quantityOwned,
    required bool isAvailable,
  }) async => throw Exception('Rent is down');
}

/// The business profile, where the UPI ID is kept. Saving it is seen by Rent at once, as the server
/// does by reading the profile when asked for the order QR's UPI ID.
class _FakeBusinessProfile extends BusinessProfileNotifier {
  _FakeBusinessProfile(this._rent);

  final _FakeRentalRepository _rent;

  @override
  Future<BusinessProfile> build() async => _profile(_rent.upiId);

  @override
  Future<void> setUpiId(String upiId) async {
    _rent.calls.add('profile-upi:$upiId');
    _rent.upiId = upiId;
    state = AsyncData(_profile(upiId));
  }

  static BusinessProfile _profile(String? upiId) => BusinessProfile(
    id: 'b1',
    businessName: 'Joy Rentals',
    verificationStatus: 'Verified',
    upiId: upiId,
    missingDetails: upiId == null ? const ['UPI ID'] : const [],
  );
}
