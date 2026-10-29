import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/vacancy/presentation/providers/worker_vacancies_notifier.dart';
import 'package:zuno/features/worker/domain/entities/worker_dashboard.dart';
import 'package:zuno/features/worker/domain/entities/worker_profile.dart';
import 'package:zuno/features/worker/presentation/providers/worker_dashboard_notifier.dart';
import 'package:zuno/features/worker/presentation/screens/worker_dashboard_tab.dart';

/// The worker's home screen, drawn at phone width.
///
/// The single most important assertion below is that nothing threw. This codebase has shipped two
/// blank screens caused by a stretch into an unbounded height, and a dashboard is exactly the shape
/// that provokes it — a column of cards and a hand-drawn chart inside a scroll view.
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
    bool canReceivePayouts = true,
    bool hasPayoutDestination = true,
    double totalEarned = 24000,
    int jobsCompleted = 12,
    int jobsPaid = 11,
    double? averageSalary = 800,
    int openDisputes = 0,
  }) => WorkerProfile(
    id: 'w-1',
    fullName: 'Ravi Kumar',
    phoneNumber: phoneNumber,
    email: 'ravi@example.com',
    experienceYears: 4,
    hourlyRate: 450,
    availabilityStatus: 'Available',
    verificationStatus: 'Verified',
    upiVpa: upiVpa,
    hasPayoutDestination: hasPayoutDestination,
    canReceivePayouts: canReceivePayouts,
    payoutVerificationStatus: 'Verified',
    totalEarned: totalEarned,
    owedToYou: 0,
    jobsCompleted: jobsCompleted,
    jobsPaid: jobsPaid,
    averageSalary: averageSalary,
    businessesWorkedFor: 3,
    offersDeclined: 1,
    openDisputes: openDisputes,
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

  List<WorkerMonthlyEarning> trend(List<int> jobs) => [
    for (var i = 0; i < jobs.length; i++)
      WorkerMonthlyEarning(
        label: 'M$i',
        year: 2026,
        month: i + 4,
        jobsCompleted: jobs[i],
        earned: jobs[i] * 800,
      ),
  ];

  Future<void> pump(WidgetTester tester, WorkerDashboard data) async {
    // A narrow phone, which is where an overflow shows up.
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workerDashboardProvider.overrideWith(() => _FakeDashboard(data)),
          // No full-time applications: the section still draws its tiles, at zero.
          myVacancyApplicationsProvider.overrideWith((_) async => const []),
        ],
        child: const MaterialApp(home: Scaffold(body: WorkerDashboardTab())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders every section without a layout failure', (tester) async {
    await pump(
      tester,
      WorkerDashboard(
        profile: profile(),
        inProgressCount: 2,
        upcomingCount: 5,
        pendingPayments: [
          payment(id: 'p1'),
          payment(id: 'p2', amount: 900),
        ],
        pendingPaymentTotal: 1700,
        trend: trend([0, 1, 3, 2, 4, 2]),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('AWAITING PAYMENT'), findsOneWidget);
    expect(find.text('EARNED THROUGH ZUNO'), findsOneWidget);
    expect(find.text('Ravi Kumar'), findsOneWidget);
  });

  testWidgets('the three work tiles sit side by side at phone width', (
    tester,
  ) async {
    // The row that would fail with CrossAxisAlignment.stretch in an unbounded column — the exact
    // mistake that has blanked two screens here.
    await pump(
      tester,
      WorkerDashboard(
        profile: profile(),
        inProgressCount: 2,
        upcomingCount: 14,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('On the job'), findsOneWidget);
    expect(find.text('Coming up'), findsOneWidget);
    expect(find.text('Needs you'), findsOneWidget);
  });

  group('money', () {
    testWidgets('owed is shown before what has been banked', (tester) async {
      await pump(
        tester,
        WorkerDashboard(
          profile: profile(),
          pendingPayments: [payment(id: 'p1')],
          pendingPaymentTotal: 800,
        ),
      );

      final owed = tester.getTopLeft(find.text('AWAITING PAYMENT')).dy;
      final earned = tester.getTopLeft(find.text('EARNED THROUGH ZUNO')).dy;
      expect(
        owed,
        lessThan(earned),
        reason: 'a worker opens this asking where their wage is',
      );
    });

    testWidgets('the amount and what it is owed on are both stated', (
      tester,
    ) async {
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
      );

      expect(find.text('₹1,700'), findsOneWidget);
      expect(
        find.textContaining('On 2 jobs you have finished'),
        findsOneWidget,
      );
    });

    testWidgets('the card stays put when nothing is owed, reading as settled', (
      tester,
    ) async {
      // Kept rather than hidden: "am I owed anything" is answered in the same place every time,
      // instead of by a card that only exists on the days the answer is bad.
      await pump(tester, WorkerDashboard(profile: profile()));

      expect(find.text('AWAITING PAYMENT'), findsOneWidget);
      expect(find.text('Nothing waiting'), findsOneWidget);
      // And no ₹0 dressed up as a figure.
      expect(find.text('₹0'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping it opens the payments screen', (tester) async {
      // The only route to confirming or disputing a wage, so it is pinned: this card is how a
      // worker reaches the two buttons that recover their money.
      await pump(
        tester,
        WorkerDashboard(
          profile: profile(),
          pendingPayments: [payment(id: 'p1', paymentStatus: 'Failed')],
          pendingPaymentTotal: 800,
        ),
      );

      await tester.tap(find.text('AWAITING PAYMENT'));
      await tester.pumpAndSettle();

      expect(find.text('Awaiting payment'), findsOneWidget);
      // Distinct from "not sent yet": a failed payout usually means payout details, which is the
      // worker's to fix.
      expect(find.text('Payment failed'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);
      expect(find.text('Not paid'), findsOneWidget);
    });
  });

  group('a worker with no history', () {
    testWidgets('is not shown a row of zeroes', (tester) async {
      await pump(
        tester,
        WorkerDashboard(
          profile: profile(
            totalEarned: 0,
            jobsCompleted: 0,
            jobsPaid: 0,
            averageSalary: null,
          ),
          trend: trend([0, 0, 0, 0, 0, 0]),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('first job is still to come'), findsOneWidget);
      // Six empty months is not a chart worth drawing.
      expect(find.text('Jobs finished each month'), findsNothing);
      expect(find.text('Work and pay'), findsNothing);
    });
  });

  group('payout setup', () {
    testWidgets('is shouted about when there is nowhere to send money', (
      tester,
    ) async {
      await pump(
        tester,
        WorkerDashboard(
          profile: profile(
            upiVpa: null,
            hasPayoutDestination: false,
            canReceivePayouts: false,
          ),
        ),
      );

      expect(find.text('Add your UPI to get paid'), findsOneWidget);
      expect(find.text('Add UPI'), findsOneWidget);
    });

    testWidgets('reads as waiting once details are in and unverified', (
      tester,
    ) async {
      // Nothing for the worker to do here, so it must not read as an action.
      await pump(
        tester,
        WorkerDashboard(profile: profile(canReceivePayouts: false)),
      );

      expect(find.text('Your UPI is being checked'), findsOneWidget);
      expect(find.text('Add UPI'), findsNothing);
    });
  });

  group('the profile card', () {
    testWidgets('is a summary, not the details themselves', (tester) async {
      // The details moved to a page of their own. What stays here is enough to recognise and to
      // tap: the picture, the name and the level.
      await pump(tester, WorkerDashboard(profile: profile()));

      expect(find.text('YOUR PROFILE'), findsOneWidget);
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('Tap to view and edit your details'), findsOneWidget);

      // None of the labelled rows are on the home screen any more.
      expect(find.text('Hourly rate'), findsNothing);
      expect(find.text('Experience'), findsNothing);
    });

    testWidgets('names what is missing rather than counting it', (
      tester,
    ) async {
      // A worker nobody can phone will not go hunting through a profile page, so the nudge stays on
      // the home screen even though the field it refers to does not.
      await pump(tester, WorkerDashboard(profile: profile(phoneNumber: null)));

      expect(find.text('Add your phone number — tap to fix'), findsOneWidget);
    });

    testWidgets('opens the profile page, where the detail lives', (
      tester,
    ) async {
      await pump(tester, WorkerDashboard(profile: profile(phoneNumber: null)));

      await tester.ensureVisible(find.text('YOUR PROFILE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('YOUR PROFILE'));
      await tester.pumpAndSettle();

      expect(find.text('Your profile'), findsOneWidget);
      expect(find.text('YOUR DETAILS'), findsOneWidget);
      // Around a worker in ten, and they are the only person who can fix it.
      expect(find.textContaining('businesses cannot call you'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);
    });
  });
}
