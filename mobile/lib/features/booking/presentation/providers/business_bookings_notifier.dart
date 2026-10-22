import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/presentation/providers/booking_providers.dart';

part 'business_bookings_notifier.g.dart';

@riverpod
class BusinessBookingsNotifier extends _$BusinessBookingsNotifier {
  @override
  Future<List<Booking>> build() =>
      ref.watch(bookingRepositoryProvider).getMyBookingsAsBusiness();

  Future<void> confirm(String id) async {
    await ref.read(bookingRepositoryProvider).confirmBooking(id);
    await _refresh();
  }

  /// Offers the customer a crew size and price, or counters theirs.
  Future<void> proposeTerms(
    String bookingId, {
    required int workerCount,
    required double price,
    String? message,
  }) async {
    await ref
        .read(bookingRepositoryProvider)
        .proposeTerms(
          bookingId,
          asBusiness: true,
          workerCount: workerCount,
          price: price,
          message: message,
        );
    await _refresh();
  }

  /// Takes up the customer's counter-offer, which confirms the order.
  Future<void> acceptTerms(String bookingId, String proposalId) async {
    await ref
        .read(bookingRepositoryProvider)
        .acceptTerms(bookingId, proposalId, asBusiness: true);
    await _refresh();
  }

  Future<Booking> startWork(String id) async {
    final updated = await ref.read(bookingRepositoryProvider).startWork(id);
    await _refresh();
    return updated;
  }

  Future<Booking> completeWork(String id) async {
    final updated = await ref.read(bookingRepositoryProvider).completeWork(id);
    await _refresh();
    return updated;
  }

  /// Extra pay for one worker added to the order directly. A full reload, not a swap in place:
  /// the order's "Pay crew" total is worked out on the server and only comes with the list.
  Future<void> raiseCrewMemberSalary(
    String bookingId,
    String workerProfileId, {
    required double increase,
    String? reason,
  }) async {
    await ref
        .read(bookingRepositoryProvider)
        .raiseCrewMemberSalary(
          bookingId,
          workerProfileId,
          increase: increase,
          reason: reason,
        );
    await _refresh();
  }

  /// The same extra pay for everyone on the order still to be paid.
  Future<void> raiseCrewSalary(
    String bookingId, {
    required double increase,
    String? reason,
  }) async {
    await ref
        .read(bookingRepositoryProvider)
        .raiseCrewSalary(bookingId, increase: increase, reason: reason);
    await _refresh();
  }

  /// Sets or clears what one crew member is on this job. Null takes the role away.
  Future<Booking> setCrewRole(
    String bookingId,
    String workerProfileId, {
    required String? role,
  }) async {
    final updated = await ref
        .read(bookingRepositoryProvider)
        .setCrewRole(bookingId, workerProfileId, role: role);

    final current = state.value;
    if (current == null) {
      await _refresh();
      return updated;
    }

    // The one row, swapped in place — not a reload.
    //
    // _refresh() puts the provider back into loading, which replaces the whole list with a
    // spinner and drops the reader at the top of it. Setting a role happens deep in a scrolled
    // list of orders, so the card somebody just worked on would vanish and have to be hunted for
    // again. Nothing else on the screen changed; only this order did.
    state = AsyncData([
      for (final booking in current)
        booking.id == bookingId ? updated : booking,
    ]);

    return updated;
  }

  Future<Booking> assignWorker(
    String id,
    String workerProfileId, {
    DateTime? scheduledDate,
    double? salaryAmount,
    String? salaryUnit,
  }) async {
    final updated = await ref
        .read(bookingRepositoryProvider)
        .assignWorker(
          id,
          workerProfileId,
          scheduledDate: scheduledDate,
          salaryAmount: salaryAmount,
          salaryUnit: salaryUnit,
        );
    await _refresh();
    return updated;
  }

  Future<void> cancel(String id, {String? reason}) async {
    await ref
        .read(bookingRepositoryProvider)
        .cancelBookingAsBusiness(id, reason: reason);
    await _refresh();
  }

  Future<void> _refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(bookingRepositoryProvider).getMyBookingsAsBusiness(),
    );
  }
}
