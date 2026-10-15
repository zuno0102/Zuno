import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/business_owner/domain/entities/business_dashboard.dart';

/// A worker's availability has to say *when*, not just *whether*.
///
/// "Booked" reads identically for someone busy this afternoon and someone busy in March, and a
/// business staffing tomorrow's job cannot tell those apart. These pin the line that fixes it.
void main() {
  DashboardWorker worker({
    String availabilityStatus = 'Booked',
    DateTime? busyOn,
  }) => DashboardWorker(
    workerProfileId: 'w-1',
    workerName: 'Binu K',
    availabilityStatus: availabilityStatus,
    sinceDate: DateTime(2026, 7, 14),
    busyOn: busyOn,
  );

  group('relativeDayLabel', () {
    final now = DateTime(2026, 9, 15, 12);

    test('names today and tomorrow rather than making you count', () {
      expect(relativeDayLabel(DateTime(2026, 9, 15, 18), now: now), 'Today');
      expect(relativeDayLabel(DateTime(2026, 9, 16, 12), now: now), 'Tomorrow');
    });

    test('counts forward for anything further out', () {
      expect(relativeDayLabel(DateTime(2026, 9, 23, 12), now: now), 'In 8 days');
    });

    test('counts backward for dates gone by', () {
      expect(relativeDayLabel(DateTime(2026, 9, 14, 12), now: now), 'Yesterday');
      expect(relativeDayLabel(DateTime(2026, 9, 10, 12), now: now), '5 days ago');
    });
  });

  group('busyDetail', () {
    test('says when the job holding them starts', () {
      final detail = worker(busyOn: DateTime(2026, 9, 23, 9)).busyDetail;

      expect(detail, 'From 23 Sep 09:00');
    });

    test('never names the work', () {
      // The diary spans every business this worker serves; naming a job would show one
      // business another's customers.
      final detail = worker(busyOn: DateTime(2026, 9, 23, 9)).busyDetail!;

      expect(detail, matches(RegExp(r'^From \d{1,2} \w{3} \d{2}:\d{2}$')));
    });

    test('carries no "in N days" tail', () {
      final soon = DateTime.now().add(const Duration(days: 3));
      final detail = worker(busyOn: soon).busyDetail!;

      expect(detail, isNot(contains('days')));
      expect(detail, isNot(contains('Tomorrow')));
    });

    test('is null for someone free, so the row omits the line', () {
      expect(worker(availabilityStatus: 'Active').busyDetail, isNull);
    });
  });

  group('availability flags', () {
    test('free is the absence of the other two, not a value of its own', () {
      expect(worker(availabilityStatus: 'Active').isFree, isTrue);
      expect(worker(availabilityStatus: 'Booked').isFree, isFalse);
      expect(worker(availabilityStatus: 'AtWork').isFree, isFalse);
    });

    test('labels read as a person would say them', () {
      expect(worker(availabilityStatus: 'AtWork').availabilityLabel, 'On a job now');
      expect(worker(availabilityStatus: 'Booked').availabilityLabel, 'Booked');
      expect(worker(availabilityStatus: 'Active').availabilityLabel, 'Free');
    });
  });
}
