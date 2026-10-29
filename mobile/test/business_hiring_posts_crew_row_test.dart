import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_hiring_posts_tab.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post_application.dart';
import 'package:zuno/features/hiring_post/presentation/providers/business_hiring_posts_notifier.dart';
import 'package:zuno/shared/widgets/status_pill.dart';

/// The crew row, drawn at phone width with a call button in it.
///
/// The row already carried a name, an agreed wage, a delay warning and up to two status pills;
/// the call button is a fourth thing competing for about 296dp. This codebase has shipped two
/// layout failures of exactly this kind, so the assertion that matters most below is simply that
/// nothing threw.
class _FakePosts extends BusinessHiringPostsNotifier {
  _FakePosts(this._posts);

  final List<HiringPost> _posts;

  @override
  Future<List<HiringPost>> build() async => _posts;
}

void main() {
  // Relative to today: the Hiring tab only lists jobs whose hiring is not yet over.
  final soon = DateTime.now().add(const Duration(days: 7));
  final createdOn = DateTime(2026, 9, 1, 10);

  HiringPostApplication application({
    required String id,
    required String workerName,
    String status = 'Accepted',
    String? workerPhone = '9000000000',
    String paymentStatus = 'Unpaid',
  }) => HiringPostApplication(
    id: id,
    workerProfileId: 'w-$id',
    workerName: workerName,
    workerPhone: workerPhone,
    status: status,
    appliedAt: createdOn,
    agreedSalaryAmount: 700,
    agreedSalaryUnit: 'PerEvent',
    paymentStatus: paymentStatus,
  );

  HiringPost post({
    required List<HiringPostApplication> applications,
    String? bookingStatus = 'Confirmed',
  }) => HiringPost(
    id: 'p-1',
    businessOwnerProfileId: 'b-1',
    bookingId: 'bk-1',
    bookingStatus: bookingStatus,
    businessName: 'Test Owner',
    title: 'Paintings',
    eventDate: soon,
    workersNeeded: 3,
    salaryAmount: 700,
    confirmedCount: applications.length,
    filledCount: applications.length,
    status: 'Open',
    createdDate: createdOn,
    applications: applications,
  );

  Future<void> pump(WidgetTester tester, HiringPost data) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessHiringPostsProvider.overrideWith(() => _FakePosts([data])),
        ],
        child: const MaterialApp(
          home: Scaffold(body: BusinessHiringPostsTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The crew list always starts closed; open it to see the rows.
    if (find.text('Crew').evaluate().isNotEmpty) {
      await tester.tap(find.text('Crew'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('a failed payment flags the crew row but leaves it closed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessHiringPostsProvider.overrideWith(
            () => _FakePosts([
              post(
                applications: [
                  application(
                    id: '1',
                    workerName: 'grape grape',
                    paymentStatus: 'Failed',
                  ),
                ],
              ),
            ]),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: BusinessHiringPostsTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Reported from a phone: this one card opened by itself while the rest stayed closed.
    expect(find.text('NEEDS YOU'), findsOneWidget);
    expect(find.text('grape grape'), findsNothing);

    await tester.tap(find.text('Crew'));
    await tester.pumpAndSettle();
    expect(find.text('grape grape'), findsOneWidget);
  });

  testWidgets('a confirmed worker can be called, a phoneless one cannot', (
    tester,
  ) async {
    await pump(
      tester,
      post(
        applications: [
          application(id: '1', workerName: 'Ravi Kumar'),
          application(id: '2', workerName: 'Anita Menon', workerPhone: null),
          application(id: '3', workerName: 'Suresh P', status: 'Applied'),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.text('Anita Menon'), findsOneWidget);

    // One button for three crew: the phoneless worker gets nothing rather than a warning she
    // cannot act on, and somebody merely applying keeps Reject and Confirm instead.
    expect(find.byIcon(Icons.call), findsOneWidget);
  });

  testWidgets('a finished, paid order leaves the Hiring tab altogether', (
    tester,
  ) async {
    await pump(
      tester,
      post(
        bookingStatus: 'Completed',
        applications: [
          application(id: '1', workerName: 'Ravi Kumar', paymentStatus: 'Paid'),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Paintings'), findsNothing);
    expect(find.byIcon(Icons.call), findsNothing);
  });

  // Changed: once the job is over the crew row offers no call or chat, even while owed. The
  // row is still listed (a payment problem keeps it on the tab) so the business can settle it.
  testWidgets('no call or chat once the order is finished, even while owed', (
    tester,
  ) async {
    await pump(
      tester,
      post(
        bookingStatus: 'Completed',
        applications: [
          application(
            id: '1',
            workerName: 'Ravi Kumar',
            paymentStatus: 'Disputed',
          ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.byIcon(Icons.call), findsNothing);
    expect(find.byTooltip('Message worker'), findsNothing);
  });

  testWidgets('the worst case for the width budget still lays out', (
    tester,
  ) async {
    // A long name beside two pills and the call button: the densest this row ever gets, and the
    // reason the name is capped at two lines with an ellipsis.
    await pump(
      tester,
      post(
        applications: [
          application(
            id: '1',
            workerName: 'Krishnankutty Ramachandran',
            paymentStatus: 'AwaitingWorkerConfirmation',
          ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.call), findsOneWidget);
    expect(find.text('Awaiting confirmation'), findsOneWidget);
  });

  testWidgets('the status and payment pills sit a clear gap apart', (
    tester,
  ) async {
    // Reported from a phone: "Accepted" and "Payment failed" stacked 4px apart read as one block.
    await pump(
      tester,
      post(
        applications: [
          application(
            id: '1',
            workerName: 'grape grape',
            paymentStatus: 'Failed',
          ),
        ],
      ),
    );

    Rect pill(String label) => tester.getRect(
      find.ancestor(of: find.text(label), matching: find.byType(StatusPill)),
    );
    final status = pill('Accepted');
    final payment = pill('Payment failed');

    expect(tester.takeException(), isNull);
    // Stacked, right-aligned, and not touching.
    expect(payment.top, greaterThan(status.bottom));
    expect(payment.right, closeTo(status.right, 0.5));
    expect(payment.top - status.bottom, closeTo(StatusPillStack.gap, 0.5));
  });
}
