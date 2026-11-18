import 'dart:typed_data';

import 'package:zuno/features/marketplace/domain/entities/marketplace_order.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/domain/marketplace_order_repository.dart';

/// The order statuses as the server's table names and colours them, in chip order.
const testOrderStatuses = [
  MarketplaceOption(code: 'Placed', name: 'New', tone: 'danger'),
  MarketplaceOption(
    code: 'AwaitingPayment',
    name: 'Awaiting payment',
    tone: 'waiting',
  ),
  MarketplaceOption(code: 'Confirmed', name: 'Confirmed', tone: 'progress'),
  MarketplaceOption(code: 'Shipped', name: 'Shipped', tone: 'progress'),
  MarketplaceOption(
    code: 'OutForDelivery',
    name: 'Out for delivery',
    tone: 'progress',
  ),
  MarketplaceOption(code: 'Delivered', name: 'Delivered', tone: 'success'),
  MarketplaceOption(code: 'Closed', name: 'Closed', tone: 'success'),
  MarketplaceOption(code: 'Cancelled', name: 'Cancelled', tone: 'waiting'),
];

const testB2BStatuses = [
  MarketplaceOption(code: 'Requested', name: 'New', tone: 'danger'),
  MarketplaceOption(code: 'Accepted', name: 'Accepted', tone: 'success'),
  MarketplaceOption(code: 'Declined', name: 'Declined', tone: 'waiting'),
];

const testPaymentMethods = [
  MarketplaceOption(
    code: 'CashOnDelivery',
    name: 'Cash on delivery',
    detail: 'The customer pays the courier or you when it arrives.',
  ),
  MarketplaceOption(
    code: 'Online',
    name: 'Online pay',
    detail:
        'UPI, cards and net banking. The order is confirmed only after the payment goes through.',
  ),
];

const testCouriers = [
  MarketplaceCourier(code: 'india-post', name: 'India Post'),
  MarketplaceCourier(code: 'dtdc', name: 'DTDC'),
  MarketplaceCourier(
    code: 'delhivery',
    name: 'Delhivery',
    hasTrackingLink: true,
  ),
  MarketplaceCourier(code: 'other', name: 'Other', takesCustomName: true),
];

/// The next steps the server's transitions table gives the business from [status].
List<MarketplaceOrderAction> testOrderActions(String status) =>
    switch (status) {
      'Placed' => const [
        MarketplaceOrderAction(toStatus: 'Confirmed', name: 'Confirm order'),
      ],
      'Confirmed' => const [
        MarketplaceOrderAction(
          toStatus: 'Shipped',
          name: 'Mark shipped',
          needsTracking: true,
        ),
      ],
      'Shipped' => const [
        MarketplaceOrderAction(
          toStatus: 'OutForDelivery',
          name: 'Out for delivery',
        ),
        MarketplaceOrderAction(
          toStatus: 'Delivered',
          name: 'Mark delivered',
          needsConfirm: true,
        ),
      ],
      'OutForDelivery' => const [
        MarketplaceOrderAction(
          toStatus: 'Delivered',
          name: 'Mark delivered',
          needsConfirm: true,
        ),
      ],
      _ => const [],
    };

MarketplaceOrder testOrder({
  String id = 'o-1',
  String status = 'Placed',
  String title = 'Silk saree',
  String? variantName = 'Red',
  int quantity = 2,
  double unitPrice = 2400,
  String paymentMethod = 'CashOnDelivery',
  bool isPaid = false,
  double dueToBusiness = 0,
  String customerName = 'Priya S',
  String? courierName,
  String? trackingNumber,
  String? trackingUrl,
  String? cancelledBy,
  int? ratingScore,
  String? ratingComment,
  DateTime? closesAt,
  List<MarketplaceOrderEvent> events = const [],
}) {
  final option = testOrderStatuses.firstWhere((s) => s.code == status);
  return MarketplaceOrder(
    id: id,
    number: id.toUpperCase().replaceAll('-', ''),
    postId: 'p-1',
    title: title,
    variantName: variantName,
    quantity: quantity,
    unitPrice: unitPrice,
    amount: unitPrice * quantity,
    paymentMethod: paymentMethod,
    paymentMethodName: paymentMethod == 'Online'
        ? 'Online pay'
        : 'Cash on delivery',
    isPaid: isPaid,
    dueToBusiness: dueToBusiness,
    status: status,
    statusName: option.name,
    statusTone: option.tone!,
    customerName: customerName,
    customerPhone: '9876543210',
    deliveryAddress: '12, North Street, Nagercoil',
    pincode: '629001',
    courierName: courierName,
    trackingNumber: trackingNumber,
    trackingUrl: trackingUrl,
    cancelledBy: cancelledBy,
    ratingScore: ratingScore,
    ratingComment: ratingComment,
    closesAt: closesAt,
    createdDate: DateTime(2026, 11, 18, 10, 40),
    actions: testOrderActions(status),
    events: events,
  );
}

MarketplaceB2BRequest testRequest({
  String id = 'r-1',
  String status = 'Requested',
  String? buyerPhone,
}) {
  final option = testB2BStatuses.firstWhere((s) => s.code == status);
  return MarketplaceB2BRequest(
    id: id,
    number: id.toUpperCase().replaceAll('-', ''),
    postId: 'p-b2b',
    title: 'Nendran banana',
    quantity: 500,
    unit: 'kg',
    unitPrice: 38,
    total: 19000,
    minOrderQuantity: 200,
    message: 'Weekly supply to Thuckalay?',
    status: status,
    statusName: option.name,
    statusTone: option.tone!,
    buyerName: 'Kumar Traders',
    buyerPhone: buyerPhone,
    sellerName: status == 'Accepted' ? 'Joy Silks' : null,
    createdDate: DateTime(2026, 11, 18),
  );
}

/// Orders and requests kept in memory, moved along the way the server would.
class FakeMarketplaceOrderRepository implements MarketplaceOrderRepository {
  FakeMarketplaceOrderRepository({
    List<MarketplaceOrder> orders = const [],
    List<MarketplaceB2BRequest> requests = const [],
    this.settings = const MarketplacePaymentSettings(
      acceptsCashOnDelivery: true,
      acceptsOnlinePay: true,
    ),
  }) : orders = [...orders],
       requests = [...requests];

  final List<MarketplaceOrder> orders;
  final List<MarketplaceB2BRequest> requests;
  MarketplacePaymentSettings settings;

  final List<String> steps = [];
  final List<
    ({
      String id,
      String courierCode,
      String? courierName,
      String trackingNumber,
    })
  >
  shipped = [];
  final List<String> receipts = [];
  final List<({String id, bool accept})> answers = [];

  List<MarketplaceStatusCount> _counts<T>(
    List<MarketplaceOption> statuses,
    Iterable<String> of,
  ) => [
    for (final s in statuses)
      MarketplaceStatusCount(
        status: s.code,
        count: of.where((x) => x == s.code).length,
      ),
  ];

  @override
  Future<MarketplaceOrderPage> getOrders({String? status}) async {
    final items = orders
        .where((o) => status == null || o.status == status)
        .toList();
    return MarketplaceOrderPage(
      items: items,
      totalCount: items.length,
      counts: _counts(testOrderStatuses, orders.map((o) => o.status)),
    );
  }

  @override
  Future<MarketplaceOrder> getOrder(String id) async =>
      orders.firstWhere((o) => o.id == id);

  void _replace(MarketplaceOrder order) {
    final index = orders.indexWhere((o) => o.id == order.id);
    orders[index] = order;
  }

  @override
  Future<MarketplaceOrder> changeStatus(String id, String status) async {
    steps.add('$id→$status');
    final old = orders.firstWhere((o) => o.id == id);
    final changed = testOrder(
      id: id,
      status: status,
      courierName: old.courierName,
      trackingNumber: old.trackingNumber,
      isPaid: status == 'Delivered' || old.isPaid,
    );
    _replace(changed);
    return changed;
  }

  @override
  Future<MarketplaceOrder> ship(
    String id, {
    required String courierCode,
    required String trackingNumber,
    String? courierName,
  }) async {
    shipped.add((
      id: id,
      courierCode: courierCode,
      courierName: courierName,
      trackingNumber: trackingNumber,
    ));
    final name =
        courierName ??
        testCouriers.firstWhere((c) => c.code == courierCode).name;
    final changed = testOrder(
      id: id,
      status: 'Shipped',
      courierName: name,
      trackingNumber: trackingNumber,
    );
    _replace(changed);
    return changed;
  }

  @override
  Future<MarketplaceOrder> uploadReceipt(String id, Uint8List bytes) async {
    receipts.add(id);
    return orders.firstWhere((o) => o.id == id);
  }

  @override
  Future<MarketplacePaymentSettings> getPaymentSettings() async => settings;

  @override
  Future<MarketplacePaymentSettings> updatePaymentSettings({
    required bool acceptsCashOnDelivery,
    required bool acceptsOnlinePay,
  }) async => settings = MarketplacePaymentSettings(
    acceptsCashOnDelivery: acceptsCashOnDelivery,
    acceptsOnlinePay: acceptsOnlinePay,
  );

  @override
  Future<MarketplaceB2BRequestPage> getB2BRequests({String? status}) async {
    final items = requests
        .where((r) => status == null || r.status == status)
        .toList();
    return MarketplaceB2BRequestPage(
      items: items,
      totalCount: items.length,
      counts: _counts(testB2BStatuses, requests.map((r) => r.status)),
    );
  }

  @override
  Future<MarketplaceB2BRequest> answerB2BRequest(
    String id, {
    required bool accept,
  }) async {
    answers.add((id: id, accept: accept));
    final changed = testRequest(
      id: id,
      status: accept ? 'Accepted' : 'Declined',
      buyerPhone: accept ? '9843012345' : null,
    );
    requests[requests.indexWhere((r) => r.id == id)] = changed;
    return changed;
  }
}
