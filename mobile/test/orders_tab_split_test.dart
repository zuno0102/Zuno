import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/domain/entities/booking_worker_assignment.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';

/// What belongs in Orders → Status management, and what does not.
///
/// The split exists so one job is worked from one place. Two rules hold it together, and both
/// are easy to break by accident:
///   * a hiring post raised **for an order** is managed through that order, never twice;
///   * a **standalone** post has no order to hide behind, so it must appear in its own right —
///     strip the actions off the hire-post card without this and it is stranded for ever.
void main() {
  final now = DateTime(2026, 9, 16, 12);
  final earlier = DateTime(2026, 9, 16, 9);
  final later = DateTime(2026, 10, 16, 9);

  Booking order({
    String id = 'o-1',
    String status = 'Confirmed',
    DateTime? scheduledDate,
    DateTime? workStartedAt,
    DateTime? completedAt,
    String wageStatus = '',
    double outstanding = 0,
    bool accepted = true,
  }) => Booking(
    id: id,
    businessOwnerProfileId: 'biz-1',
    businessName: 'Test Owner',
    customerProfileId: 'c-1',
    customerName: 'Test Customer',
    businessServiceId: 's-1',
    serviceName: 'Catering',
    serviceCategoryName: 'Cleaning',
    status: status,
    scheduledDate: scheduledDate ?? later,
    priceQuoted: 5000,
    workStartedAt: workStartedAt,
    completedAt: completedAt,
    wageStatus: wageStatus,
    wageOutstandingAmount: outstanding,
    assignedWorkers: accepted
        ? [
            const BookingWorkerAssignment(
              workerProfileId: 'w-1',
              workerName: 'Ravi',
              status: 'Accepted',
              displayStatus: 'Active',
            ),
          ]
        : const [],
  );

  HiringPost post({String? bookingId, DateTime? eventDate}) => HiringPost(
    id: 'p-1',
    businessOwnerProfileId: 'biz-1',
    bookingId: bookingId,
    businessName: 'Test Owner',
    title: 'Evening crew',
    eventDate: eventDate ?? later,
    workersNeeded: 2,
    salaryAmount: 800,
    confirmedCount: 0,
    status: 'Open',
    createdDate: earlier,
  );

  /// The two filters the Status management tab applies, kept here so the rule is pinned rather
  /// than only drawn.
  List<Booking> manageable(List<Booking> all) =>
      all.where((o) => !o.isPending && !o.isCancelled).toList();

  List<HiringPost> ownEvents(List<HiringPost> all) =>
      all.where((p) => p.bookingId == null && !p.isLapsed(now: now)).toList();

  group('which orders need managing', () {
    test('an order still awaiting confirmation is answered elsewhere', () {
      expect(manageable([order(status: 'Pending')]), isEmpty);
    });

    test('a cancelled order has nothing left to do', () {
      expect(manageable([order(status: 'Cancelled')]), isEmpty);
    });

    test('everything the business took on is listed', () {
      final all = [
        order(id: 'a', status: 'Confirmed'),
        order(id: 'b', status: 'InProgress'),
        order(id: 'c', status: 'Completed'),
      ];

      expect(manageable(all).map((o) => o.id), ['a', 'b', 'c']);
    });
  });

  group('which hiring posts appear alongside them', () {
    test('a post raised for an order does NOT — that would manage it twice', () {
      expect(ownEvents([post(bookingId: 'o-1')]), isEmpty);
    });

    test('a standalone post DOES — nothing else can start or pay it', () {
      // The regression that matters. The hire-post card no longer carries Start, Complete or
      // Pay, so if this filter ever drops standalone posts they become unfinishable.
      expect(ownEvents([post()]), hasLength(1));
    });

    test('a post nobody took before its date is not work to manage', () {
      expect(ownEvents([post(eventDate: earlier)]), isEmpty);
    });
  });

  group('the next step, one per job', () {
    /// Mirrors the card: at most one action, in this order.
    String? step(Booking o) {
      if (o.canStartWork(now: now)) return 'Start work';
      if (o.canCompleteWork) return 'Mark completed';
      if (o.isCompleted && o.hasOutstandingWages) return 'Pay crew';
      return null;
    }

    test('nothing to press before the day', () {
      expect(step(order()), isNull);
    });

    test('start work once the day has come', () {
      expect(step(order(scheduledDate: earlier)), 'Start work');
    });

    test('then finish it', () {
      expect(
        step(order(status: 'InProgress', workStartedAt: earlier)),
        'Mark completed',
      );
    });

    test('then pay, but only while something is owed', () {
      final owing = order(
        status: 'Completed',
        completedAt: now,
        wageStatus: 'Outstanding',
        outstanding: 1400,
      );
      final square = order(
        status: 'Completed',
        completedAt: now,
        wageStatus: 'Settled',
      );

      expect(step(owing), 'Pay crew');
      expect(step(square), isNull, reason: 'nothing left to do');
    });

    test('a roster-staffed order never asks to be paid', () {
      final roster = order(
        status: 'Completed',
        completedAt: now,
        wageStatus: 'NoWagesThroughZuno',
      );

      expect(step(roster), isNull);
      expect(roster.isEntirelyComplete, isTrue);
    });
  });
}
