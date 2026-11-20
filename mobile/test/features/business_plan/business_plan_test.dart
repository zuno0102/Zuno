import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/error/app_exceptions.dart';
import 'package:zuno/features/business_owner/domain/entities/business_service.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_services_notifier.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_services_tab.dart';
import 'package:zuno/features/business_plan/domain/business_plan.dart';
import 'package:zuno/features/business_plan/presentation/business_plan_providers.dart';
import 'package:zuno/features/business_plan/presentation/business_plans_screen.dart';
import 'package:zuno/features/business_plan/presentation/plan_lock.dart';

import 'business_plan_fakes.dart';

class _NoServices extends BusinessServicesNotifier {
  @override
  Future<List<BusinessService>> build() async => const [];
}

Future<FakeBusinessPlanRepository> _pump(
  WidgetTester tester,
  Widget child, {
  BusinessPlan? plan,
}) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final repo = FakeBusinessPlanRepository(plan ?? testBusinessPlan());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        businessPlanRepositoryProvider.overrideWithValue(repo),
        businessServicesProvider.overrideWith(_NoServices.new),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  group('Plans screen', () {
    testWidgets(
      'shows Basic with its use, and the monthly plans with their areas',
      (tester) async {
        await _pump(
          tester,
          const BusinessPlansScreen(),
          plan: testBusinessPlan(
            live: {ListingArea.service: 1},
            locked: ListingArea.values.toSet(),
          ),
        );

        expect(find.text('Basic (free)'), findsOneWidget);
        expect(find.textContaining('1 of 1 live listing used'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('plan-offer-service-monthly')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('plan-offer-all3-annual')),
          findsNothing,
        );
        expect(find.text('All 3 · best value'), findsOneWidget);
        expect(find.text('₹699'), findsOneWidget);
      },
    );

    testWidgets(
      'Annual shows the yearly prices and the saving against twelve months',
      (tester) async {
        await _pump(tester, const BusinessPlansScreen());

        await tester.tap(find.text('Annual · save more'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('plan-offer-all3-annual')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('plan-offer-all3-monthly')),
          findsNothing,
        );
        expect(
          find.text('Save ₹1,389 a year'),
          findsOneWidget,
          reason: '699 × 12 − 6,999',
        );
      },
    );

    testWidgets('Buy asks first, then buys and shows the plan running', (
      tester,
    ) async {
      final repo = await _pump(tester, const BusinessPlansScreen());
      repo.afterPurchase = testBusinessPlan(
        planName: 'All 3',
        isBasic: false,
        endsAt: DateTime(2026, 12, 21),
        includes: ListingArea.values.toSet(),
      );

      await tester.tap(find.byKey(const ValueKey('plan-buy-all3-monthly')));
      await tester.pumpAndSettle();
      expect(find.text('Buy All 3 · Monthly?'), findsOneWidget);
      await tester.tap(find.text('Pay ₹699'));
      await tester.pumpAndSettle();

      expect(repo.started, ['p-a-m']);
      expect(repo.confirmed.single.$1, 'sub-1');
      expect(find.textContaining('All 3 · till'), findsOneWidget);
    });

    testWidgets('Not now buys nothing', (tester) async {
      final repo = await _pump(tester, const BusinessPlansScreen());

      await tester.tap(find.byKey(const ValueKey('plan-buy-service-monthly')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(repo.started, isEmpty);
    });

    testWidgets('a paused count says renewing brings them back', (
      tester,
    ) async {
      await _pump(
        tester,
        const BusinessPlansScreen(),
        plan: testBusinessPlan(pausedCount: 6),
      );

      expect(
        find.textContaining('6 listings are paused because a plan ended'),
        findsOneWidget,
      );
    });
  });

  group('Locks', () {
    testWidgets(
      'Add service on a full Basic plan shows the lock, not the form',
      (tester) async {
        await _pump(
          tester,
          const BusinessServicesTab(),
          plan: testBusinessPlan(
            live: {ListingArea.rent: 1},
            locked: ListingArea.values.toSet(),
          ),
        );

        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
        await tester.tap(find.text('Add service'));
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(TextFormField, 'Service name'),
          findsNothing,
        );
        expect(find.text('Service is locked'), findsOneWidget);
        expect(find.text('Service'), findsWidgets);
        expect(
          find.textContaining('₹199/mo'),
          findsOneWidget,
          reason: 'the cheapest monthly plan with Service',
        );
      },
    );

    testWidgets('See plans opens the plans', (tester) async {
      await _pump(
        tester,
        const BusinessServicesTab(),
        plan: testBusinessPlan(locked: ListingArea.values.toSet()),
      );
      await tester.tap(find.text('Add service'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('plan-lock-see-plans')));
      await tester.pumpAndSettle();

      expect(find.byType(BusinessPlansScreen), findsOneWidget);
    });

    testWidgets('an open area opens the form', (tester) async {
      await _pump(tester, const BusinessServicesTab());

      await tester.tap(find.text('Add service'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Service is locked'), findsNothing);

      expect(
        find.widgetWithText(TextFormField, 'Service name'),
        findsOneWidget,
      );
    });

    testWidgets('a server refusal shows the same lock', (tester) async {
      await _pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showLockIfPlanLimit(
              context,
              const PlanLimitAppException(
                'Your plan does not include Rent. Get a plan with Rent to list here.',
              ),
              ListingArea.rent,
            ),
            child: const Text('Save'),
          ),
        ),
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Rent is locked'), findsOneWidget);
      expect(
        find.text(
          'Your plan does not include Rent. Get a plan with Rent to list here.',
        ),
        findsOneWidget,
      );
    });

    test('other errors are not a plan limit', () {
      expect(
        const UnknownAppException('x'),
        isNot(isA<PlanLimitAppException>()),
      );
    });
  });

  group('Plan on Home', () {
    testWidgets('the chip and card say Basic and its use', (tester) async {
      await _pump(
        tester,
        const Column(children: [BusinessPlanChip(), BusinessPlanCard()]),
        plan: testBusinessPlan(live: {ListingArea.marketplace: 1}),
      );

      expect(find.text('Basic · 1 of 1 used'), findsOneWidget);
      expect(find.text('Plan · Basic'), findsOneWidget);
    });

    testWidgets('a paid plan shows its end', (tester) async {
      await _pump(
        tester,
        const BusinessPlanChip(),
        plan: testBusinessPlan(
          planName: 'All 3',
          isBasic: false,
          endsAt: DateTime(2026, 12, 20),
        ),
      );

      expect(find.text('All 3 · till 20 Dec'), findsOneWidget);
    });
  });

  group('The plan', () {
    test('the cheapest plan with an area, and the yearly saving', () {
      final plan = testBusinessPlan();
      expect(plan.cheapestFor(ListingArea.marketplace)!.code, 'all3-monthly');
      expect(plan.cheapestFor(ListingArea.rent)!.code, 'rent-monthly');
      expect(plan.annualSaving(testPlanOffers.last), 1389);
      expect(plan.totalLive, 0);
    });

    test('an area that could not be counted leaves the total unknown', () {
      const plan = BusinessPlan(
        planName: 'Basic',
        isBasic: true,
        basicLimit: 1,
        pausedCount: 0,
        offers: [],
        areas: [AreaUsage(area: ListingArea.rent, canAdd: false)],
      );
      expect(plan.totalLive, isNull);
    });
  });
}
