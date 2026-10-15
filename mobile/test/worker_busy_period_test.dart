import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/business_owner/domain/entities/worker_busy_period.dart';

/// A worker's schedule, as the popup behind the "Already booked" card reads it.
///
/// Times only — the work is never named. And nothing is merged: the two cases that drove this
/// were a worker booked on several dates, and a worker booked twice on the *same* date, which
/// the old distinct-timestamp query quietly collapsed into one.
void main() {
  WorkerBusyPeriod period(
    DateTime startsAt, {
    Duration length = const Duration(hours: 2),
  }) => WorkerBusyPeriod(startsAt: startsAt, endsAt: startsAt.add(length));

  group('one entry', () {
    test('shows the window, not just the start', () {
      expect(period(DateTime(2026, 9, 23, 9)).timeRange, '09:00 – 11:00');
    });

    test('groups under the day it starts', () {
      expect(period(DateTime(2026, 9, 23, 9)).day, DateTime(2026, 9, 23));
    });

    test('flags work that runs past midnight', () {
      final overnight = period(
        DateTime(2026, 9, 23, 23),
        length: const Duration(hours: 3),
      );

      expect(overnight.endsNextDay, isTrue);
      expect(period(DateTime(2026, 9, 23, 9)).endsNextDay, isFalse);
    });

    test('carries nothing that could name the work', () {
      // The entity holds two fields. If a title ever creeps back in, this fails — the diary
      // spans every business the worker serves, and one has no claim on another's customers.
      final p = period(DateTime(2026, 9, 23, 9));

      expect(p.timeRange, matches(RegExp(r'^\d{2}:\d{2} – \d{2}:\d{2}$')));
    });
  });

  group('grouping — the two cases that prompted this', () {
    /// The same grouping the dialog does, pinned here rather than only drawn.
    Map<DateTime, List<WorkerBusyPeriod>> byDay(List<WorkerBusyPeriod> ps) {
      final out = <DateTime, List<WorkerBusyPeriod>>{};
      for (final p in ps) {
        out.putIfAbsent(p.day, () => []).add(p);
      }
      return out;
    }

    test('several dates become several headings', () {
      final grouped = byDay([
        period(DateTime(2026, 9, 23, 9)),
        period(DateTime(2026, 9, 25, 14)),
        period(DateTime(2026, 10, 2, 8)),
      ]);

      expect(grouped.length, 3);
      expect(grouped.values.every((v) => v.length == 1), isTrue);
    });

    test('two jobs on one date stay two jobs under one heading', () {
      final grouped = byDay([
        period(DateTime(2026, 9, 23, 9)),
        period(DateTime(2026, 9, 23, 14)),
      ]);

      expect(grouped.length, 1, reason: 'one heading');
      expect(grouped[DateTime(2026, 9, 23)]!.length, 2, reason: 'two rows under it');
    });

    test('two jobs at the identical hour are still two entries', () {
      // The exact shape the old query lost. A double-booking is the most important thing this
      // screen can show, so it must never be collapsed away.
      final clash = DateTime(2026, 9, 23, 9);
      final grouped = byDay([period(clash), period(clash)]);

      expect(grouped[DateTime(2026, 9, 23)]!.length, 2);
    });

    test('a job crossing midnight is filed under the day it starts', () {
      final grouped = byDay([
        period(DateTime(2026, 9, 23, 23), length: const Duration(hours: 3)),
      ]);

      expect(grouped.keys.single, DateTime(2026, 9, 23));
    });
  });
}
