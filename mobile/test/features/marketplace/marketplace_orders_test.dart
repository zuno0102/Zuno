import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/catalog/domain/entities/app_options.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_order.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_order_providers.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:zuno/features/marketplace/presentation/screens/marketplace_order_detail_screen.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_b2b_request_card.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_order_card.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_payment_settings_sheet.dart';

import 'marketplace_order_fakes.dart';

const _options = MarketplaceOptions(
  kinds: [],
  statuses: [],
  imageSlots: 3,
  maxFoodOfferHours: 24,
  maxAdDays: 60,
  orderStatuses: testOrderStatuses,
  b2bRequestStatuses: testB2BStatuses,
  paymentMethods: testPaymentMethods,
  couriers: testCouriers,
);

/// Shows [build]'s widget with the orders kept in [repo], read back after every change — as the
/// Orders tab does, which lists from the provider.
Future<FakeMarketplaceOrderRepository> _pump(
  WidgetTester tester,
  FakeMarketplaceOrderRepository repo,
  Widget Function(WidgetRef ref) build,
) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        marketplaceOrderRepositoryProvider.overrideWithValue(repo),
        marketplaceOptionsProvider.overrideWith((ref) async => _options),
        currentAppOptionsProvider.overrideWithValue(AppOptions.defaults),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(builder: (context, ref, _) => build(ref)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

/// The first order as the provider has it now.
Widget _firstOrderCard(WidgetRef ref) {
  final page = ref.watch(businessMarketplaceOrdersProvider()).value;
  if (page == null) return const SizedBox();
  return ListView(
    children: [for (final o in page.items) MarketplaceOrderCard(order: o)],
  );
}

Widget _requests(WidgetRef ref) {
  final page = ref.watch(businessB2BRequestsProvider()).value;
  if (page == null) return const SizedBox();
  return ListView(
    children: [
      for (final r in page.items) MarketplaceB2BRequestCard(request: r),
    ],
  );
}

void main() {
  group('Order card', () {
    testWidgets('a new cash order shows what, who, money, and Confirm order', (
      tester,
    ) async {
      final repo = await _pump(
        tester,
        FakeMarketplaceOrderRepository(orders: [testOrder()]),
        _firstOrderCard,
      );

      expect(find.text('2 × Silk saree · Red'), findsOneWidget);
      expect(find.text('Priya S'), findsOneWidget);
      expect(
        find.text('New'),
        findsOneWidget,
        reason: 'the status name from the server table',
      );
      expect(find.text('₹4,800 · Cash on delivery'), findsOneWidget);
      expect(find.byTooltip('Call customer'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('marketplace-order-action-o-1-Confirmed')),
      );
      await tester.pumpAndSettle();

      expect(repo.steps, ['o-1→Confirmed']);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Mark shipped'), findsOneWidget);
    });

    testWidgets(
      'Mark shipped needs a courier and a tracking number, then shows them',
      (tester) async {
        final repo = await _pump(
          tester,
          FakeMarketplaceOrderRepository(
            orders: [testOrder(status: 'Confirmed')],
          ),
          _firstOrderCard,
        );

        await tester.tap(find.text('Mark shipped'));
        await tester.pumpAndSettle();
        expect(find.text('How did you send it?'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('marketplace-ship-save')));
        await tester.pumpAndSettle();
        expect(find.text('Choose the courier.'), findsOneWidget);
        expect(
          find.text("Enter the tracking number from the courier's receipt."),
          findsOneWidget,
        );
        expect(repo.shipped, isEmpty);

        await tester.tap(
          find.byKey(const ValueKey('marketplace-ship-courier')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('DTDC').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('marketplace-ship-number')),
          'D 451',
        );
        await tester.tap(find.byKey(const ValueKey('marketplace-ship-save')));
        await tester.pumpAndSettle();
        expect(
          find.text('Use only letters, digits and dashes.'),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const ValueKey('marketplace-ship-number')),
          ' D45120098871 ',
        );
        await tester.tap(find.byKey(const ValueKey('marketplace-ship-save')));
        await tester.pumpAndSettle();

        expect(repo.shipped.single.courierCode, 'dtdc');
        expect(repo.shipped.single.trackingNumber, 'D45120098871');
        expect(repo.shipped.single.courierName, isNull);
        expect(find.text('How did you send it?'), findsNothing);
        expect(find.text('DTDC · D45120098871'), findsOneWidget);
        expect(find.text('Out for delivery'), findsWidgets);
      },
    );

    testWidgets('"Other" courier asks for its name', (tester) async {
      final repo = await _pump(
        tester,
        FakeMarketplaceOrderRepository(
          orders: [testOrder(status: 'Confirmed')],
        ),
        _firstOrderCard,
      );
      await tester.tap(find.text('Mark shipped'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('marketplace-ship-courier-name')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('marketplace-ship-courier')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('marketplace-ship-number')),
        'AP-7781',
      );
      await tester.tap(find.byKey(const ValueKey('marketplace-ship-save')));
      await tester.pumpAndSettle();
      expect(find.text("Type the courier's name."), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('marketplace-ship-courier-name')),
        'Anbu Parcel Service',
      );
      await tester.tap(find.byKey(const ValueKey('marketplace-ship-save')));
      await tester.pumpAndSettle();
      expect(repo.shipped.single.courierName, 'Anbu Parcel Service');
    });

    testWidgets(
      'Mark delivered asks first; cancelling the question changes nothing',
      (tester) async {
        final repo = await _pump(
          tester,
          FakeMarketplaceOrderRepository(
            orders: [
              testOrder(
                status: 'OutForDelivery',
                courierName: 'DTDC',
                trackingNumber: 'D451',
              ),
            ],
          ),
          _firstOrderCard,
        );

        await tester.tap(find.text('Mark delivered'));
        await tester.pumpAndSettle();
        expect(find.text('Mark delivered?'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(repo.steps, isEmpty);

        await tester.tap(find.text('Mark delivered'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(FilledButton, 'Mark delivered').last,
        );
        await tester.pumpAndSettle();
        expect(repo.steps, ['o-1→Delivered']);
        expect(find.text('₹4,800 · Cash received'), findsOneWidget);
      },
    );

    testWidgets(
      'cancelled and closed orders say what happened, with no buttons',
      (tester) async {
        await _pump(
          tester,
          FakeMarketplaceOrderRepository(
            orders: [
              testOrder(status: 'Cancelled', cancelledBy: 'Customer'),
              testOrder(
                id: 'o-2',
                status: 'Closed',
                ratingScore: 4,
                ratingComment: 'Good quality',
              ),
              testOrder(
                id: 'o-3',
                status: 'Cancelled',
                cancelledBy: 'System',
                paymentMethod: 'Online',
              ),
            ],
          ),
          _firstOrderCard,
        );

        expect(
          find.textContaining('Cancelled by the customer, before shipping'),
          findsOneWidget,
        );
        expect(find.textContaining('Not paid in time'), findsOneWidget);
        expect(find.text('4 of 5 · "Good quality"'), findsOneWidget);
        expect(find.byType(FilledButton), findsNothing);
      },
    );
  });

  group('Order page', () {
    testWidgets(
      'shows customer, address, payment, due to you, courier with Track, and history',
      (tester) async {
        await _pump(
          tester,
          FakeMarketplaceOrderRepository(
            orders: [
              testOrder(
                status: 'Shipped',
                paymentMethod: 'Online',
                isPaid: true,
                dueToBusiness: 4800,
                courierName: 'Delhivery',
                trackingNumber: '149021',
                trackingUrl: 'https://www.delhivery.com/track/package/149021',
                events: [
                  MarketplaceOrderEvent(
                    status: 'AwaitingPayment',
                    statusName: 'Awaiting payment',
                    actor: 'Customer',
                    at: DateTime(2026, 11, 18, 10, 40),
                  ),
                  MarketplaceOrderEvent(
                    status: 'Confirmed',
                    statusName: 'Confirmed',
                    actor: 'Customer',
                    note: 'Paid online',
                    at: DateTime(2026, 11, 18, 10, 42),
                  ),
                  MarketplaceOrderEvent(
                    status: 'Shipped',
                    statusName: 'Shipped',
                    actor: 'Business',
                    note: 'Delhivery · 149021',
                    at: DateTime(2026, 11, 19, 9, 0),
                  ),
                ],
              ),
            ],
          ),
          (ref) => const MarketplaceOrderDetailScreen(orderId: 'o-1'),
        );

        expect(find.text('Order #O1'), findsOneWidget);
        expect(find.text('Priya S · 9876543210'), findsOneWidget);
        expect(
          find.text('12, North Street, Nagercoil · 629001'),
          findsOneWidget,
        );
        expect(find.text('2 × ₹2,400 = ₹4,800'), findsOneWidget);
        expect(find.text('₹4,800 · Paid online'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('marketplace-order-due')),
          findsOneWidget,
        );
        expect(find.text('Delhivery · 149021'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('marketplace-order-track')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('marketplace-order-add-receipt')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Confirmed · by the customer'),
          findsOneWidget,
        );
        expect(find.textContaining('Shipped · by you'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('marketplace-order-step-OutForDelivery')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a cash order owes nothing and has no Track button without a link',
      (tester) async {
        await _pump(
          tester,
          FakeMarketplaceOrderRepository(
            orders: [
              testOrder(
                status: 'Shipped',
                courierName: 'DTDC',
                trackingNumber: 'D451',
              ),
            ],
          ),
          (ref) => const MarketplaceOrderDetailScreen(orderId: 'o-1'),
        );
        expect(
          find.byKey(const ValueKey('marketplace-order-due')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('marketplace-order-track')),
          findsNothing,
        );
        expect(find.text('DTDC · D451'), findsOneWidget);
      },
    );
  });

  group('B2B requests', () {
    testWidgets(
      'a new request hides the contact until accepted, then shows the buyer\'s number',
      (tester) async {
        final repo = await _pump(
          tester,
          FakeMarketplaceOrderRepository(requests: [testRequest()]),
          _requests,
        );

        expect(find.text('Nendran banana'), findsOneWidget);
        expect(find.text('Kumar Traders'), findsOneWidget);
        expect(
          find.text('500 kg × ₹38 = ₹19,000 · smallest order 200 kg'),
          findsOneWidget,
        );
        expect(find.text('"Weekly supply to Thuckalay?"'), findsOneWidget);
        expect(
          find.text('Contact details show once you accept.'),
          findsOneWidget,
        );
        expect(find.byTooltip('Call Kumar Traders'), findsNothing);

        await tester.tap(
          find.byKey(const ValueKey('marketplace-b2b-accept-r-1')),
        );
        await tester.pumpAndSettle();

        expect(repo.answers.single.accept, isTrue);
        expect(find.text('Accepted'), findsOneWidget);
        expect(find.textContaining('9843012345'), findsOneWidget);
        expect(find.byTooltip('Call Kumar Traders'), findsOneWidget);
        expect(
          find.text(
            'The buyer sees your contact while their B2B plan is active.',
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('marketplace-b2b-accept-r-1')),
          findsNothing,
        );
      },
    );

    testWidgets('Decline asks first', (tester) async {
      final repo = await _pump(
        tester,
        FakeMarketplaceOrderRepository(requests: [testRequest()]),
        _requests,
      );

      await tester.tap(
        find.byKey(const ValueKey('marketplace-b2b-decline-r-1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Decline this request?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Decline'));
      await tester.pumpAndSettle();

      expect(repo.answers.single.accept, isFalse);
      expect(find.text('Declined'), findsOneWidget);
      expect(find.textContaining('9843012345'), findsNothing);
    });
  });

  group('How customers pay', () {
    testWidgets('names come from the server; at least one way stays on', (
      tester,
    ) async {
      final repo = await _pump(
        tester,
        FakeMarketplaceOrderRepository(),
        (ref) => const MarketplacePaymentSettingsSheet(),
      );

      expect(find.text('Cash on delivery'), findsOneWidget);
      expect(find.text('Online pay'), findsOneWidget);
      expect(find.textContaining('UPI, cards and net banking'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('marketplace-pay-cash')));
      await tester.tap(find.byKey(const ValueKey('marketplace-pay-online')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('marketplace-pay-save')));
      await tester.pumpAndSettle();
      expect(
        find.text('Keep at least one way for customers to pay.'),
        findsOneWidget,
      );
      expect(
        repo.settings.acceptsCashOnDelivery,
        isTrue,
        reason: 'nothing was saved',
      );

      await tester.tap(find.byKey(const ValueKey('marketplace-pay-cash')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('marketplace-pay-save')));
      await tester.pumpAndSettle();
      expect(repo.settings.acceptsCashOnDelivery, isTrue);
      expect(repo.settings.acceptsOnlinePay, isFalse);
    });

    test('the tile says the choice in a few words', () {
      expect(
        marketplacePaymentSummary(null),
        'Cash on delivery and online pay',
      );
      expect(
        marketplacePaymentSummary(
          const MarketplacePaymentSettings(
            acceptsCashOnDelivery: false,
            acceptsOnlinePay: true,
          ),
        ),
        'Online pay only',
      );
      expect(
        marketplacePaymentSummary(
          const MarketplacePaymentSettings(
            acceptsCashOnDelivery: true,
            acceptsOnlinePay: false,
          ),
        ),
        'Cash on delivery only',
      );
    });
  });
}
