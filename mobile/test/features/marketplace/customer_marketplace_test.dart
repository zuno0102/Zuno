import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuno/core/payments/razorpay_checkout.dart';
import 'package:zuno/core/utils/validators.dart';
import 'package:zuno/features/auth/domain/entities/user.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/auth/presentation/providers/auth_state.dart';
import 'package:zuno/features/marketplace/data/models/marketplace_customer_models.dart';
import 'package:zuno/features/marketplace/data/models/marketplace_order_models.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_customer.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_order.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/domain/marketplace_customer_repository.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_customer_providers.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:zuno/features/marketplace/presentation/screens/customer_marketplace_home_tab.dart';
import 'package:zuno/features/marketplace/presentation/screens/customer_marketplace_order_screen.dart';
import 'package:zuno/features/marketplace/presentation/screens/customer_marketplace_orders_tab.dart';
import 'package:zuno/features/marketplace/presentation/screens/customer_marketplace_post_screen.dart';
import 'package:zuno/features/marketplace/presentation/screens/marketplace_wishlist_screen.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_account_tiles.dart';
import 'package:zuno/features/rental/presentation/providers/rental_customer_providers.dart';
import 'package:zuno/features/rental/presentation/screens/customer_app_shell.dart';
import 'package:zuno/shared/legal/legal_document.dart';
import 'package:zuno/shared/widgets/network_photo.dart';
import 'package:zuno/shared/widgets/primary_button.dart';
import 'package:zuno/shared/widgets/step_progress_bar.dart';

import 'marketplace_order_fakes.dart';

MarketplaceCard _card(
  String id, {
  String title = 'Silk saree',
  String kind = 'Listing',
  String tradeType = 'Retail',
  double? price = 2400,
  double? originalPrice,
  String? priceUnit,
  int? minOrderQuantity,
  int? quantity = 5,
  bool isFavourite = false,
  bool isAvailable = true,
  double? latitude,
  double? longitude,
}) => MarketplaceCard(
  id: id,
  kind: kind,
  title: title,
  categoryId: 'cat',
  categoryName: 'Products',
  tradeType: tradeType,
  districtName: 'Kanyakumari',
  businessName: 'Joy Silks',
  price: price,
  originalPrice: originalPrice,
  priceUnit: priceUnit,
  minOrderQuantity: minOrderQuantity,
  quantity: quantity,
  isFavourite: isFavourite,
  isAvailable: isAvailable,
  latitude: latitude,
  longitude: longitude,
  endsAt: kind == 'Listing' ? null : DateTime(2026, 11, 19, 21),
);

const _cash = MarketplaceOption(
  code: 'CashOnDelivery',
  name: 'Cash on delivery',
  detail: 'Pay the courier when it arrives.',
);
const _online = MarketplaceOption(
  code: 'Online',
  name: 'Online pay',
  detail: 'Confirmed once paid.',
);

MarketplacePostDetail _saree({
  List<MarketplaceOption> methods = const [_cash, _online],
}) => MarketplacePostDetail(
  card: _card('p1', quantity: 5),
  description: 'Kanchipuram silk.',
  canOrder: true,
  paymentMethods: methods,
  details: const [(name: 'Fabric', value: 'Silk')],
  variants: const [
    MarketplaceVariant(id: 'v-red', colour: 'Red', stock: 3),
    MarketplaceVariant(
      id: 'v-blue',
      colour: 'Blue',
      stock: 2,
      price: 2600,
      imageUrls: {0: '/blue.jpg'},
    ),
    MarketplaceVariant(id: 'v-green', colour: 'Green', stock: 0),
  ],
);

final _lot = MarketplacePostDetail(
  card: _card(
    'lot',
    title: 'Nendran banana',
    tradeType: 'Wholesale',
    price: 38,
    priceUnit: 'kg',
    minOrderQuantity: 200,
    quantity: 2000,
  ),
  canRequest: true,
);

final _biryani = MarketplacePostDetail(
  card: _card(
    'food',
    title: 'Veg biryani',
    kind: 'FoodOffer',
    price: 99,
    originalPrice: 180,
    priceUnit: 'plate',
    quantity: 8,
    latitude: 8.18,
    longitude: 77.41,
  ),
);

const _track = [
  MarketplaceTrackStep(name: 'Ordered'),
  MarketplaceTrackStep(name: 'Confirmed'),
  MarketplaceTrackStep(name: 'Shipped'),
  MarketplaceTrackStep(name: 'Out for delivery'),
  MarketplaceTrackStep(name: 'Delivered'),
];

/// [_track] with the first [reached] steps reached on consecutive days from 17 Nov.
List<MarketplaceTrackStep> _reached(int reached) => [
  for (var i = 0; i < _track.length; i++)
    MarketplaceTrackStep(
      name: _track[i].name,
      reachedAt: i < reached ? DateTime(2026, 11, 17 + i) : null,
    ),
];

const _cancel = [
  MarketplaceOrderAction(
    toStatus: 'Cancelled',
    name: 'Cancel order',
    needsConfirm: true,
  ),
];

/// The customer's own order, as the server words it for them.
MarketplaceOrder _mine(
  String status, {
  int reached = 1,
  String paymentMethod = 'CashOnDelivery',
  String? courierName,
  String? trackingNumber,
  String? trackingUrl,
  String? cancelledBy,
  int? ratingScore,
}) => testOrder(
  status: status,
  paymentMethod: paymentMethod,
  isPaid: paymentMethod == 'Online' && status != 'AwaitingPayment',
  sellerName: 'Joy Silks',
  courierName: courierName,
  trackingNumber: trackingNumber,
  trackingUrl: trackingUrl,
  cancelledBy: cancelledBy,
  cancelledAt: status == 'Cancelled' ? DateTime(2026, 11, 18) : null,
  ratingScore: ratingScore,
  statusName: status == 'Placed' ? 'Ordered' : null,
  track: _reached(reached),
  actions: const ['AwaitingPayment', 'Placed', 'Confirmed'].contains(status)
      ? _cancel
      : const [],
);

class _FakeRepo implements MarketplaceCustomerRepository {
  MarketplaceHome home = const MarketplaceHome();
  final Map<String, MarketplacePostDetail> posts = {};
  List<MarketplaceCard> results = const [];
  List<MarketplaceCard> wishlist = const [];
  final Map<String, MarketplaceOrder> orders = {};
  List<MarketplaceStatusCount> counts = const [];
  List<MarketplaceB2BRequest> requests = const [];
  bool favouriteFails = false;

  final saved = <String, bool>{};
  final searched = <String?>[];
  final searchedCategories = <String?>[];
  final placed = <MarketplaceOrderInput>[];
  final cancelled = <String>[];
  final reviews = <(String, int, String?)>[];
  final asked = <(String, int, String?)>[];
  final confirmed = <String>[];

  @override
  Future<MarketplaceHome> getHome({List<String>? districtIds}) async => home;

  @override
  Future<MarketplaceCardPage> search({
    String? kind,
    bool? wholesale,
    String? categoryId,
    String? keyword,
    List<String>? districtIds,
    int page = 1,
  }) async {
    searched.add(keyword);
    searchedCategories.add(categoryId);
    return MarketplaceCardPage(items: results, totalCount: results.length);
  }

  @override
  Future<MarketplacePostDetail> getPost(String id) async => posts[id]!;

  @override
  Future<MarketplaceCardPage> getFavourites({int page = 1}) async =>
      MarketplaceCardPage(items: wishlist, totalCount: wishlist.length);

  @override
  Future<void> setFavourite(String postId, {required bool saved}) async {
    if (favouriteFails) throw Exception('Your wishlist is full.');
    this.saved[postId] = saved;
  }

  @override
  Future<MarketplaceOrderPage> getMyOrders({String? status}) async {
    final items = orders.values
        .where((o) => status == null || o.status == status)
        .toList();
    return MarketplaceOrderPage(
      items: items,
      totalCount: items.length,
      counts: counts,
    );
  }

  @override
  Future<MarketplaceOrder> getMyOrder(String id) async => orders[id]!;

  @override
  Future<MarketplaceOrder> placeOrder(MarketplaceOrderInput input) async {
    placed.add(input);
    final order = _mine(
      input.paymentMethod == 'Online' ? 'AwaitingPayment' : 'Placed',
      paymentMethod: input.paymentMethod,
    );
    orders[order.id] = order;
    return order;
  }

  @override
  Future<MarketplaceCheckout> startPayment(String orderId) async =>
      const MarketplaceCheckout(
        providerOrderId: 'order_1',
        keyId: 'rzp_test',
        amount: 4800,
        description: '2 × Silk saree',
      );

  @override
  Future<MarketplaceOrder> confirmPayment(
    String orderId, {
    required String providerOrderId,
    required String paymentId,
    required String signature,
  }) async {
    confirmed.add(paymentId);
    final paid = _mine('Confirmed', reached: 2, paymentMethod: 'Online');
    orders[orderId] = paid;
    return paid;
  }

  @override
  Future<MarketplaceOrder> cancel(String orderId) async {
    cancelled.add(orderId);
    final done = _mine('Cancelled', reached: 2, cancelledBy: 'Customer');
    orders[orderId] = done;
    return done;
  }

  @override
  Future<MarketplaceOrder> review(
    String orderId,
    int score,
    String? comment,
  ) async {
    reviews.add((orderId, score, comment));
    final closed = _mine('Closed', reached: 5, ratingScore: score);
    orders[orderId] = closed;
    return closed;
  }

  @override
  Future<MarketplaceB2BRequestPage> getMyRequests() async =>
      MarketplaceB2BRequestPage(items: requests, totalCount: requests.length);

  @override
  Future<MarketplaceB2BRequest> askForLot(
    String postId,
    int quantity,
    String? message,
  ) async {
    asked.add((postId, quantity, message));
    return testRequest();
  }
}

class _SignedIn extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthAuthenticated(
    User(
      id: 'u1',
      firstName: 'Priya',
      lastName: 'Buyer',
      role: 'Customer',
      emailConfirmed: true,
      phoneNumberConfirmed: true,
      phoneNumber: '9711166533',
    ),
  );
}

Future<_FakeRepo> _pump(
  WidgetTester tester,
  Widget child, {
  _FakeRepo? repo,
  MarketplacePaymentWindow? window,
  List<MarketplaceCategory> categories = const [],
}) async {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final fake = repo ?? _FakeRepo();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(_SignedIn.new),
        marketplaceCustomerRepositoryProvider.overrideWithValue(fake),
        marketplaceCategoriesProvider.overrideWith((ref) async => categories),
        marketplacePaymentWindowProvider.overrideWithValue(
          window ??
              (checkout, payee) async =>
                  throw StateError('The payment window should not open.'),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

/// Scrolls [key] into view, then taps it — sheets run longer than the test screen.
Future<void> _tapVisible(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
}

void main() {
  group('Marketplace home', () {
    testWidgets('banners, food near you, products and B2B lots', (
      tester,
    ) async {
      final repo = _FakeRepo()
        ..home = MarketplaceHome(
          banners: [_card('ad', title: 'Aadi sale', kind: 'Advertisement')],
          food: [_biryani.card],
          products: [_card('p1')],
          wholesale: [_lot.card],
        );
      await _pump(tester, const CustomerMarketplaceHomeTab(), repo: repo);

      expect(find.byKey(const ValueKey('marketplace-banners')), findsOneWidget);
      expect(find.text('Aadi sale'), findsOneWidget);
      expect(find.text('Food offers near you'), findsOneWidget);
      expect(
        find.textContaining('₹99 / plate', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Products'), findsOneWidget);
      expect(find.byKey(const ValueKey('marketplace-card-p1')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('marketplace-b2b-strip')),
        200,
        // The page itself, not the sideways strips and banners inside it.
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('B2B · smallest order 200 kg'), findsOneWidget);
    });

    testWidgets('an empty home says so', (tester) async {
      await _pump(tester, const CustomerMarketplaceHomeTab());
      expect(find.text('Nothing here yet'), findsOneWidget);
    });

    testWidgets('search shows matches, and Clear goes back home', (
      tester,
    ) async {
      final repo = _FakeRepo()
        ..home = MarketplaceHome(products: [_card('p1')])
        ..results = [_card('p2', title: 'Cotton kurta')];
      await _pump(tester, const CustomerMarketplaceHomeTab(), repo: repo);

      await tester.enterText(
        find.byKey(const ValueKey('marketplace-search')),
        '  kurta ',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(repo.searched, ['kurta']);
      expect(find.text('Matching'), findsOneWidget);
      expect(find.text('Cotton kurta'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('Matching'), findsNothing);
      expect(find.byKey(const ValueKey('marketplace-card-p1')), findsOneWidget);
    });
  });

  testWidgets('category squares, as on Service and Rent, narrow the home', (
    tester,
  ) async {
    final repo = _FakeRepo()
      ..home = MarketplaceHome(products: [_card('p1')])
      ..results = [_card('p1')];
    await _pump(
      tester,
      const CustomerMarketplaceHomeTab(),
      repo: repo,
      categories: const [
        MarketplaceCategory(
          id: 'food',
          name: 'Nearby food',
          shortName: 'Food',
          slug: 'nearby-food',
          kind: 'FoodOffer',
          tradeMode: 'RetailOnly',
          displayOrder: 3,
          isActive: true,
          subCategories: [],
          fields: [],
          iconName: 'restaurant_outlined',
        ),
      ],
    );

    expect(
      find.byKey(const ValueKey('marketplace-categories')),
      findsOneWidget,
    );
    expect(
      find.byType(ChoiceChip),
      findsNothing,
      reason: 'no plain chips any more',
    );

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    expect(repo.searchedCategories, ['food']);
    expect(find.text('Matching'), findsOneWidget);

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    expect(
      find.text('Matching'),
      findsNothing,
      reason: 'tapping it again clears it',
    );
  });

  group('Wishlist heart', () {
    testWidgets('saves and un-saves at once', (tester) async {
      final repo = _FakeRepo()..home = MarketplaceHome(products: [_card('p1')]);
      await _pump(tester, const CustomerMarketplaceHomeTab(), repo: repo);
      final heart = find.byKey(const ValueKey('marketplace-heart-p1'));

      await tester.tap(heart);
      await tester.pumpAndSettle();
      expect(repo.saved['p1'], isTrue);
      expect(
        find.descendant(
          of: heart,
          matching: find.byIcon(Icons.favorite_rounded),
        ),
        findsOneWidget,
      );

      await tester.tap(heart);
      await tester.pumpAndSettle();
      expect(repo.saved['p1'], isFalse);
      expect(
        find.descendant(
          of: heart,
          matching: find.byIcon(Icons.favorite_border_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('goes back with the reason when the server refuses', (
      tester,
    ) async {
      final repo = _FakeRepo()
        ..home = MarketplaceHome(products: [_card('p1')])
        ..favouriteFails = true;
      await _pump(tester, const CustomerMarketplaceHomeTab(), repo: repo);

      await tester.tap(find.byKey(const ValueKey('marketplace-heart-p1')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Your wishlist is full.'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    });

    testWidgets('the wishlist greys out a post no longer on sale', (
      tester,
    ) async {
      final repo = _FakeRepo()
        ..wishlist = [
          _card('p1', isFavourite: true),
          _card(
            'gone',
            title: 'Used scooter',
            isFavourite: true,
            isAvailable: false,
          ),
        ];
      await _pump(tester, const MarketplaceWishlistScreen(), repo: repo);

      expect(find.text('Not available'), findsOneWidget);
      await tester.tap(find.text('Used scooter'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No longer on sale'), findsOneWidget);
    });

    testWidgets('an empty wishlist says how to fill it', (tester) async {
      await _pump(tester, const MarketplaceWishlistScreen());
      expect(find.text('Nothing saved yet'), findsOneWidget);
    });
  });

  group('A product and Buy now', () {
    testWidgets('colours show what is left; a sold-out one cannot be picked', (
      tester,
    ) async {
      final repo = _FakeRepo()..posts['p1'] = _saree();
      await _pump(
        tester,
        CustomerMarketplacePostScreen(preview: _card('p1')),
        repo: repo,
      );

      expect(find.text('Red · 3 left'), findsOneWidget);
      expect(find.text('Green · sold out'), findsOneWidget);
      final green = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey('marketplace-variant-v-green')),
      );
      expect(green.onSelected, isNull);
      expect(find.text('Fabric'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('marketplace-variant-v-blue')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<NetworkPhoto>(find.byType(NetworkPhoto))
            .any((w) => w.url?.endsWith('/blue.jpg') ?? false),
        isTrue,
        reason: 'the colour chosen shows in its own photo',
      );
      expect(
        find.text('₹2,600'),
        findsNWidgets(2),
        reason: 'the colour\'s own price',
      );
    });

    testWidgets('the sheet checks every field, then places a cash order', (
      tester,
    ) async {
      final repo = _FakeRepo()..posts['p1'] = _saree();
      await _pump(
        tester,
        CustomerMarketplacePostScreen(preview: _card('p1')),
        repo: repo,
      );

      await tester.tap(find.byKey(const ValueKey('marketplace-buy-now')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('marketplace-order-quantity')),
        '9',
      );
      await tester.enterText(
        find.byKey(const ValueKey('marketplace-order-pincode')),
        '0123',
      );
      await _tapVisible(tester, const ValueKey('marketplace-order-place'));
      await tester.pumpAndSettle();

      expect(find.text('Only 3 left. Order 3 or fewer.'), findsOneWidget);
      expect(find.text('Enter the delivery address.'), findsOneWidget);
      expect(
        find.text('Enter the 6-digit pincode, like 629001.'),
        findsOneWidget,
      );
      expect(repo.placed, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('marketplace-order-quantity')),
        '2',
      );
      await tester.enterText(
        find.byKey(const ValueKey('marketplace-order-address')),
        '12, North Street, Nagercoil',
      );
      await tester.enterText(
        find.byKey(const ValueKey('marketplace-order-pincode')),
        '629001',
      );
      await tester.pumpAndSettle();
      expect(find.text('₹4,800'), findsOneWidget);
      await _tapVisible(tester, const ValueKey('marketplace-order-place'));
      await tester.pumpAndSettle();

      final input = repo.placed.single;
      expect(input.variantId, 'v-red');
      expect(input.quantity, 2);
      expect(input.paymentMethod, 'CashOnDelivery');
      expect(input.phone, '9711166533', reason: "the account's own number");
      expect(input.pincode, '629001');
      // Then the order's own page opens, with where it is.
      expect(find.byType(CustomerMarketplaceOrderScreen), findsOneWidget);
      expect(find.byType(StepProgressBar), findsOneWidget);
    });

    testWidgets('an online order opens the payment window and confirms', (
      tester,
    ) async {
      final repo = _FakeRepo()..posts['p1'] = _saree();
      var opened = 0;
      await _pump(
        tester,
        CustomerMarketplacePostScreen(preview: _card('p1')),
        repo: repo,
        window: (checkout, payee) async {
          opened++;
          return RazorpayResult(
            paymentId: 'pay_1',
            orderId: checkout.providerOrderId,
            signature: 'sig',
          );
        },
      );

      await tester.tap(find.byKey(const ValueKey('marketplace-buy-now')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Online pay'));
      await tester.enterText(
        find.byKey(const ValueKey('marketplace-order-address')),
        '12, North Street',
      );
      await tester.enterText(
        find.byKey(const ValueKey('marketplace-order-pincode')),
        '629001',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PrimaryButton>(
              find.byKey(const ValueKey('marketplace-order-place')),
            )
            .label,
        'Place order and pay',
      );
      await _tapVisible(tester, const ValueKey('marketplace-order-place'));
      await tester.pumpAndSettle();

      expect(repo.placed.single.paymentMethod, 'Online');
      expect(opened, 1);
      expect(repo.confirmed, ['pay_1']);
      expect(find.textContaining('order confirmed'), findsOneWidget);
    });

    testWidgets('a closed payment window says the order may still confirm', (
      tester,
    ) async {
      final repo = _FakeRepo()..posts['p1'] = _saree(methods: const [_online]);
      await _pump(
        tester,
        CustomerMarketplacePostScreen(preview: _card('p1')),
        repo: repo,
        window: (checkout, payee) async => throw const RazorpayCancelled(),
      );

      await tester.tap(find.byKey(const ValueKey('marketplace-buy-now')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('marketplace-order-address')),
        '12, North Street',
      );
      await tester.enterText(
        find.byKey(const ValueKey('marketplace-order-pincode')),
        '629001',
      );
      await _tapVisible(tester, const ValueKey('marketplace-order-place'));
      await tester.pumpAndSettle();

      expect(repo.confirmed, isEmpty);
      expect(find.textContaining('confirmed by itself'), findsOneWidget);
    });

    testWidgets('a seller taking no payment now cannot be ordered from', (
      tester,
    ) async {
      final repo = _FakeRepo()..posts['p1'] = _saree(methods: const []);
      await _pump(
        tester,
        CustomerMarketplacePostScreen(preview: _card('p1')),
        repo: repo,
      );

      final buy = tester.widget<ButtonStyleButton>(
        find.byKey(const ValueKey('marketplace-buy-now')),
      );
      expect(buy.onPressed, isNull);
    });
  });

  group('Food offers and B2B lots', () {
    testWidgets('a food offer shows where to go, and nothing to order', (
      tester,
    ) async {
      final repo = _FakeRepo()..posts['food'] = _biryani;
      await _pump(
        tester,
        CustomerMarketplacePostScreen(preview: _biryani.card),
        repo: repo,
      );

      expect(
        find.byKey(const ValueKey('marketplace-post-place')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('marketplace-buy-now')), findsNothing);
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('a lot is asked for with at least its smallest order', (
      tester,
    ) async {
      final repo = _FakeRepo()..posts['lot'] = _lot;
      await _pump(
        tester,
        CustomerMarketplacePostScreen(preview: _lot.card),
        repo: repo,
      );

      await tester.tap(find.byKey(const ValueKey('marketplace-request-lot')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('marketplace-lot-quantity')),
        '150',
      );
      await _tapVisible(tester, const ValueKey('marketplace-lot-send'));
      await tester.pumpAndSettle();
      expect(find.text('The smallest order is 200 kg.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('marketplace-lot-quantity')),
        '3000',
      );
      await tester.pumpAndSettle();
      expect(find.text('Only 2000 kg available.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('marketplace-lot-quantity')),
        '500',
      );
      await tester.enterText(
        find.byKey(const ValueKey('marketplace-lot-message')),
        'Weekly supply',
      );
      await tester.pumpAndSettle();
      expect(find.text('500 kg × ₹38 = ₹19,000'), findsOneWidget);
      await _tapVisible(tester, const ValueKey('marketplace-lot-send'));
      await tester.pumpAndSettle();

      expect(repo.asked.single, ('lot', 500, 'Weekly supply'));
      expect(find.textContaining('Request sent to Joy Silks'), findsOneWidget);
    });
  });

  group('My order and its progress bar', () {
    Future<_FakeRepo> open(WidgetTester tester, MarketplaceOrder order) {
      final repo = _FakeRepo()..orders[order.id] = order;
      return _pump(
        tester,
        CustomerMarketplaceOrderScreen(orderId: order.id),
        repo: repo,
      );
    }

    testWidgets('confirmed: two steps done, and Cancel before it ships', (
      tester,
    ) async {
      final repo = await open(tester, _mine('Confirmed', reached: 2));

      final bar = tester.widget<StepProgressBar>(find.byType(StepProgressBar));
      expect(bar.reached, 1);
      expect(bar.stoppedAt, isNull);
      expect(find.text('17 Nov'), findsOneWidget);
      expect(find.text('Joy Silks is packing it.'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('marketplace-my-order-cancel')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel order').last);
      await tester.pumpAndSettle();

      expect(repo.cancelled, ['o-1']);
      final cancelled = tester.widget<StepProgressBar>(
        find.byType(StepProgressBar),
      );
      expect(cancelled.stoppedAt, 2, reason: 'it stopped after Confirmed');
      expect(find.text('You cancelled it before it shipped.'), findsOneWidget);
    });

    testWidgets('keeping the order changes nothing', (tester) async {
      final repo = await open(tester, _mine('Placed'));
      await tester.tap(
        find.byKey(const ValueKey('marketplace-my-order-cancel')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();
      expect(repo.cancelled, isEmpty);
    });

    testWidgets('shipped: no Cancel, the courier and Track', (tester) async {
      await open(
        tester,
        _mine(
          'OutForDelivery',
          reached: 4,
          courierName: 'Delhivery',
          trackingNumber: '149021',
          trackingUrl: 'https://www.delhivery.com/track/package/149021',
        ),
      );

      expect(
        find.byKey(const ValueKey('marketplace-my-order-cancel')),
        findsNothing,
      );
      expect(find.text('Delhivery · 149021'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('marketplace-my-order-track')),
        findsOneWidget,
      );
      expect(
        tester.widget<StepProgressBar>(find.byType(StepProgressBar)).reached,
        3,
      );
    });

    testWidgets('delivered: Rate this order closes it with the stars', (
      tester,
    ) async {
      final repo = await open(tester, _mine('Delivered', reached: 5));

      await tester.tap(find.byKey(const ValueKey('marketplace-my-order-rate')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.star_border_rounded).at(3));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(repo.reviews.single.$2, 4);
      expect(
        find.byKey(const ValueKey('marketplace-my-order-rate')),
        findsNothing,
      );
      expect(find.text('4 of 5'), findsOneWidget);
    });

    testWidgets('awaiting payment: Pay opens the payment window', (
      tester,
    ) async {
      final order = _mine('AwaitingPayment', paymentMethod: 'Online');
      final repo = _FakeRepo()..orders[order.id] = order;
      await _pump(
        tester,
        CustomerMarketplaceOrderScreen(orderId: order.id),
        repo: repo,
        window: (checkout, payee) async => RazorpayResult(
          paymentId: 'pay_9',
          orderId: checkout.providerOrderId,
          signature: 'sig',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('marketplace-my-order-pay')));
      await tester.pumpAndSettle();
      expect(repo.confirmed, ['pay_9']);
    });
  });

  test('a cancelled order ends in a red stop after its last step', () {
    final track = marketplaceTrack(
      _mine('Cancelled', reached: 2, cancelledBy: 'Customer'),
    );
    expect(track.reached, 1);
    expect(track.stoppedAt, 2);
    expect(track.stops[2].label, 'Cancelled');
    expect(track.stops[2].caption, '18 Nov');
    expect(track.stops.length, 5);

    final live = marketplaceTrack(_mine('Shipped', reached: 3));
    expect(live.stoppedAt, isNull);
    expect(live.stops.map((s) => s.label), [
      'Ordered',
      'Confirmed',
      'Shipped',
      'Out for delivery',
      'Delivered',
    ]);
  });

  group('My orders tab', () {
    testWidgets(
      'chips are the customer\'s own statuses; cards name the seller',
      (tester) async {
        final placed = _mine('Placed');
        final repo = _FakeRepo()
          ..orders[placed.id] = placed
          ..counts = const [
            MarketplaceStatusCount(
              status: 'Placed',
              count: 1,
              name: 'Ordered',
              tone: 'danger',
            ),
          ];
        await _pump(tester, const CustomerMarketplaceOrdersTab(), repo: repo);

        expect(
          find.byKey(const ValueKey('my-marketplace-chip-Placed')),
          findsOneWidget,
        );
        expect(find.text('Ordered 1'), findsOneWidget);
        expect(find.text('Joy Silks'), findsOneWidget);
        expect(
          find.text('Priya S'),
          findsNothing,
          reason: 'not the business view',
        );
        expect(find.byTooltip('Call customer'), findsNothing);
        expect(find.text('Waiting for Joy Silks to confirm.'), findsOneWidget);
      },
    );

    testWidgets('B2B requests: accepted without a plan holds the number back', (
      tester,
    ) async {
      final repo = _FakeRepo()
        ..requests = [
          MarketplaceB2BRequest(
            id: 'r-1',
            number: 'R1',
            postId: 'lot',
            title: 'Nendran banana',
            quantity: 500,
            unit: 'kg',
            status: 'Accepted',
            statusName: 'Accepted',
            statusTone: 'success',
            buyerName: 'Priya Buyer',
            sellerName: 'Kanya Farms',
            contactNeedsPlan: true,
            createdDate: DateTime(2026, 11, 18),
          ),
        ];
      await _pump(tester, const CustomerMarketplaceOrdersTab(), repo: repo);
      await tester.tap(find.byKey(const ValueKey('my-marketplace-tab-b2b')));
      await tester.pumpAndSettle();

      expect(find.text('Kanya Farms'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('marketplace-b2b-plan-note-r-1')),
        findsOneWidget,
      );
      expect(find.text('Accept'), findsNothing);
    });
  });

  group('Account tiles', () {
    testWidgets('Orders, Wishlist, Coupons and Help Center', (tester) async {
      var orders = 0;
      await _pump(tester, MarketplaceAccountTiles(onOrders: () => orders++));
      for (final label in ['Orders', 'Wishlist', 'Coupons', 'Help Center']) {
        expect(find.text(label), findsOneWidget);
      }

      await tester.tap(find.text('Orders'));
      expect(orders, 1);

      await tester.tap(find.text('Coupons'));
      await tester.pumpAndSettle();
      expect(find.text('No coupons yet'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Help Center'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LegalDocumentScreen>(find.byType(LegalDocumentScreen))
            .doc,
        LegalDoc.help,
      );
    });
  });

  testWidgets('the top switch offers Marketplace as a third door', (
    tester,
  ) async {
    CustomerPanel? chosen;
    await _pump(
      tester,
      CustomerPanelSwitch(
        value: CustomerPanel.service,
        onChanged: (p) => chosen = p,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('customer-panel-marketplace')));
    expect(chosen, CustomerPanel.marketplace);
  });

  test('pincodes are six digits, not starting with 0', () {
    expect(Validators.pincode('629001'), isNull);
    expect(Validators.pincode(' 629001 '), isNull);
    expect(Validators.pincode(''), 'Enter the pincode.');
    expect(Validators.pincode('029001'), isNotNull);
    expect(Validators.pincode('62900'), isNotNull);
    expect(Validators.pincode('6290011'), isNotNull);
  });

  test('the server\'s card, post and order read as the app needs them', () {
    final detail = MarketplacePostDetailModel.fromJson({
      'card': {
        'id': 'p1',
        'kind': 'Listing',
        'title': 'Silk saree',
        'categoryId': 'c',
        'categoryName': 'Products',
        'tradeType': 'Retail',
        'districtName': 'Kanyakumari',
        'businessName': 'Joy Silks',
        'price': 2400,
        'isFavourite': true,
      },
      'details': [
        {'name': 'Fabric', 'value': 'Silk'},
      ],
      'variants': [
        {'id': 'v1', 'colour': 'Red', 'stock': 3},
      ],
      'media': [
        {'url': '/b.jpg', 'sortOrder': 1},
        {'url': '/a.jpg', 'sortOrder': 0},
      ],
      'paymentMethods': [
        {'code': 'CashOnDelivery', 'name': 'Cash on delivery'},
      ],
      'canOrder': true,
      'deliversEverywhere': false,
      'deliveryStateName': 'Tamil Nadu',
    }).toEntity();
    expect(detail.card.isFavourite, isTrue);
    expect(detail.media, ['/a.jpg', '/b.jpg']);
    expect(detail.details.single.name, 'Fabric');
    expect(detail.deliversTo, 'All of Tamil Nadu');

    final order = MarketplaceOrderModel.fromJson({
      'id': 'o1',
      'number': 'O1',
      'postId': 'p1',
      'title': 'Silk saree',
      'quantity': 1,
      'unitPrice': 2400,
      'amount': 2400,
      'paymentMethod': 'CashOnDelivery',
      'paymentMethodName': 'Cash on delivery',
      'isPaid': false,
      'status': 'Placed',
      'statusName': 'Ordered',
      'statusTone': 'danger',
      'customerName': 'Priya',
      'customerPhone': '9711166533',
      'deliveryAddress': '12, North Street',
      'pincode': '629001',
      'createdDate': '2026-11-18T10:40:00Z',
      'sellerName': 'Joy Silks',
      'track': [
        {'code': 1, 'name': 'Ordered', 'reachedAt': '2026-11-18T10:40:00Z'},
        {'code': 2, 'name': 'Confirmed', 'reachedAt': null},
      ],
    }).toEntity();
    expect(order.sellerName, 'Joy Silks');
    expect(order.track.first.reachedAt, isNotNull);
    expect(order.track.last.reachedAt, isNull);
  });
}
