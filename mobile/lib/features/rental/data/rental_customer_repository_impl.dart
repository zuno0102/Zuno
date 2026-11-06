import 'package:zuno/features/booking/domain/entities/booking_message.dart';
import 'package:zuno/features/rental/data/rental_customer_remote_datasource.dart';
import 'package:zuno/features/rental/data/rental_repository_impl.dart';
import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/features/rental/domain/entities/rental_payment.dart';
import 'package:zuno/features/rental/domain/entities/rental_stock.dart';
import 'package:zuno/features/rental/domain/rental_customer_repository.dart';
import 'package:zuno/features/rental/domain/rental_orders_gateway.dart';
import 'package:zuno/features/rental/domain/rental_repository.dart';

class RentalCustomerRepositoryImpl implements RentalCustomerRepository {
  RentalCustomerRepositoryImpl(this._remote);

  final RentalCustomerRemoteDataSource _remote;

  @override
  Future<List<RentalHomeSection>> home(
    int seed,
    List<String> districtIds,
  ) async =>
      (await _remote.home(seed, districtIds)).map((s) => s.toEntity()).toList();

  @override
  Future<List<RentalCard>> banners(List<String> districtIds) async =>
      (await _remote.banners(districtIds)).map((c) => c.toEntity()).toList();

  @override
  Future<List<RentalCard>> search({
    String? categoryId,
    String? keyword,
    List<String> districtIds = const [],
  }) async => (await _remote.search(
    categoryId: categoryId,
    keyword: keyword,
    districtIds: districtIds,
  )).map((c) => c.toEntity()).toList();

  @override
  Future<RentalItemDetail> item(String id) async =>
      (await _remote.item(id)).toEntity();

  @override
  Future<RentalAvailability> availability(
    String id,
    DateTime start,
    DateTime end,
  ) async => (await _remote.availability(id, start, end)).toEntity();

  @override
  Future<RentalOrder> book(RentalBookingInput input) async =>
      (await _remote.book(input)).toEntity();

  @override
  Future<String?> verifiedPhone() => _remote.verifiedPhone();

  @override
  Future<RentalPhoneCodeSent> sendPhoneCode(String phone) =>
      _remote.sendPhoneCode(phone);

  @override
  Future<void> verifyPhoneCode(String phone, String code) =>
      _remote.verifyPhoneCode(phone, code);

  @override
  Future<RentalCheckout> checkout(String orderId) async =>
      (await _remote.checkout(orderId)).toEntity();

  @override
  Future<RentalOrder> pay(
    String orderId, {
    required String providerOrderId,
    required String paymentId,
    required String signature,
  }) async => (await _remote.pay(
    orderId,
    providerOrderId: providerOrderId,
    paymentId: paymentId,
    signature: signature,
  )).toEntity();

  @override
  Future<RentalOrder> rate(
    String orderId,
    int score, {
    String? comment,
  }) async => (await _remote.rate(orderId, score, comment)).toEntity();
}

/// The customer's rent orders for the shared order screens.
class CustomerRentalOrdersGateway implements RentalOrdersGateway {
  CustomerRentalOrdersGateway(this._remote);

  final RentalCustomerRemoteDataSource _remote;

  @override
  Future<List<RentalOrder>> orders({String? status}) async {
    final all = (await _remote.myRentals(
      pageSize: RentalRepositoryImpl.listPageSize,
    )).items.map((o) => o.toEntity());
    return [
      for (final o in all)
        if (status == null || o.status == status) o,
    ];
  }

  @override
  Future<RentalOrder> order(String id) async =>
      (await _remote.myRental(id)).toEntity();

  @override
  Future<List<RentalOrderEvent>> history(String id) async =>
      (await _remote.history(id)).map((e) => e.toEntity()).toList();

  @override
  Future<RentalCancelQuote> cancelQuote(String id) async =>
      (await _remote.cancelQuote(id)).toEntity();

  /// A customer's one step is cancelling, while the order is only booked.
  @override
  Future<RentalOrder> takeStep(
    String id,
    String toStatus, {
    String? refundMode,
  }) async => (await _remote.cancel(id)).toEntity();

  @override
  Future<List<RentalOrderThread>> threads() async =>
      (await _remote.threads()).map((t) => t.toEntity()).toList();

  @override
  Future<List<BookingMessage>> messages(String id) async =>
      (await _remote.messages(id)).map((m) => m.toEntity()).toList();

  @override
  Future<BookingMessage> send(String id, String body) async =>
      (await _remote.send(id, body)).toEntity();
}

/// The business's rent orders for the shared order screens — the business repository, as it was.
class BusinessRentalOrdersGateway implements RentalOrdersGateway {
  BusinessRentalOrdersGateway(this._repository);

  final RentalRepository _repository;

  @override
  Future<List<RentalOrder>> orders({String? status}) =>
      _repository.getOrders(status: status);

  @override
  Future<RentalOrder> order(String id) => _repository.getOrder(id);

  @override
  Future<List<RentalOrderEvent>> history(String id) =>
      _repository.getOrderHistory(id);

  @override
  Future<RentalCancelQuote> cancelQuote(String id) =>
      _repository.getCancelQuote(id);

  @override
  Future<RentalOrder> takeStep(
    String id,
    String toStatus, {
    String? refundMode,
  }) => _repository.changeOrderStatus(id, toStatus, refundMode: refundMode);

  @override
  Future<List<RentalOrderThread>> threads() => _repository.getOrderThreads();

  @override
  Future<List<BookingMessage>> messages(String id) =>
      _repository.getOrderMessages(id);

  @override
  Future<BookingMessage> send(String id, String body) =>
      _repository.sendOrderMessage(id, body);
}
