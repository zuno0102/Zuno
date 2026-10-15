import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/worker/presentation/screens/worker_jobs_tab.dart';

/// How a worker's jobs are split into sections.
///
/// The jobs tab was one flat list in whatever order the server returned, so an offer waiting on the
/// worker could sit below a job finished last month. These tests pin the two properties that make
/// the split trustworthy: every job lands in exactly one bucket, and the bucket that asks something
/// of the worker wins over every other.
void main() {
  final now = DateTime(2026, 9, 28, 12);
  final tomorrow = DateTime(2026, 9, 29, 10);
  final lastMonth = DateTime(2026, 8, 14, 10);

  Booking job({
    required String id,
    String status = 'Confirmed',
    String? myAssignmentStatus = 'Accepted',
    DateTime? scheduledDate,
  }) => Booking(
    id: id,
    businessOwnerProfileId: '',
    businessName: 'Test Business',
    customerProfileId: '',
    customerName: '',
    businessServiceId: '',
    serviceName: 'Catering',
    serviceCategoryName: '',
    status: status,
    scheduledDate: scheduledDate ?? tomorrow,
    priceQuoted: 0,
    requiredWorkerCount: 1,
    myAssignmentStatus: myAssignmentStatus,
  );

  group('which section a job lands in', () {
    test('an unanswered offer waits for the worker', () {
      final s = WorkerJobSections.from([
        job(id: 'a', myAssignmentStatus: 'Assigned'),
      ], now: now);

      expect(s.needsAnswer.map((j) => j.id), ['a']);
      expect(s.active, isEmpty);
      expect(s.upcoming, isEmpty);
      expect(s.finished, isEmpty);
    });

    test('work under way is on the job', () {
      final s = WorkerJobSections.from([
        job(id: 'a', status: 'InProgress'),
      ], now: now);

      expect(s.active.map((j) => j.id), ['a']);
    });

    test('a future job is coming up', () {
      final s = WorkerJobSections.from([job(id: 'a')], now: now);

      expect(s.upcoming.map((j) => j.id), ['a']);
    });

    test('a completed job is history', () {
      final s = WorkerJobSections.from([
        job(id: 'a', status: 'Completed', scheduledDate: lastMonth),
      ], now: now);

      expect(s.finished.map((j) => j.id), ['a']);
    });

    test('a cancelled job is history too', () {
      final s = WorkerJobSections.from([
        job(id: 'a', status: 'Cancelled', scheduledDate: lastMonth),
      ], now: now);

      expect(s.finished.map((j) => j.id), ['a']);
    });

    test('a job whose day went by unstarted stays with the live work', () {
      // Not upcoming — a worker would plan around a date that has already passed — and not
      // finished, because nobody has said it is.
      final s = WorkerJobSections.from([
        job(id: 'a', scheduledDate: lastMonth),
      ], now: now);

      expect(s.active.map((j) => j.id), ['a']);
      expect(s.upcoming, isEmpty);
      expect(s.finished, isEmpty);
    });
  });

  group('the answer section wins', () {
    test('even when the date has already passed', () {
      // The assertion this split exists for. An unanswered offer is the one thing only the worker
      // can clear, and filing it under history by date is how it gets missed for ever.
      final s = WorkerJobSections.from([
        job(id: 'a', myAssignmentStatus: 'Assigned', scheduledDate: lastMonth),
      ], now: now);

      expect(s.needsAnswer.map((j) => j.id), ['a']);
      expect(s.finished, isEmpty);
    });

    test('but not on a job the business called off', () {
      // Nothing to accept once the job is gone, and showing Accept would be offering something
      // that no longer exists.
      final s = WorkerJobSections.from([
        job(id: 'a', myAssignmentStatus: 'Assigned', status: 'Cancelled'),
      ], now: now);

      expect(s.needsAnswer, isEmpty);
      expect(s.finished.map((j) => j.id), ['a']);
    });
  });

  group('nothing is lost or duplicated', () {
    test('every job lands in exactly one section', () {
      final jobs = [
        job(id: 'answer', myAssignmentStatus: 'Assigned'),
        job(id: 'running', status: 'InProgress'),
        job(id: 'future'),
        job(id: 'done', status: 'Completed', scheduledDate: lastMonth),
        job(id: 'called-off', status: 'Cancelled', scheduledDate: lastMonth),
        job(id: 'overdue', scheduledDate: lastMonth),
      ];

      final s = WorkerJobSections.from(jobs, now: now);

      expect(s.total, jobs.length, reason: 'no job was dropped or counted twice');

      final placed = [
        ...s.needsAnswer,
        ...s.active,
        ...s.upcoming,
        ...s.finished,
      ].map((j) => j.id).toList();

      expect(placed.toSet().length, jobs.length);
      expect(placed.toSet(), jobs.map((j) => j.id).toSet());
    });

    test('an empty list gives four empty sections, not an error', () {
      final s = WorkerJobSections.from([], now: now);

      expect(s.total, 0);
    });
  });

  group('the order within a section', () {
    test('work still to come is soonest first', () {
      final s = WorkerJobSections.from([
        job(id: 'later', scheduledDate: DateTime(2026, 10, 5)),
        job(id: 'sooner', scheduledDate: DateTime(2026, 9, 30)),
      ], now: now);

      expect(s.upcoming.map((j) => j.id), ['sooner', 'later']);
    });

    test('history is most recent first', () {
      // The opposite order, and deliberately so: nobody scrolls to the bottom to find what they
      // did last week.
      final s = WorkerJobSections.from([
        job(id: 'older', status: 'Completed', scheduledDate: DateTime(2026, 6, 1)),
        job(id: 'newer', status: 'Completed', scheduledDate: DateTime(2026, 9, 1)),
      ], now: now);

      expect(s.finished.map((j) => j.id), ['newer', 'older']);
    });
  });
}
