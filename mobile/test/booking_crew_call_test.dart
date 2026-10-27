import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/domain/entities/booking_worker_assignment.dart';

/// Whether the business can phone a worker it put on the job itself.
///
/// The mirror of the hiring-post rule, and it has to stay a mirror: the same worker can arrive by
/// either route, and a business should not find that one of them can be rung and the other cannot.
///
/// Note this is deliberately narrower than [Booking.canBeCalled], which governs the business and
/// the customer talking to each other and stays true on a finished order.
void main() {
  BookingWorkerAssignment worker({
    String status = 'Accepted',
    String? workerPhone = '9000000000',
    double? agreedSalaryAmount = 800,
    String paymentStatus = 'Unpaid',
  }) => BookingWorkerAssignment(
    workerProfileId: 'w-1',
    workerName: 'Test Worker',
    workerPhone: workerPhone,
    status: status,
    displayStatus: 'Active',
    agreedSalaryAmount: agreedSalaryAmount,
    agreedSalaryUnit: agreedSalaryAmount == null ? null : 'PerEvent',
    paymentStatus: paymentStatus,
  );

  Booking order({String status = 'Confirmed'}) => Booking(
    id: '',
    businessOwnerProfileId: '',
    businessName: '',
    customerProfileId: '',
    customerName: '',
    businessServiceId: '',
    serviceName: '',
    serviceCategoryName: '',
    status: status,
    scheduledDate: DateTime(2026, 1, 1),
    priceQuoted: 0,
    requiredWorkerCount: 2,
  );

  group('who may be called', () {
    test('a worker on the job', () {
      expect(order().canCallCrewMember(worker()), isTrue);
    });

    test('not a worker who has not answered yet', () {
      // Being put on the job is not the same as having taken it, and the rule has to read the
      // same way as the hiring-post one — the same person can arrive by either route.
      expect(order().canCallCrewMember(worker(status: 'Assigned')), isFalse);
    });

    test('a worker who finished the job', () {
      // Still reachable, because a finished worker can still be owed money.
      expect(order().canCallCrewMember(worker(status: 'Completed')), isTrue);
    });

    test('not a worker who turned the job down', () {
      expect(order().canCallCrewMember(worker(status: 'Rejected')), isFalse);
    });

    test('not without a phone number', () {
      expect(order().canCallCrewMember(worker(workerPhone: null)), isFalse);
    });

    test('not on an empty phone number', () {
      expect(order().canCallCrewMember(worker(workerPhone: '')), isFalse);
    });
  });

  group('once the order is over', () {
    test('gone when completed and the worker was paid', () {
      final o = order(status: 'Completed');
      expect(o.canCallCrewMember(worker(paymentStatus: 'Paid')), isFalse);
    });

    test('gone when cancelled and the worker was paid', () {
      final o = order(status: 'Cancelled');
      expect(o.canCallCrewMember(worker(paymentStatus: 'Paid')), isFalse);
    });

    test('gone when the worker is paid outside Zuno', () {
      // A regular on a monthly wage is owed nothing per job, so nothing outlives it.
      final o = order(status: 'Completed');
      expect(o.canCallCrewMember(worker(agreedSalaryAmount: null)), isFalse);
    });

    test('the business can still call the customer, though', () {
      // The two rules are not the same rule, and this is the assertion that keeps them apart.
      final o = order(status: 'Completed');
      expect(o.canBeCalled, isTrue);
      expect(o.canCallCrewMember(worker(paymentStatus: 'Paid')), isFalse);
    });
  });

  // Changed: once the job is over the crew row offers no call or chat, even while wages are
  // still owed (it used to stay callable). Settling pay is done through Pay crew and raises.
  group('once the order is over', () {
    for (final unsettled in ['Unpaid', 'Processing', 'Failed', 'Disputed']) {
      test('not callable or messageable, even while pay reads $unsettled', () {
        final o = order(status: 'Completed');
        final w = worker(paymentStatus: unsettled);
        expect(o.canCallCrewMember(w), isFalse);
        expect(o.canMessageCrewMember(w), isFalse);
      });
    }

    test('but not to somebody who refused and is owed nothing', () {
      final o = order(status: 'Completed');
      expect(
        o.canCallCrewMember(
          worker(status: 'Rejected', paymentStatus: 'Unpaid'),
        ),
        isFalse,
      );
    });
  });
}
