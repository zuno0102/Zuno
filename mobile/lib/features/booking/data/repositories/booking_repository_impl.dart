import 'package:zuno/features/booking/data/datasources/booking_remote_datasource.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/domain/entities/rating.dart';
import 'package:zuno/features/booking/domain/repositories/booking_repository.dart';

class BookingRepositoryImpl implements BookingRepository {
  BookingRepositoryImpl({required BookingRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  final BookingRemoteDataSource _remoteDataSource;

  @override
  Future<Booking> createBooking({
    required String businessServiceId,
    String? businessServiceVariantId,
    required DateTime scheduledDate,
    String? notes,
    required String addressLine1,
    String? addressLine2,
    required String city,
    required String state,
    required String postalCode,
    String? country,
    required double latitude,
    required double longitude,
    Map<String, String> answers = const {},
  }) async {
    final model = await _remoteDataSource.createBooking({
      'businessServiceId': businessServiceId,
      'businessServiceVariantId': businessServiceVariantId,
      'scheduledDate': scheduledDate.toUtc().toIso8601String(),
      'notes': notes,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'city': city,
      'state': state,
      'postalCode': postalCode,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      // questionId -> what the customer typed. Empty for a service with no questions.
      'answers': [
        for (final entry in answers.entries)
          {'questionId': entry.key, 'answerText': entry.value},
      ],
    });
    return model.toEntity();
  }

  @override
  Future<List<Booking>> getMyBookingsAsCustomer() async =>
      (await _remoteDataSource.getMyBookingsAsCustomer())
          .map((m) => m.toEntity())
          .toList();

  @override
  Future<Booking> cancelBookingAsCustomer(String id, {String? reason}) async =>
      (await _remoteDataSource.cancelBookingAsCustomer(id, reason)).toEntity();

  @override
  Future<Rating> rateBooking(
    String id, {
    required int score,
    String? comment,
  }) async => (await _remoteDataSource.rateBooking(
    id,
    score: score,
    comment: comment,
  )).toEntity();

  @override
  Future<List<Booking>> getMyBookingsAsBusiness() async =>
      (await _remoteDataSource.getMyBookingsAsBusiness())
          .map((m) => m.toEntity())
          .toList();

  @override
  Future<Booking> confirmBooking(String id) async =>
      (await _remoteDataSource.confirmBooking(id)).toEntity();

  @override
  Future<Booking> proposeTerms(
    String bookingId, {
    required bool asBusiness,
    required int workerCount,
    required double price,
    String? message,
  }) async => (await _remoteDataSource.proposeTerms(
    bookingId,
    asBusiness: asBusiness,
    workerCount: workerCount,
    price: price,
    message: message,
  )).toEntity();

  @override
  Future<Booking> acceptTerms(
    String bookingId,
    String proposalId, {
    required bool asBusiness,
  }) async => (await _remoteDataSource.acceptTerms(
    bookingId,
    proposalId,
    asBusiness: asBusiness,
  )).toEntity();

  @override
  Future<Booking> startWork(String id) async =>
      (await _remoteDataSource.startWork(id)).toEntity();

  @override
  Future<Booking> completeWork(String id) async =>
      (await _remoteDataSource.completeWork(id)).toEntity();

  @override
  Future<Booking> setCrewRole(
    String bookingId,
    String workerProfileId, {
    required String? role,
  }) async => (await _remoteDataSource.setCrewRole(
    bookingId,
    workerProfileId,
    role: role,
  )).toEntity();

  @override
  Future<Booking> assignWorker(
    String id,
    String workerProfileId, {
    DateTime? scheduledDate,
    double? salaryAmount,
    String? salaryUnit,
  }) async => (await _remoteDataSource.assignWorker(
    id,
    workerProfileId,
    scheduledDate: scheduledDate,
    salaryAmount: salaryAmount,
    salaryUnit: salaryUnit,
  )).toEntity();

  @override
  Future<Booking> cancelBookingAsBusiness(String id, {String? reason}) async =>
      (await _remoteDataSource.cancelBookingAsBusiness(id, reason)).toEntity();

  @override
  Future<List<Booking>> getMyJobsAsWorker() async =>
      (await _remoteDataSource.getMyJobsAsWorker())
          .map((m) => m.toEntity())
          .toList();

  @override
  Future<Booking> getJobByIdAsWorker(String id) async =>
      (await _remoteDataSource.getJobByIdAsWorker(id)).toEntity();

  @override
  Future<Booking> getBookingByIdAsCustomer(String id) async =>
      (await _remoteDataSource.getBookingByIdAsCustomer(id)).toEntity();

  @override
  Future<Booking> getBookingByIdAsBusiness(String id) async =>
      (await _remoteDataSource.getBookingByIdAsBusiness(id)).toEntity();

  @override
  Future<Booking> respondToAssignment(
    String id, {
    required bool accept,
  }) async => (await _remoteDataSource.respondToAssignment(
    id,
    accept: accept,
  )).toEntity();

  @override
  Future<Booking> startJobAsLead(String id) async =>
      (await _remoteDataSource.startJobAsLead(id)).toEntity();

  @override
  Future<Booking> finishJobAsLead(String id) async =>
      (await _remoteDataSource.finishJobAsLead(id)).toEntity();

  @override
  Future<Booking> completeBooking(String id) async =>
      (await _remoteDataSource.completeBooking(id)).toEntity();
}
