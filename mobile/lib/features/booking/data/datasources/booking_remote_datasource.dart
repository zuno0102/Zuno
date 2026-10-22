import 'package:dio/dio.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/network/dio_error_mapper.dart';
import 'package:zuno/features/booking/data/models/booking_model.dart';
import 'package:zuno/features/booking/data/models/rating_model.dart';

class BookingRemoteDataSource {
  BookingRemoteDataSource(this._dio);

  final Dio _dio;

  Future<BookingModel> createBooking(Map<String, dynamic> body) =>
      _post(ApiConstants.customerBookingsPath, body);

  Future<List<BookingModel>> getMyBookingsAsCustomer() =>
      _list(ApiConstants.customerBookingsPath);

  /// One order, fetched by id.
  ///
  /// What a notification needs: it carries an id, while the detail screens take a whole booking.
  /// Fetching the one order is also cheaper and fresher than loading the customer's whole list to
  /// find it in.
  Future<BookingModel> getBookingByIdAsCustomer(String id) =>
      _get(ApiConstants.customerBookingPath(id));

  Future<BookingModel> cancelBookingAsCustomer(String id, String? reason) =>
      _post(ApiConstants.customerBookingCancelPath(id), {'reason': reason});

  Future<RatingModel> rateBooking(
    String id, {
    required int score,
    String? comment,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.customerBookingRatePath(id),
        data: {'score': score, 'comment': comment},
      );
      return RatingModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<List<BookingModel>> getMyBookingsAsBusiness() =>
      _list(ApiConstants.businessBookingsPath);

  /// One order, fetched by id, for the same reason as the customer's.
  Future<BookingModel> getBookingByIdAsBusiness(String id) =>
      _get(ApiConstants.businessBookingPath(id));

  Future<BookingModel> confirmBooking(String id) =>
      _post(ApiConstants.businessBookingConfirmPath(id), const {});

  /// Offers a crew size and price, or counters the other side's.
  ///
  /// [asBusiness] only picks the route. Which side is making the offer is decided by the server
  /// from the signed-in user, so a wrong flag here cannot put words in anyone's mouth.
  Future<BookingModel> proposeTerms(
    String bookingId, {
    required bool asBusiness,
    required int workerCount,
    required double price,
    String? message,
  }) => _post(
    asBusiness
        ? ApiConstants.businessBookingTermsPath(bookingId)
        : ApiConstants.customerBookingTermsPath(bookingId),
    {'workerCount': workerCount, 'price': price, 'message': message},
  );

  /// Takes up the other side's offer, which confirms the order.
  Future<BookingModel> acceptTerms(
    String bookingId,
    String proposalId, {
    required bool asBusiness,
  }) => _post(
    asBusiness
        ? ApiConstants.businessBookingAcceptTermsPath(bookingId, proposalId)
        : ApiConstants.customerBookingAcceptTermsPath(bookingId, proposalId),
    const {},
  );

  Future<BookingModel> startWork(String id) =>
      _post(ApiConstants.businessBookingStartPath(id), const {});

  Future<BookingModel> completeWork(String id) =>
      _post(ApiConstants.businessBookingCompletePath(id), const {});

  /// Sets or clears what one crew member is on this job. A null role takes it away.
  Future<BookingModel> setCrewRole(
    String bookingId,
    String workerProfileId, {
    required String? role,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        ApiConstants.businessBookingCrewRolePath(bookingId, workerProfileId),
        data: {'role': role},
      );
      return BookingModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  /// Adds [increase] to the wage of one worker added to this order directly.
  Future<BookingModel> raiseCrewMemberSalary(
    String bookingId,
    String workerProfileId, {
    required double increase,
    String? reason,
  }) => _post(
    ApiConstants.businessBookingCrewRaisePath(bookingId, workerProfileId),
    {'increase': increase, 'reason': reason},
  );

  /// Adds [increase] to the wage of everyone on this order still to be paid.
  Future<BookingModel> raiseCrewSalary(
    String bookingId, {
    required double increase,
    String? reason,
  }) => _post(ApiConstants.businessBookingCrewRaiseAllPath(bookingId), {
    'increase': increase,
    'reason': reason,
  });

  Future<BookingModel> assignWorker(
    String id,
    String workerProfileId, {
    DateTime? scheduledDate,
    double? salaryAmount,
    String? salaryUnit,
  }) => _post(ApiConstants.businessBookingAssignWorkerPath(id), {
    'workerProfileId': workerProfileId,
    'scheduledDate': scheduledDate?.toUtc().toIso8601String(),
    // Null for someone paid outside Zuno. The server refuses half a wage, so these two are
    // always both present or both absent.
    'salaryAmount': salaryAmount,
    'salaryUnit': salaryUnit,
  });

  Future<BookingModel> cancelBookingAsBusiness(String id, String? reason) =>
      _post(ApiConstants.businessBookingCancelPath(id), {'reason': reason});

  Future<List<BookingModel>> getMyJobsAsWorker() =>
      _list(ApiConstants.workerJobsPath);

  Future<BookingModel> getJobByIdAsWorker(String id) =>
      _get(ApiConstants.workerJobPath(id));

  Future<BookingModel> respondToAssignment(String id, {required bool accept}) =>
      _post(ApiConstants.workerJobRespondPath(id), {'accept': accept});

  /// The job's lead saying the work has begun, and that the whole order is finished.
  Future<BookingModel> startJobAsLead(String id) =>
      _post(ApiConstants.workerJobStartJobPath(id), const {});

  Future<BookingModel> finishJobAsLead(String id) =>
      _post(ApiConstants.workerJobFinishJobPath(id), const {});

  Future<BookingModel> completeBooking(String id) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.workerJobCompletePath(id),
      );
      return BookingModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  /// One booking, from whichever role's route the caller passed.
  ///
  /// All three roles have a get-one route, and each decides for itself whether the signed-in user
  /// is party to that booking — so the path chosen here is a convenience, never the access rule.
  Future<BookingModel> _get(String path) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(path);
      return BookingModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<List<BookingModel>> _list(String path) async {
    try {
      final response = await _dio.get<List<dynamic>>(path);
      return response.data!
          .map((e) => BookingModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<BookingModel> _post(String path, Map<String, dynamic> body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: body);
      return BookingModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
