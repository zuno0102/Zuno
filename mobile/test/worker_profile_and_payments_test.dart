import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/worker/domain/entities/worker_dashboard.dart';
import 'package:zuno/features/worker/domain/entities/worker_profile.dart';
import 'package:zuno/features/worker/presentation/providers/worker_dashboard_notifier.dart';
import 'package:zuno/features/worker/presentation/screens/worker_payments_screen.dart';
import 'package:zuno/features/worker/presentation/screens/worker_profile_screen.dart';

/// The two pages the worker's home now opens into.
///
/// Both read the dashboard rather than taking their content as arguments, so a wage settled on the
/// payments page clears from the card behind it. These tests cover what each page must say — and, as
/// everywhere in this codebase, that nothing threw: a column of cards inside a scroll view is the
/// exact shape that has blanked screens here before.
class _FakeDashboard extends WorkerDashboardNotifier {
  _FakeDashboard(this._data);

  final WorkerDashboard _data;

  @override
  Future<WorkerDashboard> build() async => _data;
}

void main() {
  WorkerProfile profile({
    String? phoneNumber = '9000000000',
    String? upiVpa = 'ravi@okhdfcbank',
    bool hasPayoutDestination = true,
    bool canReceivePayouts = true,
    String payoutVerificationStatus = 'Verified',
    double? hourlyRate = 450,
    int? experienceYears = 4,
  }) => WorkerProfile(
    id: 'w-1',
    fullName: 'Ravi Kumar',
    phoneNumber: phoneNumber,
    email: 'ravi@example.com',
    experienceYears: experienceYears,
    hourlyRate: hourlyRate,
    availabilityStatus: 'Available',
    verificationStatus: 'Verified',
    upiVpa: upiVpa,
    hasPayoutDestination: hasPayoutDestination,
    canReceivePayouts: canReceivePayouts,
    payoutVerificationStatus: payoutVerificationStatus,
    level: 3,
    levelName: 'Experienced',
    jobsToNextLevel: 8,
    totalEarned: 24000,
    jobsCompleted: 12,
    jobsPaid: 11,
  );

  WorkerPendingPayment payment({
    required String id,
    double amount = 800,
    String paymentStatus = 'Unpaid',
  }) => WorkerPendingPayment(
    applicationId: id,
    title: 'Wedding catering',
    businessName: 'Test Business',
    amount: amount,
    unit: 'PerEvent',
    paymentStatus: paymentStatus,
    workCompletedAt: DateTime(2026, 9, 20),
  );

  Future<void> pump(
    WidgetTester tester,
    WorkerDashboard data,
    Widget screen,
  ) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workerDashboardProvider.overrideWith(() => _FakeDashboard(data)),
        ],
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the profile page', () {
    testWidgets('shows who this is, then every detail', (tester) async {
      await pump(
        tester,
        WorkerDashboard(profile: profile()),
        const WorkerProfileScreen(),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('ravi@example.com'), findsOneWidget);
      expect(find.text('Level 3 · Experienced'), findsOneWidget);

      // The rows that used to crowd the home screen.
      expect(find.text('Phone'), findsOneWidget);
      expect(find.text('9000000000'), findsOneWidget);
      expect(find.text('Hourly rate'), findsOneWidget);
      expect(find.text('4 years'), findsOneWidget);
      // Shown in part, never in full.
      expect(find.text('ra••@okhdfcbank'), findsOneWidget);
    });

    testWidgets('says in red what a business would find missing', (
      tester,
    ) async {
      await pump(
        tester,
        WorkerDashboard(profile: profile(phoneNumber: null, hourlyRate: null)),
        const WorkerProfileScreen(),
      );

      expect(
        find.text('Not added — businesses cannot call you'),
        findsOneWidget,
      );
      expect(find.text('Not set'), findsOneWidget);
    });

    group('the payout card', () {
      testWidgets('reads as ready once the UPI is verified', (tester) async {
        await pump(
          tester,
          WorkerDashboard(profile: profile()),
          const WorkerProfileScreen(),
        );

        expect(find.text('Ready to be paid'), findsOneWidget);
        expect(
          find.textContaining('Wages go straight to ra••@okhdfcbank'),
          findsOneWidget,
        );
      });

      testWidgets('says the UPI is not verified, so the worker checks it', (
        tester,
      ) async {
        // A changed UPI is verified again before it can be paid; until then the worker is told to
        // check it, since wages cannot reach them.
        await pump(
          tester,
          WorkerDashboard(
            profile: profile(
              canReceivePayouts: false,
              payoutVerificationStatus: 'Pending',
            ),
          ),
          const WorkerProfileScreen(),
        );

        expect(find.text('Your UPI is not verified'), findsOneWidget);
      });

      testWidgets('says plainly when there is nowhere to send money', (
        tester,
      ) async {
        await pump(
          tester,
          WorkerDashboard(
            profile: profile(
              upiVpa: null,
              hasPayoutDestination: false,
              canReceivePayouts: false,
              payoutVerificationStatus: 'NotSubmitted',
            ),
          ),
          const WorkerProfileScreen(),
        );

        expect(find.text('No payout address'), findsOneWidget);
      });
    });
  });

  group('the payments page', () {
    testWidgets('leads with the total, then one row per job', (tester) async {
      await pump(
        tester,
        WorkerDashboard(
          profile: profile(),
          pendingPayments: [
            payment(id: 'p1'),
            payment(id: 'p2', amount: 900),
          ],
          pendingPaymentTotal: 1700,
        ),
        const WorkerPaymentsScreen(),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('₹1,700'), findsOneWidget);
      expect(find.text('owed across 2 finished jobs'), findsOneWidget);
      expect(find.byType(PendingPaymentRow), findsNWidgets(2));
    });

    testWidgets('every row can be answered either way', (tester) async {
      // The whole point of the page: a worker who was never paid must be able to say so without
      // waiting for the business to claim it was sent.
      await pump(
        tester,
        WorkerDashboard(
          profile: profile(),
          pendingPayments: [payment(id: 'p1')],
          pendingPaymentTotal: 800,
        ),
        const WorkerPaymentsScreen(),
      );

      expect(find.text('Got it'), findsOneWidget);
      expect(find.text('Not paid'), findsOneWidget);
      expect(find.text('Not sent yet'), findsOneWidget);
    });

    testWidgets('a failed payout is not shown as merely waiting', (
      tester,
    ) async {
      await pump(
        tester,
        WorkerDashboard(
          profile: profile(),
          pendingPayments: [payment(id: 'p1', paymentStatus: 'Failed')],
          pendingPaymentTotal: 800,
        ),
        const WorkerPaymentsScreen(),
      );

      expect(find.text('Payment failed'), findsOneWidget);
    });

    testWidgets('an empty page reassures rather than looking broken', (
      tester,
    ) async {
      await pump(
        tester,
        WorkerDashboard(profile: profile()),
        const WorkerPaymentsScreen(),
      );

      expect(find.text('Nothing waiting'), findsOneWidget);
      expect(find.byType(PendingPaymentRow), findsNothing);
    });
  });
}
