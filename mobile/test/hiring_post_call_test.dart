import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post_application.dart';

/// Whether the business can phone a worker it hired through a post.
///
/// The rule is deliberately split in two, because neither object knows enough on its own: the
/// application knows *who* may be called, and only the post knows *when* the job stopped being
/// live. The tests below are grouped the same way, and the last group is the one that matters —
/// the option has to survive a finished order for exactly as long as the money is unsettled.
void main() {
  final soon = DateTime(2026, 9, 20, 10);
  final createdOn = DateTime(2026, 9, 1, 10);

  HiringPostApplication application({
    String status = 'Accepted',
    String? workerPhone = '9000000000',
    double? agreedSalaryAmount = 700,
    String paymentStatus = 'Unpaid',
  }) => HiringPostApplication(
    id: 'a-1',
    workerProfileId: 'w-1',
    workerName: 'Test Worker',
    workerPhone: workerPhone,
    status: status,
    appliedAt: createdOn,
    agreedSalaryAmount: agreedSalaryAmount,
    agreedSalaryUnit: agreedSalaryAmount == null ? null : 'PerEvent',
    paymentStatus: paymentStatus,
  );

  HiringPost post({
    String? bookingStatus = 'Confirmed',
    DateTime? workCompletedAt,
  }) => HiringPost(
    id: 'p-1',
    businessOwnerProfileId: 'b-1',
    bookingId: bookingStatus == null ? null : 'bk-1',
    bookingStatus: bookingStatus,
    businessName: 'Test Owner',
    title: 'Paintings',
    eventDate: soon,
    workersNeeded: 3,
    salaryAmount: 700,
    confirmedCount: 1,
    filledCount: 1,
    workCompletedAt: workCompletedAt,
    status: 'Open',
    createdDate: createdOn,
  );

  group('who may be called', () {
    test('a worker who took the job', () {
      // Accepting is what puts somebody on the crew, and the number is for working the job out
      // with the people doing it.
      expect(application(status: 'Accepted').canBeCalled, isTrue);
    });

    test('not a worker whose offer is still unanswered', () {
      // The business has approved them, but they have not said yes, so they are not on the crew
      // yet. An approval is not an arrangement.
      expect(application(status: 'Confirmed').canBeCalled, isFalse);
    });

    test('not somebody still merely applying', () {
      // Not chosen yet, and that row carries Reject and Confirm instead.
      expect(application(status: 'Applied').canBeCalled, isFalse);
    });

    test('not somebody the business turned down', () {
      expect(application(status: 'Rejected').canBeCalled, isFalse);
    });

    test('not somebody who turned the job down', () {
      expect(application(status: 'Declined').canBeCalled, isFalse);
    });

    test('not without a phone number', () {
      // Roughly one hired worker in ten, because phone is optional at registration and nothing
      // in the backend can fill it in afterwards.
      expect(application(workerPhone: null).canBeCalled, isFalse);
    });

    test('not on an empty phone number', () {
      // Distinct from null on purpose: a `!= null` test would pass this and dial "tel:".
      expect(application(workerPhone: '').canBeCalled, isFalse);
    });

    test('not on a status this build has never heard of', () {
      // The reason the rule is written as an inclusion list. An exclusion list fails open: the
      // day the server grows a Withdrawn status, it would arrive callable.
      expect(application(status: 'Withdrawn').canBeCalled, isFalse);
    });
  });

  group('while the job is live', () {
    test('yes on a running order', () {
      final p = post();
      expect(p.canCallCrewMember(application()), isTrue);
    });

    test('the who-half still vetoes', () {
      // Being live does not make everyone callable.
      final p = post();
      expect(p.canCallCrewMember(application(status: 'Declined')), isFalse);
    });
  });

  group('once the job is over', () {
    test('gone when the order completed and the worker was paid', () {
      // The headline rule.
      final p = post(bookingStatus: 'Completed');
      expect(p.canCallCrewMember(application(paymentStatus: 'Paid')), isFalse);
    });

    test('gone when the order was cancelled and the worker was paid', () {
      final p = post(bookingStatus: 'Cancelled');
      expect(p.canCallCrewMember(application(paymentStatus: 'Paid')), isFalse);
    });

    test('gone when the work was marked done, even on a standalone post', () {
      // A post with no order behind it is never closed by bookingStatus, so this is the only
      // signal that ends it. Without isWorkCompleted the button would sit there for ever.
      final p = post(bookingStatus: null, workCompletedAt: soon);
      expect(p.isOrderClosed, isFalse, reason: 'no order to close');
      expect(p.canCallCrewMember(application(paymentStatus: 'Paid')), isFalse);
    });

    test('a standalone post whose work is not done is still live', () {
      // The other half of that pair: a null bookingStatus must not read as "finished".
      final p = post(bookingStatus: null);
      expect(p.canCallCrewMember(application()), isTrue);
    });

    test('gone when the worker is paid outside Zuno', () {
      // No wage recorded here, so nothing is owed that could outlive the job.
      final p = post(bookingStatus: 'Completed');
      expect(
        p.canCallCrewMember(application(agreedSalaryAmount: null)),
        isFalse,
      );
    });
  });

  group('but wages outlive the job', () {
    // The exception the whole design turns on. A finished order can still owe money, and chasing
    // that is the one thing after completion a business certainly phones about.
    for (final unsettled in ['Unpaid', 'Processing', 'Failed', 'Disputed']) {
      test('still callable while pay reads $unsettled', () {
        final p = post(bookingStatus: 'Completed');
        expect(
          p.canCallCrewMember(application(paymentStatus: unsettled)),
          isTrue,
        );
      });
    }

    test('and on a cancelled order that still owes money', () {
      final p = post(bookingStatus: 'Cancelled');
      expect(p.canCallCrewMember(application(paymentStatus: 'Failed')), isTrue);
    });

    test('but not to somebody who declined and is owed nothing', () {
      // Unsettled pay reopens the window; it does not widen who is in it.
      final p = post(bookingStatus: 'Completed');
      expect(
        p.canCallCrewMember(
          application(status: 'Declined', paymentStatus: 'Unpaid'),
        ),
        isFalse,
      );
    });
  });
}
