import 'package:zuno/features/marketplace/data/marketplace_remote_datasource.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_customer.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_order.dart';

/// What a customer orders: the delivery details and how they pay.
class MarketplaceOrderInput {
  const MarketplaceOrderInput({
    required this.postId,
    required this.quantity,
    required this.paymentMethod,
    required this.deliveryAddress,
    required this.pincode,
    this.variantId,
    this.phone,
  });

  final String postId;
  final String? variantId;
  final int quantity;

  /// `CashOnDelivery` or `Online`.
  final String paymentMethod;

  /// The mobile the courier calls; the account's own when null.
  final String? phone;
  final String deliveryAddress;
  final String pincode;

  Map<String, dynamic> toJson() => {
    'postId': postId,
    'variantId': ?variantId,
    'quantity': quantity,
    'paymentMethod': paymentMethod,
    'phone': ?phone,
    'deliveryAddress': deliveryAddress,
    'pincode': pincode,
  };
}

/// The customer's side of Marketplace: browse, save, order, pay, track, review, ask for B2B lots.
abstract interface class MarketplaceCustomerRepository {
  /// Food and adverts are local: [districtIds] keeps them to the customer's districts.
  Future<MarketplaceHome> getHome({List<String>? districtIds});

  /// Matching posts a page at a time. [feed] is the home's last section: products and B2B lots
  /// from everywhere, food in [districtIds], no adverts.
  Future<MarketplaceCardPage> search({
    String? kind,
    bool? wholesale,
    String? categoryId,
    String? keyword,
    List<String>? districtIds,
    bool feed = false,
    int page = 1,
    int? pageSize,
  });

  Future<MarketplacePostDetail> getPost(String id);

  Future<MarketplaceCardPage> getFavourites({int page = 1});

  /// Saves or un-saves a post; doing it twice is the same as once.
  Future<void> setFavourite(String postId, {required bool saved});

  Future<MarketplaceOrderPage> getMyOrders({String? status});

  Future<MarketplaceOrder> getMyOrder(String id);

  Future<MarketplaceOrder> placeOrder(MarketplaceOrderInput input);

  Future<MarketplaceCheckout> startPayment(String orderId);

  Future<MarketplaceOrder> confirmPayment(
    String orderId, {
    required String providerOrderId,
    required String paymentId,
    required String signature,
  });

  Future<MarketplaceOrder> cancel(String orderId);

  Future<MarketplaceOrder> review(String orderId, int score, String? comment);

  Future<MarketplaceB2BRequestPage> getMyRequests();

  Future<MarketplaceB2BRequest> askForLot(
    String postId,
    int quantity,
    String? message,
  );
}

class MarketplaceCustomerRepositoryImpl
    implements MarketplaceCustomerRepository {
  MarketplaceCustomerRepositoryImpl(this._remote);

  final MarketplaceRemoteDataSource _remote;

  @override
  Future<MarketplaceHome> getHome({List<String>? districtIds}) async =>
      (await _remote.getHome(districtIds: districtIds)).toEntity();

  @override
  Future<MarketplaceCardPage> search({
    String? kind,
    bool? wholesale,
    String? categoryId,
    String? keyword,
    List<String>? districtIds,
    bool feed = false,
    int page = 1,
    int? pageSize,
  }) async => (await _remote.searchPosts(
    kind: kind,
    wholesale: wholesale,
    categoryId: categoryId,
    keyword: keyword,
    districtIds: districtIds,
    feed: feed,
    page: page,
    pageSize: pageSize,
  )).toEntity();

  @override
  Future<MarketplacePostDetail> getPost(String id) async =>
      (await _remote.getPostDetail(id)).toEntity();

  @override
  Future<MarketplaceCardPage> getFavourites({int page = 1}) async =>
      (await _remote.getFavourites(page: page)).toEntity();

  @override
  Future<void> setFavourite(String postId, {required bool saved}) =>
      _remote.setFavourite(postId, saved: saved);

  @override
  Future<MarketplaceOrderPage> getMyOrders({String? status}) async =>
      (await _remote.getMyOrders(status: status)).toEntity();

  @override
  Future<MarketplaceOrder> getMyOrder(String id) async =>
      (await _remote.getMyOrder(id)).toEntity();

  @override
  Future<MarketplaceOrder> placeOrder(MarketplaceOrderInput input) async =>
      (await _remote.placeOrder(input.toJson())).toEntity();

  @override
  Future<MarketplaceCheckout> startPayment(String orderId) async =>
      (await _remote.startPayment(orderId)).toEntity();

  @override
  Future<MarketplaceOrder> confirmPayment(
    String orderId, {
    required String providerOrderId,
    required String paymentId,
    required String signature,
  }) async => (await _remote.confirmPayment(
    orderId,
    providerOrderId: providerOrderId,
    paymentId: paymentId,
    signature: signature,
  )).toEntity();

  @override
  Future<MarketplaceOrder> cancel(String orderId) async =>
      (await _remote.cancelMyOrder(orderId)).toEntity();

  @override
  Future<MarketplaceOrder> review(
    String orderId,
    int score,
    String? comment,
  ) async => (await _remote.reviewMyOrder(
    orderId,
    score: score,
    comment: comment,
  )).toEntity();

  @override
  Future<MarketplaceB2BRequestPage> getMyRequests() async =>
      (await _remote.getMyB2BRequests()).toEntity();

  @override
  Future<MarketplaceB2BRequest> askForLot(
    String postId,
    int quantity,
    String? message,
  ) async => (await _remote.askForLot(
    postId: postId,
    quantity: quantity,
    message: message,
  )).toEntity();
}
