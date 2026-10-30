import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuno/core/payments/razorpay_checkout.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/auth/domain/entities/user.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/auth/presentation/providers/auth_state.dart';
import 'package:zuno/features/booking/domain/entities/booking_message.dart';
import 'package:zuno/features/booking/presentation/screens/booking_chat_screen.dart';
import 'package:zuno/features/customer/presentation/providers/customer_search_filter_provider.dart';
import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/features/rental/domain/entities/rental_item.dart';
import 'package:zuno/features/rental/domain/entities/rental_payment.dart';
import 'package:zuno/features/rental/domain/entities/rental_stock.dart';
import 'package:zuno/features/rental/domain/rental_customer_repository.dart';
import 'package:zuno/features/rental/domain/rental_orders_gateway.dart';
import 'package:zuno/features/rental/presentation/providers/rental_customer_providers.dart';
import 'package:zuno/features/rental/presentation/providers/rental_order_providers.dart';
import 'package:zuno/features/rental/presentation/providers/rental_payment_providers.dart';
import 'package:zuno/features/rental/presentation/providers/rental_providers.dart';
import 'package:zuno/features/rental/presentation/screens/business_rent_orders_tab.dart';
import 'package:zuno/features/rental/presentation/screens/customer_app_shell.dart';
import 'package:zuno/features/rental/presentation/screens/rental_home_tab.dart';
import 'package:zuno/features/rental/presentation/screens/rental_item_screen.dart';
import 'package:zuno/features/rental/presentation/screens/rental_order_detail_screen.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_item_card.dart';

const _ekm = RentalItemDistrict(
  id: 'd-ekm',
  name: 'Ernakulam',
  stateId: 's-kl',
  stateName: 'Kerala',
);

RentalCard _card(String id, String name, {String category = 'Furniture'}) =>
    RentalCard(
      id: id,
      name: name,
      categoryName: category,
      priceType: 'Daily',
      price: 12,
      unitSuffix: '/day',
      businessName: 'Joy Rentals',
      districtName: 'Ernakulam',
    );

final _chairs = _card('chairs', 'Plastic chair');
final _tent = _card('tent', 'Shamiana', category: 'Tents');
final _cutter = _card('cutter', 'Cutting machine', category: 'Tools');

/// Stands in for the Rent server's customer side: a home that shuffles with the seed, search, one
/// item with a required question, and the stock rule — 2000 chairs, 1700 already booked.
class _FakeCustomerRepository implements RentalCustomerRepository {
  final seeds = <int>[];
  final searches = <String>[];
  RentalBookingInput? booked;
  int held = 1700;

  /// The item's advance, as the business set it.
  String advanceType = RentalAdvanceType.none;
  double? advanceAmount;

  /// Development's simulated collection: no payment window.
  bool simulated = false;
  final payments = <String>[];

  @override
  Future<List<RentalHomeSection>> home(
    int seed,
    List<String> districtIds,
  ) async {
    seeds.add(seed);
    // A different seed, a different order — what the customer sees after a pull.
    final items = seed.isEven
        ? [_chairs, _tent, _cutter]
        : [_cutter, _tent, _chairs];
    return [
      RentalHomeSection(
        code: 'popular',
        title: 'Popular near you',
        layout: RentalHomeLayout.strip,
        items: items.take(2).toList(),
      ),
      RentalHomeSection(
        code: 'explore',
        title: 'Explore',
        layout: RentalHomeLayout.grid,
        items: items,
      ),
    ];
  }

  @override
  Future<List<RentalCard>> banners(List<String> districtIds) async => [_chairs];

  @override
  Future<List<RentalCard>> search({
    String? categoryId,
    String? keyword,
    List<String> districtIds = const [],
  }) async {
    searches.add(
      '${categoryId ?? '-'}|${keyword ?? ''}|${districtIds.join(',')}',
    );
    return [
      for (final c in [_chairs, _tent, _cutter])
        if ((keyword == null ||
                keyword.isEmpty ||
                c.name.toLowerCase().contains(keyword.toLowerCase())) &&
            (categoryId == null || categoryId == 'cat-${c.categoryName}'))
          c,
    ];
  }

  @override
  Future<RentalItemDetail> item(String id) async => RentalItemDetail(
    card: _chairs,
    priceTypeName: 'Per day',
    quantityOwned: 2000,
    description: 'White armless chairs.',
    advanceType: advanceType,
    advanceAmount: advanceAmount,
    districts: const [_ekm],
    questions: const [
      RentalItemQuestion(
        id: 'q1',
        prompt: 'Event date and venue',
        isRequired: true,
      ),
    ],
  );

  @override
  Future<RentalAvailability> availability(
    String id,
    DateTime start,
    DateTime end,
  ) async =>
      RentalAvailability(total: 2000, held: held, available: 2000 - held);

  @override
  Future<RentalOrder> book(RentalBookingInput input) async {
    booked = input;
    final amount = rentalAmount(
      'Daily',
      12,
      input.quantity,
      input.startDate,
      input.endDate,
    );
    final advance = rentalAdvance(
      advanceType,
      advanceAmount,
      input.quantity,
      amount,
    );
    // An item asking an advance waits for it, holding the pieces, as the server does.
    return _order(
      'new',
      advance > 0 ? 'AwaitingAdvance' : 'Booked',
      quantity: input.quantity,
      amount: amount,
      advanceDue: advance,
    );
  }

  @override
  Future<RentalCheckout> checkout(String orderId) async {
    payments.add('checkout:$orderId');
    return RentalCheckout(
      providerOrderId: 'order_1',
      keyId: 'rzp_test_key',
      amount: 600,
      description: 'Advance for 300 Plastic chair',
      nothingToCollect: simulated,
    );
  }

  @override
  Future<RentalOrder> pay(
    String orderId, {
    required String providerOrderId,
    required String paymentId,
    required String signature,
  }) async {
    payments.add('pay:$orderId:$providerOrderId:$paymentId:$signature');
    return _order(orderId, 'Booked', amount: 3600, advanceDue: 600, paid: 600);
  }
}

RentalOrder _order(
  String id,
  String status, {
  int quantity = 300,
  double amount = 0,
  double advanceDue = 0,
  double paid = 0,
}) => RentalOrder(
  amount: amount,
  advanceDue: advanceDue,
  paid: paid,
  balance: amount - paid,
  priceType: 'Daily',
  unitPrice: 12,
  payNowAmount: status == 'AwaitingAdvance' ? advanceDue - paid : amount - paid,
  canPayOnline: amount - paid > 0 && status != 'Cancelled',
  holdUntil: status == 'AwaitingAdvance' ? DateTime(2026, 11, 1, 15, 45) : null,
  paymentStatus: status == 'AwaitingAdvance'
      ? 'AdvanceDue'
      : amount <= 0
      ? null
      : paid >= amount
      ? 'Paid'
      : paid > 0
      ? 'AdvancePaid'
      : 'Unpaid',
  paymentStatusName: status == 'AwaitingAdvance'
      ? 'Advance due'
      : paid > 0
      ? 'Advance paid'
      : 'Unpaid',
  paymentStatusTone: 'progress',
  id: id,
  rentalItemId: 'chairs',
  itemName: 'Plastic chair',
  businessName: 'Joy Rentals',
  customerName: 'Rahul Nair',
  quantity: quantity,
  startDate: DateTime(2026, 11, 1),
  endDate: DateTime(2026, 11, 3),
  deliveryAddress: 'Kakkanad',
  districtName: 'Ernakulam',
  status: status,
  statusName: status == 'OnRent' ? 'On rent' : status,
  statusTone: 'progress',
  isOut: status == 'OnRent',
  source: 'App',
  actions: status == 'Booked'
      ? const [
          RentalOrderAction(
            toStatus: 'Cancelled',
            label: 'Cancel order',
            confirmFirst: true,
          ),
        ]
      : const [],
  answers: const [
    RentalOrderAnswer(
      prompt: 'Event date and venue',
      answer: 'Sunday, St. Mary\'s',
    ),
  ],
);

/// The customer's own rentals and chats.
class _FakeCustomerGateway implements RentalOrdersGateway {
  final calls = <String>[];
  final list = [_order('o1', 'Booked'), _order('o2', 'OnRent', quantity: 150)];
  final chat = <BookingMessage>[
    BookingMessage(
      id: 'm1',
      bookingId: 'o1',
      senderRole: 'Business',
      isMine: false,
      senderName: 'Joy Rentals',
      body: 'We deliver at 8:30.',
      sentAt: DateTime(2026, 10, 30, 9),
    ),
  ];

  @override
  Future<List<RentalOrder>> orders({String? status}) async => [...list];

  @override
  Future<RentalOrder> order(String id) async =>
      list.firstWhere((o) => o.id == id);

  @override
  Future<List<RentalOrderEvent>> history(String id) async => [
    RentalOrderEvent(
      id: 'h1',
      at: DateTime(2026, 10, 29, 10, 5),
      title: 'Booked by customer',
      tone: 'progress',
      quantity: 300,
    ),
  ];

  @override
  Future<RentalOrder> takeStep(String id, String toStatus) async {
    calls.add('step:$id:$toStatus');
    final index = list.indexWhere((o) => o.id == id);
    list[index] = _order(id, toStatus);
    return list[index];
  }

  @override
  Future<List<RentalOrderThread>> threads() async => [
    RentalOrderThread(
      rentalOrderId: 'o1',
      customerName: 'Rahul Nair',
      businessName: 'Joy Rentals',
      itemName: 'Plastic chair',
      quantity: 300,
      lastMessage: 'We deliver at 8:30.',
      lastMessageAt: DateTime(2026, 10, 30, 9),
      lastFromCustomer: false,
      unreadCount: 1,
    ),
  ];

  @override
  Future<List<BookingMessage>> messages(String id) async => [...chat];

  @override
  Future<BookingMessage> send(String id, String body) async {
    calls.add('send:$id:$body');
    final sent = BookingMessage(
      id: 'm${chat.length + 1}',
      bookingId: id,
      senderRole: 'Customer',
      isMine: true,
      senderName: 'You',
      body: body,
      sentAt: DateTime(2026, 10, 30, 10),
    );
    chat.add(sent);
    return sent;
  }
}

class _SignedInCustomer extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthAuthenticated(
    User(
      id: 'u1',
      firstName: 'Rahul',
      lastName: 'Nair',
      role: 'Customer',
      emailConfirmed: true,
      phoneNumberConfirmed: true,
    ),
  );
}

Future<(_FakeCustomerRepository, _FakeCustomerGateway, ProviderContainer)>
_pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(400, 900),
  RentalPaymentWindow? window,
  void Function(_FakeCustomerRepository repository)? setUp,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});

  final repository = _FakeCustomerRepository();
  setUp?.call(repository);
  final gateway = _FakeCustomerGateway();
  // A scope that closes with the widget tree, so the chat polls stop before the test ends.
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(_SignedInCustomer.new),
        rentalCustomerRepositoryProvider.overrideWithValue(repository),
        rentalPaymentWindowProvider.overrideWithValue(
          window ??
              (checkout, payee) async =>
                  throw StateError('The payment window should not open here.'),
        ),
        rentalOrdersGatewayProvider(
          RentalAudience.customer,
        ).overrideWithValue(gateway),
        rentalCategoriesProvider.overrideWith(
          (ref) async => const [
            RentalCategory(id: 'cat-Furniture', name: 'Furniture'),
            RentalCategory(id: 'cat-Tents', name: 'Tents'),
            RentalCategory(id: 'cat-Tools', name: 'Tools'),
          ],
        ),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  await tester.pumpAndSettle();
  return (repository, gateway, container);
}

void main() {
  group('Rent home', () {
    testWidgets('sections come as a strip, then a grid, from the server', (
      tester,
    ) async {
      await _pump(tester, const RentalHomeTab());

      expect(find.text('Popular near you'), findsOneWidget);
      expect(find.byKey(const ValueKey('rent-strip-popular')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('rent-grid-explore')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Explore'), findsOneWidget);
      expect(find.byType(RentalItemCard), findsWidgets);
    });

    testWidgets('pulling down brings a new shuffle', (tester) async {
      final (repository, _, _) = await _pump(tester, const RentalHomeTab());
      final first = repository.seeds.last;

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(repository.seeds.last, isNot(first));
    });

    testWidgets('a card shows the rate, the place and the business', (
      tester,
    ) async {
      await _pump(tester, const RentalHomeTab());

      // Whichever card the shuffle puts first: every card carries the same three things.
      final card = find.byType(RentalItemCard).first;
      expect(
        find.descendant(of: card, matching: find.textContaining('/day')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('Joy Rentals')),
        findsOneWidget,
      );
    });

    testWidgets('words typed show matching rentals above the home', (
      tester,
    ) async {
      final (repository, _, _) = await _pump(tester, const RentalHomeTab());

      await tester.enterText(find.byKey(const ValueKey('rent-search')), 'tent');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('Matching rentals'), findsOneWidget);
      expect(repository.searches.last, startsWith('-|tent|'));
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('Matching rentals'), findsNothing);
    });

    testWidgets('a category narrows the results', (tester) async {
      final (repository, _, _) = await _pump(tester, const RentalHomeTab());

      await tester.tap(find.text('Tools').first);
      await tester.pumpAndSettle();

      expect(repository.searches.last, startsWith('cat-Tools|'));
      expect(find.text('Matching rentals'), findsOneWidget);
    });

    testWidgets(
      'the location is the app\'s one location, shared with Service',
      (tester) async {
        final (repository, _, container) = await _pump(
          tester,
          const RentalHomeTab(),
        );

        container
            .read(customerSearchFilterProvider.notifier)
            .setLocation(
              stateIds: {'s-kl'},
              districtIds: {'d-ekm'},
              primaryDistrictName: 'Ernakulam',
            );
        await tester.pumpAndSettle();

        expect(find.text('Ernakulam'), findsWidgets);
        await tester.enterText(
          find.byKey(const ValueKey('rent-search')),
          'chair',
        );
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(repository.searches.last, endsWith('|d-ekm'));
      },
    );

    testWidgets('fits a 360dp phone', (tester) async {
      await _pump(tester, const RentalHomeTab(), size: const Size(360, 740));
      expect(tester.takeException(), isNull);
    });
  });

  group('Item and booking', () {
    Future<void> openBooking(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('rent-book')));
      await tester.pumpAndSettle();
    }

    testWidgets('the item page shows rate, area and a verified business', (
      tester,
    ) async {
      await _pump(tester, const RentalItemScreen(itemId: 'chairs'));

      expect(find.text('White armless chairs.'), findsOneWidget);
      expect(find.text('Ernakulam'), findsOneWidget);
      expect(find.text('Verified business'), findsOneWidget);
      expect(find.byKey(const ValueKey('rent-book')), findsOneWidget);
    });

    testWidgets('500 when 300 are left shows "Only 300" and cannot be booked', (
      tester,
    ) async {
      final (repository, _, _) = await _pump(
        tester,
        const RentalItemScreen(itemId: 'chairs'),
      );
      await openBooking(tester);

      await tester.enterText(
        find.byKey(const ValueKey('order-quantity')),
        '500',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Only 300 available'), findsOneWidget);
      final book = find.widgetWithText(FilledButton, 'BOOK');
      await tester.ensureVisible(book);
      expect(tester.widget<FilledButton>(book).onPressed, isNull);
      expect(repository.booked, isNull);
    });

    testWidgets('the business\'s required question must be answered', (
      tester,
    ) async {
      final (repository, _, _) = await _pump(
        tester,
        const RentalItemScreen(itemId: 'chairs'),
      );
      await openBooking(tester);
      await tester.enterText(
        find.byKey(const ValueKey('booking-address')),
        'Kakkanad',
      );

      final book = find.widgetWithText(FilledButton, 'BOOK');
      await tester.ensureVisible(book);
      await tester.tap(book);
      await tester.pumpAndSettle();

      expect(find.text('Please answer this.'), findsOneWidget);
      expect(repository.booked, isNull);
    });

    testWidgets('a full booking is sent and opens My rental', (tester) async {
      final (repository, _, _) = await _pump(
        tester,
        const RentalItemScreen(itemId: 'chairs'),
      );
      await openBooking(tester);

      await tester.enterText(
        find.byKey(const ValueKey('order-quantity')),
        '300',
      );
      await tester.enterText(
        find.byKey(const ValueKey('booking-address')),
        'Kakkanad',
      );
      await tester.enterText(
        find.byKey(const ValueKey('booking-answer-q1')),
        'Sunday, St. Mary\'s',
      );
      await tester.pumpAndSettle();
      final book = find.widgetWithText(FilledButton, 'BOOK');
      await tester.ensureVisible(book);
      await tester.tap(book);
      await tester.pumpAndSettle();

      expect(repository.booked!.quantity, 300);
      expect(
        repository.booked!.districtId,
        'd-ekm',
        reason: 'the only district',
      );
      expect(repository.booked!.answers['q1'], 'Sunday, St. Mary\'s');
      expect(find.byType(RentalOrderDetailScreen), findsOneWidget);
      expect(find.text('My rental'), findsOneWidget);
    });
  });

  group('My rents', () {
    testWidgets('Rentals and Messages, with the business named', (
      tester,
    ) async {
      await _pump(
        tester,
        const RentOrdersTabs(audience: RentalAudience.customer),
      );

      expect(find.widgetWithText(Tab, 'Rentals'), findsOneWidget);
      expect(find.text('Status management'), findsNothing);
      expect(find.text('Offline order'), findsNothing);
      expect(find.text('Joy Rentals'), findsNWidgets(2));
    });

    testWidgets('a rental shows its total, history and answers', (
      tester,
    ) async {
      await _pump(
        tester,
        const RentOrdersTabs(audience: RentalAudience.customer),
      );

      await tester.tap(find.text('Joy Rentals').first);
      await tester.pumpAndSettle();

      expect(find.text('My rental'), findsOneWidget);
      expect(find.text('Rented from'), findsOneWidget);
      expect(find.text('Booked by customer · 300'), findsOneWidget);
      expect(find.text('Event date and venue'), findsOneWidget);
      expect(find.text('Add more pieces'), findsNothing);
    });

    testWidgets('a booked rental can be cancelled, after asking', (
      tester,
    ) async {
      final (_, gateway, _) = await _pump(
        tester,
        const RentOrdersTabs(audience: RentalAudience.customer),
      );
      await tester.tap(find.text('Joy Rentals').first);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Cancel order'));
      await tester.tap(find.text('Cancel order'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel order'));
      await tester.pumpAndSettle();

      expect(gateway.calls, ['step:o1:Cancelled']);
    });

    testWidgets('an unread reply is counted, and the customer answers', (
      tester,
    ) async {
      final (_, gateway, _) = await _pump(
        tester,
        const RentOrdersTabs(audience: RentalAudience.customer),
      );
      expect(
        find.descendant(
          of: find.widgetWithText(Tab, 'Messages'),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Messages'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rent-thread-o1')));
      await tester.pumpAndSettle();

      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.text('We deliver at 8:30.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Thank you');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      if (gateway.calls.isEmpty) {
        await tester.tap(find.byIcon(Icons.send_rounded).last);
        await tester.pumpAndSettle();
      }
      expect(gateway.calls, ['send:o1:Thank you']);
    });
  });

  group('Advance: paid online while booking', () {
    void perChairAdvance(_FakeCustomerRepository repository) => repository
      ..advanceType = RentalAdvanceType.perPiece
      ..advanceAmount = 2;

    Future<void> fillBooking(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('rent-book')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('order-quantity')),
        '300',
      );
      await tester.enterText(
        find.byKey(const ValueKey('booking-address')),
        'Kakkanad',
      );
      await tester.enterText(
        find.byKey(const ValueKey('booking-answer-q1')),
        'Sunday',
      );
      await tester.pumpAndSettle();
    }

    final payButton = find.widgetWithText(
      FilledButton,
      'BOOK & PAY ${rupees(600)}'.toUpperCase(),
    );

    testWidgets('the sheet shows the total and the advance paid now', (
      tester,
    ) async {
      await _pump(
        tester,
        const RentalItemScreen(itemId: 'chairs'),
        setUp: perChairAdvance,
      );
      await fillBooking(tester);

      // 300 chairs × ₹12 × 1 day; ₹2 a chair now.
      expect(find.text('Total ${rupees(3600)}'), findsOneWidget);
      expect(
        find.text(
          'Advance ${rupees(600)} now, online · ${rupees(3000)} before the return',
        ),
        findsOneWidget,
      );
      expect(payButton, findsOneWidget);
    });

    testWidgets('no advance says it is all paid before the return', (
      tester,
    ) async {
      await _pump(tester, const RentalItemScreen(itemId: 'chairs'));
      await fillBooking(tester);

      expect(
        find.text('Paid to Joy Rentals before the return'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'BOOK'), findsOneWidget);
    });

    testWidgets('booking opens the payment window and the server confirms it', (
      tester,
    ) async {
      final opened = <String>[];
      final (repository, _, _) = await _pump(
        tester,
        const RentalItemScreen(itemId: 'chairs'),
        setUp: perChairAdvance,
        window: (checkout, payee) async {
          opened.add('${checkout.keyId}:${checkout.providerOrderId}:$payee');
          return const RazorpayResult(
            paymentId: 'pay_1',
            orderId: 'order_1',
            signature: 'sig',
          );
        },
      );
      await fillBooking(tester);

      await tester.ensureVisible(payButton);
      await tester.tap(payButton);
      await tester.pumpAndSettle();

      expect(opened, ['rzp_test_key:order_1:Joy Rentals']);
      expect(repository.payments, [
        'checkout:new',
        'pay:new:order_1:pay_1:sig',
      ]);
      expect(find.textContaining('booking confirmed'), findsOneWidget);
      expect(find.byType(RentalOrderDetailScreen), findsOneWidget);
    });

    testWidgets('closing the window charges nothing and keeps the booking', (
      tester,
    ) async {
      final (repository, _, _) = await _pump(
        tester,
        const RentalItemScreen(itemId: 'chairs'),
        setUp: perChairAdvance,
        window: (checkout, payee) async => throw const RazorpayCancelled(),
      );
      await fillBooking(tester);

      await tester.ensureVisible(payButton);
      await tester.tap(payButton);
      await tester.pumpAndSettle();

      expect(repository.payments, ['checkout:new']);
      expect(find.textContaining('Nothing was charged'), findsOneWidget);
      // The booking waits for its advance, with a way to pay it.
      expect(find.byKey(const ValueKey('pay-online')), findsOneWidget);
      expect(find.byKey(const ValueKey('advance-hold-note')), findsOneWidget);
    });

    testWidgets('simulated collection confirms without opening a window', (
      tester,
    ) async {
      final (repository, _, _) = await _pump(
        tester,
        const RentalItemScreen(itemId: 'chairs'),
        setUp: (r) => perChairAdvance(r..simulated = true),
      );
      await fillBooking(tester);

      await tester.ensureVisible(payButton);
      await tester.tap(payButton);
      await tester.pumpAndSettle();

      expect(repository.payments.last, 'pay:new:order_1:sim_order_1:simulated');
      expect(find.textContaining('booking confirmed'), findsOneWidget);
    });
  });

  group('Service | Rent choice', () {
    testWidgets(
      'shows two cards side by side; tapping the other one chooses it',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final chosen = <CustomerPanel>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CustomerPanelSwitch(
                value: CustomerPanel.service,
                onChanged: chosen.add,
              ),
            ),
          ),
        );

        final service = find.byKey(const ValueKey('customer-panel-service'));
        final rent = find.byKey(const ValueKey('customer-panel-rent'));
        expect(find.text('Service'), findsOneWidget);
        expect(find.text('Rent'), findsOneWidget);
        // Two separate cards with a gap between them, not one joined pill.
        expect(
          tester.getTopLeft(rent).dx - tester.getTopRight(service).dx,
          greaterThan(0),
        );

        await tester.tap(service);
        await tester.tap(rent);
        expect(chosen, [CustomerPanel.rent]);
        expect(tester.takeException(), isNull);
      },
    );

    test('is remembered on the phone', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(customerPanelChoiceProvider),
        CustomerPanel.service,
      );
      await container
          .read(customerPanelChoiceProvider.notifier)
          .choose(CustomerPanel.rent);

      final again = ProviderContainer();
      addTearDown(again.dispose);
      again.read(customerPanelChoiceProvider);
      await Future<void>.delayed(Duration.zero);
      expect(again.read(customerPanelChoiceProvider), CustomerPanel.rent);
    });
  });
}
