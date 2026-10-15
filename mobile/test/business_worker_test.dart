import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/business_owner/domain/entities/business_worker.dart';

/// The Workers tab row: the green Active chip, and beside it Already booked / At work when the
/// person is spoken for.
///
/// The row says *whether*, never *when* — one date could only show the first of however many
/// jobs a worker holds. Tapping the card opens the schedule, which reports them all; see
/// worker_busy_period_test.dart.
void main() {
  BusinessWorker worker({
    String status = 'Active',
    String availabilityStatus = 'Booked',
  }) => BusinessWorker(
    id: 'bw-1',
    workerProfileId: 'w-1',
    workerName: 'Binu K',
    status: status,
    invitedAt: DateTime(2026, 7, 14),
    availabilityStatus: availabilityStatus,
  );

  test('status and availability are separate axes', () {
    final invited = worker(status: 'Invited', availabilityStatus: 'Active');

    expect(invited.isActive, isFalse);
    expect(invited.isBooked, isFalse);
  });

  test('an active worker can still be booked or at work', () {
    expect(worker().isActive, isTrue);
    expect(worker().isBooked, isTrue);
    expect(worker(availabilityStatus: 'AtWork').isAtWork, isTrue);
  });

  test('a free worker is neither booked nor at work', () {
    final free = worker(availabilityStatus: 'Active');

    expect(free.isBooked, isFalse);
    expect(free.isAtWork, isFalse);
  });
}
