import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/domain/entities/booking_worker_assignment.dart';
import 'package:zuno/shared/domain/track_state.dart';

/// The five tracks an order runs on, and the rule that each moves for its own reason.
///
/// They used to share one word: "in progress" meant either that the day had arrived or that the
/// crew was on site, and "completed" meant either that the work was done or that everyone had
/// been paid. Every test here pins one track against the others.
void main() {
  final now = DateTime(2026, 9, 16, 12);
  final nextMonth = DateTime(2026, 10, 16, 9);
  final thisMorning = DateTime(2026, 9, 16, 9);

  BookingWorkerAssignment worker({
    String status = 'Accepted',
    String displayStatus = 'Active',
  }) => BookingWorkerAssignment(
    workerProfileId: 'w-1',
    workerName: 'Ravi Kumar',
    status: status,
    displayStatus: displayStatus,
  );

  Booking order({
    String status = 'Confirmed',
    DateTime? scheduledDate,
    DateTime? workStartedAt,
    DateTime? completedAt,
    String wageStatus = '',
    int wagePayeeCount = 0,
    int wagePaidPayeeCount = 0,
    double wageOutstandingAmount = 0,
    List<BookingWorkerAssignment> crew = const [],
  }) => Booking(
    id: 'b-1',
    businessOwnerProfileId: 'biz-1',
    businessName: 'Test Owner',
    customerProfileId: 'c-1',
    customerName: 'Test Customer',
    businessServiceId: 's-1',
    serviceName: 'Catering',
    serviceCategoryName: 'Cleaning',
    status: status,
    scheduledDate: scheduledDate ?? nextMonth,
    priceQuoted: 5000,
    workStartedAt: workStartedAt,
    completedAt: completedAt,
    wageStatus: wageStatus,
    wagePayeeCount: wagePayeeCount,
    wagePaidPayeeCount: wagePaidPayeeCount,
    wageOutstandingAmount: wageOutstandingAmount,
    assignedWorkers: crew,
  );

  // The one label the order list shows is the server's stage now — tested in the backend's
  // OrderStagesTests, and its display in order_stage_test.dart.

  group('the cascade — each track opens the next', () {
    test('confirmed, before the day: only the event is open', () {
      final o = order();

      expect(o.eventState(now: now), TrackState.active);
      expect(o.workState(now: now), TrackState.notStarted);
      expect(o.paymentState(), TrackState.notStarted);
    });

    test('the day arrives: the event runs, the work opens', () {
      // Nothing was pressed — the date did this.
      final o = order(scheduledDate: thisMorning);

      expect(o.eventState(now: now), TrackState.inProgress);
      expect(o.workState(now: now), TrackState.active);
      expect(o.paymentState(), TrackState.notStarted);
    });

    test('exactly on the scheduled minute counts as arrived', () {
      expect(
        order(scheduledDate: now).eventState(now: now),
        TrackState.inProgress,
      );
    });

    test('start work: the work runs, the wages open', () {
      final o = order(
        status: 'InProgress',
        scheduledDate: thisMorning,
        workStartedAt: thisMorning,
      );

      expect(o.workState(now: now), TrackState.inProgress);
      expect(o.paymentState(), TrackState.active);
      // Work under way means the event is under way. They cannot read differently.
      expect(o.eventState(now: now), TrackState.inProgress);
    });

    test('work under way keeps the event under way even if the date moved', () {
      // Somebody is on site. A scheduled date edited to next month afterwards must not make
      // the event read as merely upcoming while the crew is standing in the kitchen.
      final o = order(
        status: 'InProgress',
        scheduledDate: nextMonth,
        workStartedAt: thisMorning,
      );

      expect(o.workState(now: now), TrackState.inProgress);
      expect(o.eventState(now: now), TrackState.inProgress);
    });

    test('mark completed: event and work done, the wages run', () {
      final o = order(
        status: 'Completed',
        scheduledDate: thisMorning,
        workStartedAt: thisMorning,
        completedAt: now,
        wageStatus: 'Outstanding',
        wageOutstandingAmount: 1400,
      );

      expect(o.eventState(now: now), TrackState.completed);
      expect(o.workState(now: now), TrackState.completed);
      expect(o.paymentState(), TrackState.inProgress);
      expect(o.isEntirelyComplete, isFalse);
    });

    test('paid: every track home', () {
      final o = order(
        status: 'Completed',
        scheduledDate: thisMorning,
        workStartedAt: thisMorning,
        completedAt: now,
        wageStatus: 'Settled',
      );

      expect(o.paymentState(), TrackState.completed);
      expect(o.isEntirelyComplete, isTrue);
    });

    test('a roster-staffed order settles the moment the work is done', () {
      // There is no payment coming that could ever move this track, so waiting for one would
      // leave the order unfinished for ever.
      final o = order(
        status: 'Completed',
        scheduledDate: thisMorning,
        workStartedAt: thisMorning,
        completedAt: now,
        wageStatus: 'NoWagesThroughZuno',
      );

      expect(o.paymentState(), TrackState.completed);
      expect(o.isEntirelyComplete, isTrue);
    });

    test('a cancelled order lapses rather than completing', () {
      final o = order(status: 'Cancelled');

      expect(o.eventState(now: now), TrackState.lapsed);
      expect(o.workState(now: now), TrackState.lapsed);
      expect(o.paymentState(), TrackState.lapsed);
      expect(o.isEntirelyComplete, isFalse);
    });
  });

  group('Start work', () {
    test('is offered on the day, with someone who said yes', () {
      final today = order(scheduledDate: thisMorning, crew: [worker()]);

      expect(today.canStartWork(now: now), isTrue);
    });

    test('is not offered before the day', () {
      expect(order(crew: [worker()]).canStartWork(now: now), isFalse);
    });

    test('is not offered with nobody who has accepted', () {
      final awaiting = order(
        scheduledDate: thisMorning,
        crew: [worker(status: 'Assigned', displayStatus: 'Awaiting')],
      );

      expect(awaiting.canStartWork(now: now), isFalse);
    });

    test('is not offered on an unconfirmed order', () {
      final pending = order(
        status: 'Pending',
        scheduledDate: thisMorning,
        crew: [worker()],
      );

      expect(pending.canStartWork(now: now), isFalse);
    });
  });

  group('Mark completed', () {
    test('is offered only once the work is under way', () {
      expect(order(status: 'InProgress').canCompleteWork, isTrue);
      expect(order(scheduledDate: thisMorning).canCompleteWork, isFalse);
      expect(order(status: 'Completed').canCompleteWork, isFalse);
    });
  });

  group('the wages track', () {
    test('is left blank when nobody asked, not read as owing nothing', () {
      // A customer, or a screen that did not load it. Silence is not "settled".
      expect(order().hasWageInfo, isFalse);
      expect(order().wageStatusLabel, '');
    });

    test('a roster-staffed order owes nothing through the app', () {
      final o = order(wageStatus: 'NoWagesThroughZuno');

      expect(o.wageStatusLabel, 'No wages through Zuno');
      expect(o.isWageClear, isTrue);
    });

    test('an order still owing is not clear', () {
      final o = order(
        wageStatus: 'Outstanding',
        wagePayeeCount: 5,
        wagePaidPayeeCount: 2,
        wageOutstandingAmount: 2100,
      );

      expect(o.isWageClear, isFalse);
      expect(o.wagePaidLabel, '2 of 5 paid');
    });

    test('a dispute is not merely outstanding', () {
      expect(order(wageStatus: 'Disputed').isWageDisputed, isTrue);
      expect(order(wageStatus: 'Disputed').isWageClear, isFalse);
    });
  });

  group('the whole order', () {
    test('counts only when the work is done AND the wages are square', () {
      Booking finished(String wages) =>
          order(status: 'Completed', completedAt: now, wageStatus: wages);

      expect(finished('Settled').isEntirelyComplete, isTrue);
      expect(finished('NoWagesThroughZuno').isEntirelyComplete, isTrue);
      expect(finished('Outstanding').isEntirelyComplete, isFalse);
      expect(finished('Disputed').isEntirelyComplete, isFalse);
    });

    test('paid-up work that is not finished does not count', () {
      final working = order(
        status: 'InProgress',
        workStartedAt: thisMorning,
        wageStatus: 'Settled',
      );

      expect(working.isEntirelyComplete, isFalse);
    });
  });

  group('a worker on the order', () {
    test('reads active until the work starts, then in progress', () {
      expect(worker().displayStatusLabel, 'Active');
      expect(
        worker(displayStatus: 'InProgress').displayStatusLabel,
        'In progress',
      );
    });

    test('names the states a business actually reads', () {
      expect(
        worker(
          status: 'Assigned',
          displayStatus: 'Awaiting',
        ).displayStatusLabel,
        'Awaiting their answer',
      );
      expect(
        worker(
          status: 'Completed',
          displayStatus: 'Completed',
        ).displayStatusLabel,
        'Completed',
      );
    });
  });
}
