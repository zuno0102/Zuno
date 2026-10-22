import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post_application.dart';

/// Hiring runs until the job is over, not until it starts.
///
/// A job needing 3 that only found 2 can still take a late joiner while it is running. It stops
/// for good when the business taps Stop hiring, marks the work done, or the end time passes —
/// and from then on it is no longer a vacancy on the business's Hiring tab.
void main() {
  // A 4-hour job from 10:00 to 14:00.
  final start = DateTime(2026, 10, 22, 10);
  final before = DateTime(2026, 10, 22, 9);
  final during = DateTime(2026, 10, 22, 12);
  final after = DateTime(2026, 10, 22, 15);

  HiringPost post({
    int filledCount = 2,
    DateTime? workStartedAt,
    DateTime? workCompletedAt,
    DateTime? hiringStoppedAt,
    String? bookingStatus,
    List<HiringPostApplication> applications = const [],
  }) => HiringPost(
    id: 'p-1',
    businessOwnerProfileId: 'b-1',
    businessName: 'Test Owner',
    title: 'Wedding catering',
    eventDate: start,
    durationMinutes: 240,
    workersNeeded: 3,
    salaryAmount: 800,
    confirmedCount: filledCount,
    filledCount: filledCount,
    workStartedAt: workStartedAt,
    workCompletedAt: workCompletedAt,
    hiringStoppedAt: hiringStoppedAt,
    bookingStatus: bookingStatus,
    status: 'Open',
    createdDate: before,
    applications: applications,
  );

  group('A late joiner', () {
    test('can still apply while the work is running', () {
      final p = post(workStartedAt: start);
      expect(p.isOpenToWorkers(now: during), isTrue);
      expect(p.isInvitable(now: during), isTrue);
    });

    test('sees it flagged as needed now, but not before it starts', () {
      expect(post().isNeededNow(now: during), isTrue);
      expect(post().isNeededNow(now: before), isFalse);
    });

    test('cannot once the end time has passed', () {
      expect(post().isOpenToWorkers(now: after), isFalse);
    });

    test('cannot once the work is marked completed', () {
      final p = post(workStartedAt: start, workCompletedAt: during);
      expect(p.isOpenToWorkers(now: during), isFalse);
      expect(p.isInvitable(now: during), isFalse);
    });

    test('cannot once the business stops hiring', () {
      final p = post(hiringStoppedAt: before);
      expect(p.isOpenToWorkers(now: before), isFalse);
      expect(p.isInvitable(now: before), isFalse);
      expect(p.canStopHiring(now: before), isFalse);
    });
  });

  group('The business Hiring tab', () {
    test('lists a vacancy still being filled, even mid-job', () {
      expect(post().isListedAsVacancy(now: before), isTrue);
      expect(post(workStartedAt: start).isListedAsVacancy(now: during), isTrue);
    });

    test('drops it once hiring is stopped', () {
      expect(
        post(hiringStoppedAt: before).isListedAsVacancy(now: before),
        isFalse,
      );
    });

    test('drops it once the work is completed', () {
      final p = post(workStartedAt: start, workCompletedAt: during);
      expect(p.isListedAsVacancy(now: during), isFalse);
    });

    test('drops it once the end time has passed', () {
      expect(post().isListedAsVacancy(now: after), isFalse);
    });

    test("keeps a finished job while a worker's pay is disputed", () {
      final disputed = HiringPostApplication(
        id: 'a-1',
        workerProfileId: 'w-1',
        workerName: 'Ravi Kumar',
        status: 'Accepted',
        appliedAt: before,
        paymentStatus: 'Disputed',
      );
      final p = post(
        workStartedAt: start,
        workCompletedAt: during,
        applications: [disputed],
      );
      expect(p.isListedAsVacancy(now: after), isTrue);
    });

    test('drops it once its order is closed', () {
      expect(
        post(bookingStatus: 'Completed').isListedAsVacancy(now: before),
        isFalse,
      );
    });
  });

  group('The Workers line', () {
    test('says hiring stopped when short-handed', () {
      expect(
        post(hiringStoppedAt: before).workersDetail(now: before),
        '2 of 3 · hiring stopped',
      );
    });

    test('is not "nobody hired" while an empty job is still hiring', () {
      final p = post(filledCount: 0);
      expect(p.workersDetail(now: during), isNot('Nobody was hired'));
      expect(p.workersDetail(now: after), 'Nobody was hired');
    });
  });
}
