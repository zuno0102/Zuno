import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';

/// What the invite picker is allowed to offer.
///
/// Hiring runs in two shapes and both are listed: crew for a customer's order, and crew for
/// work the business took on outside the app. The rule has to leave the second kind alone while
/// still dropping the first once its order is over — which a post's own status cannot tell you,
/// since it keeps reading "Open" long after the order is finished.
void main() {
  final now = DateTime(2026, 9, 14, 12);
  final soon = DateTime(2026, 9, 20, 10);
  final gone = DateTime(2026, 9, 1, 10);

  HiringPost post({
    String? bookingId = 'bk-1',
    String? bookingStatus = 'Confirmed',
    String status = 'Open',
    DateTime? eventDate,
    int workersNeeded = 3,
    int filledCount = 0,
    DateTime? workCompletedAt,
  }) => HiringPost(
    id: 'p-1',
    businessOwnerProfileId: 'b-1',
    bookingId: bookingId,
    bookingReference: bookingId == null ? null : '#7CF6DF93 · Paintings · 20 Sep',
    bookingStatus: bookingStatus,
    businessName: 'Test Owner',
    title: 'Paintings',
    eventDate: eventDate ?? soon,
    workersNeeded: workersNeeded,
    salaryAmount: 700,
    confirmedCount: 0,
    filledCount: filledCount,
    workCompletedAt: workCompletedAt,
    status: status,
    createdDate: gone,
  );

  group('Crew for a customer order', () {
    test('yes for an open, future job with places left', () {
      expect(post().isInvitable(now: now), isTrue);
    });

    test('no once the order is completed, though the post still reads Open', () {
      final p = post(bookingStatus: 'Completed');
      expect(p.isOpen, isTrue, reason: 'the post never closes itself');
      expect(p.isInvitable(now: now), isFalse);
    });

    test('no once the order is cancelled', () {
      expect(post(bookingStatus: 'Cancelled').isInvitable(now: now), isFalse);
    });

    test('no once the day has gone by', () {
      expect(post(eventDate: gone).isInvitable(now: now), isFalse);
    });

    test('no once the work is marked done', () {
      expect(post(workCompletedAt: gone).isInvitable(now: now), isFalse);
    });

    test('no once every place is taken', () {
      expect(
        post(workersNeeded: 3, filledCount: 3).isInvitable(now: now),
        isFalse,
      );
    });

    test('the picker names it by its order code', () {
      expect(post().bookingReference, startsWith('#7CF6DF93'));
    });
  });

  group('Crew for the business\'s own work, booked outside the app', () {
    HiringPost offline({
      DateTime? eventDate,
      int workersNeeded = 3,
      int filledCount = 0,
    }) => post(
      bookingId: null,
      bookingStatus: null,
      eventDate: eventDate,
      workersNeeded: workersNeeded,
      filledCount: filledCount,
    );

    test('is listed — having no order is not a reason to hide it', () {
      expect(offline().isOrderClosed, isFalse);
      expect(offline().isInvitable(now: now), isTrue);
    });

    test('has no order code, so the picker falls back to its title', () {
      expect(offline().bookingReference, isNull);
    });

    test('still drops out when its own day has gone by', () {
      expect(offline(eventDate: gone).isInvitable(now: now), isFalse);
    });

    test('still drops out when every place is taken', () {
      expect(
        offline(workersNeeded: 2, filledCount: 2).isInvitable(now: now),
        isFalse,
      );
    });
  });
}
