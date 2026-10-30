import 'package:dio/dio.dart';
import 'package:zuno/core/network/dio_error_mapper.dart';
import 'package:zuno/features/rental/data/models/rental_customer_models.dart';
import 'package:zuno/features/rental/data/models/rental_stock_models.dart';
import 'package:zuno/features/rental/data/rental_api.dart';
import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/features/rental/domain/entities/rental_stock.dart';

/// The customer's side of the Rent server: browsing, booking, and their own rent orders. Same Dio
/// and login as everything else in Rent.
class RentalCustomerRemoteDataSource {
  RentalCustomerRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<RentalHomeSectionModel>> home(
    int seed,
    List<String> districtIds,
  ) => _list(
    RentApi.browseHomePath,
    RentalHomeSectionModel.fromJson,
    query: {'seed': seed, 'districtIds': districtIds},
  );

  Future<List<RentalCardModel>> banners(List<String> districtIds) => _list(
    RentApi.browseBannersPath,
    RentalCardModel.fromJson,
    query: {'districtIds': districtIds},
  );

  Future<List<RentalCardModel>> search({
    String? categoryId,
    String? keyword,
    List<String> districtIds = const [],
  }) => _list(
    RentApi.browsePath,
    RentalCardModel.fromJson,
    query: {
      'categoryId': ?categoryId,
      if (keyword != null && keyword.trim().isNotEmpty) 'keyword': keyword,
      'districtIds': districtIds,
    },
  );

  Future<RentalItemDetailModel> item(String id) => _run(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      RentApi.browseItemPath(id),
    );
    return RentalItemDetailModel.fromJson(response.data!);
  });

  Future<RentalAvailabilityModel> availability(
    String id,
    DateTime start,
    DateTime end,
  ) => _run(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      RentApi.browseAvailabilityPath(id),
      queryParameters: {
        'start': rentalApiDate(start),
        'end': rentalApiDate(end),
      },
    );
    return RentalAvailabilityModel.fromJson(response.data!);
  });

  Future<RentalOrderModel> book(RentalBookingInput input) => _run(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      RentApi.myRentalsPath,
      data: {
        'rentalItemId': input.rentalItemId,
        'quantity': input.quantity,
        'startDate': rentalApiDate(input.startDate),
        'endDate': rentalApiDate(input.endDate),
        'deliveryAddress': input.deliveryAddress,
        'districtId': input.districtId,
        'answers': [
          for (final entry in input.answers.entries)
            if (entry.value.trim().isNotEmpty)
              {'questionId': entry.key, 'answer': entry.value.trim()},
        ],
      },
    );
    return RentalOrderModel.fromJson(response.data!);
  });

  Future<RentalOrderPageModel> myRentals({int? pageSize}) => _run(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      RentApi.myRentalsPath,
      queryParameters: {'pageSize': ?pageSize},
    );
    return RentalOrderPageModel.fromJson(response.data!);
  });

  Future<RentalOrderModel> myRental(String id) => _run(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      RentApi.myRentalPath(id),
    );
    return RentalOrderModel.fromJson(response.data!);
  });

  Future<RentalOrderModel> cancel(String id) => _run(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      RentApi.myRentalCancelPath(id),
    );
    return RentalOrderModel.fromJson(response.data!);
  });

  Future<RentalCheckoutModel> checkout(String id) => _run(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      RentApi.myRentalCheckoutPath(id),
    );
    return RentalCheckoutModel.fromJson(response.data!);
  });

  Future<RentalOrderModel> pay(
    String id, {
    required String providerOrderId,
    required String paymentId,
    required String signature,
  }) => _run(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      RentApi.myRentalPayPath(id),
      data: {
        'providerOrderId': providerOrderId,
        'paymentId': paymentId,
        'signature': signature,
      },
    );
    return RentalOrderModel.fromJson(response.data!);
  });

  Future<List<RentalOrderEventModel>> history(String id) =>
      _list(RentApi.myRentalHistoryPath(id), RentalOrderEventModel.fromJson);

  Future<List<RentalOrderThreadModel>> threads() =>
      _list(RentApi.myRentalThreadsPath, RentalOrderThreadModel.fromJson);

  Future<List<RentalOrderMessageModel>> messages(String id) =>
      _list(RentApi.myRentalMessagesPath(id), RentalOrderMessageModel.fromJson);

  Future<RentalOrderMessageModel> send(String id, String body) =>
      _run(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          RentApi.myRentalMessagesPath(id),
          data: {'body': body},
        );
        return RentalOrderMessageModel.fromJson(response.data!);
      });

  Future<List<T>> _list<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, dynamic>? query,
  }) => _run(() async {
    final response = await _dio.get<List<dynamic>>(
      path,
      queryParameters: query,
    );
    return response.data!
        .map((json) => fromJson(json as Map<String, dynamic>))
        .toList();
  });

  /// Every call fails the same way the rest of the app does: an app exception with the server's words.
  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
