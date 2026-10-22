import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/domain/entities/rating.dart';

abstract interface class BookingRepository {
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
  });

  Future<List<Booking>> getMyBookingsAsCustomer();

  /// One order, by id — what a notification can ask for.
  Future<Booking> getBookingByIdAsCustomer(String id);

  Future<Booking> cancelBookingAsCustomer(String id, {String? reason});

  Future<Rating> rateBooking(String id, {required int score, String? comment});

  Future<List<Booking>> getMyBookingsAsBusiness();

  /// One order, by id, as the business sees it.
  Future<Booking> getBookingByIdAsBusiness(String id);

  Future<Booking> confirmBooking(String id);

  /// Offers a crew size and price on an order, or counters the other side's.
  Future<Booking> proposeTerms(
    String bookingId, {
    required bool asBusiness,
    required int workerCount,
    required double price,
    String? message,
  });

  /// Takes up the other side's offer, which confirms the order.
  Future<Booking> acceptTerms(
    String bookingId,
    String proposalId, {
    required bool asBusiness,
  });

  /// Marks a confirmed order as actually under way.
  Future<Booking> startWork(String id);

  /// The business closing the work on an order, finishing any crew still on it.
  Future<Booking> completeWork(String id);

  /// Extra pay on top of one directly added worker's wage: ₹1,000 + ₹200 = ₹1,200.
  Future<Booking> raiseCrewMemberSalary(
    String bookingId,
    String workerProfileId, {
    required double increase,
    String? reason,
  });

  /// The same extra pay for everyone on the order still to be paid.
  Future<Booking> raiseCrewSalary(
    String bookingId, {
    required double increase,
    String? reason,
  });

  /// Sets or clears a crew member's role on this one job. Null removes it.
  ///
  /// The role is not a label: whoever holds one can mark this job's work started and finished.
  Future<Booking> setCrewRole(
    String bookingId,
    String workerProfileId, {
    required String? role,
  });

  Future<Booking> assignWorker(
    String id,
    String workerProfileId, {
    DateTime? scheduledDate,
    double? salaryAmount,
    String? salaryUnit,
  });

  Future<Booking> cancelBookingAsBusiness(String id, {String? reason});

  Future<List<Booking>> getMyJobsAsWorker();

  Future<Booking> getJobByIdAsWorker(String id);

  Future<Booking> respondToAssignment(String id, {required bool accept});

  Future<Booking> completeBooking(String id);

  /// The job's lead moving the whole order, which only a worker holding a role on it may do.
  Future<Booking> startJobAsLead(String id);

  Future<Booking> finishJobAsLead(String id);
}
