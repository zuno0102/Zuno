import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/error/app_exceptions.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/business_owner/domain/entities/business_service.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_services_notifier.dart';
import 'package:zuno/features/catalog/domain/entities/app_options.dart';
import 'package:zuno/features/catalog/domain/entities/district.dart';
import 'package:zuno/features/catalog/domain/entities/location_state.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/domain/marketplace_repository.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:zuno/features/marketplace/presentation/screens/admin_marketplace_categories_screen.dart';
import 'package:zuno/features/marketplace/presentation/screens/business_marketplace_tab.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_dashboard_tiles.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_post_form_sheet.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_post_lines.dart';
import 'package:zuno/features/rental/presentation/screens/business_catalog_tab.dart';
import 'package:zuno/shared/widgets/stat_tile.dart';

const _vehicles = MarketplaceCategory(
  id: 'cat-vehicles',
  name: 'Vehicles',
  slug: 'vehicles',
  kind: MarketplacePostKind.listing,
  allowsWholesale: false,
  displayOrder: 1,
  isActive: true,
  fields: [
    MarketplaceCategoryField(
      id: 'f-km',
      key: 'km_driven',
      label: 'KM driven',
      fieldType: MarketplaceFieldType.number,
      options: [],
      unit: 'km',
      isRequired: true,
      displayOrder: 2,
      isActive: true,
    ),
    MarketplaceCategoryField(
      id: 'f-fuel',
      key: 'fuel',
      label: 'Fuel',
      fieldType: MarketplaceFieldType.select,
      options: ['Petrol', 'Diesel'],
      isRequired: true,
      displayOrder: 3,
      isActive: true,
    ),
    MarketplaceCategoryField(
      id: 'f-year',
      key: 'model_year',
      label: 'Model year',
      fieldType: MarketplaceFieldType.number,
      options: [],
      isRequired: true,
      displayOrder: 1,
      isActive: true,
    ),
  ],
);

const _farm = MarketplaceCategory(
  id: 'cat-farm',
  name: 'Farm & Wholesale',
  slug: 'farm-wholesale',
  kind: MarketplacePostKind.listing,
  allowsWholesale: true,
  displayOrder: 4,
  isActive: true,
  fields: [],
);

const _food = MarketplaceCategory(
  id: 'cat-food',
  name: 'Food offers',
  slug: 'food-offers',
  kind: MarketplacePostKind.foodOffer,
  allowsWholesale: false,
  displayOrder: 5,
  isActive: true,
  fields: [],
);

const _ads = MarketplaceCategory(
  id: 'cat-ads',
  name: 'Events & Sales',
  slug: 'events-sales',
  kind: MarketplacePostKind.advertisement,
  allowsWholesale: false,
  displayOrder: 6,
  isActive: true,
  fields: [],
);

const _options = MarketplaceOptions(
  kinds: [
    MarketplaceOption(code: 'Listing', name: 'Listing'),
    MarketplaceOption(code: 'FoodOffer', name: 'Food offer'),
    MarketplaceOption(code: 'Advertisement', name: 'Advertisement'),
  ],
  statuses: [
    MarketplaceOption(code: 'Active', name: 'Active', tone: 'success'),
    MarketplaceOption(code: 'Paused', name: 'On hold', tone: 'waiting'),
    MarketplaceOption(code: 'Expired', name: 'Expired', tone: 'danger'),
    MarketplaceOption(code: 'Closed', name: 'Closed', tone: 'progress'),
  ],
  imageSlots: 3,
  maxFoodOfferHours: 24,
  maxAdDays: 60,
);

const _kanyakumari = District(
  id: 'd-kk',
  name: 'Kanyakumari',
  stateId: 's-tn',
  stateName: 'Tamil Nadu',
);

MarketplacePlan _plan({int used = 0, int max = 1}) => MarketplacePlan(
  code: 'free',
  name: 'Free',
  price: 0,
  maxActivePosts: max,
  usedActivePosts: used,
);

MarketplacePost _post({
  String id = 'p-1',
  String title = 'Swift VXi 2019',
  String kind = MarketplacePostKind.listing,
  String status = MarketplacePostStatus.active,
  String categoryId = 'cat-vehicles',
  String categoryName = 'Vehicles',
  double? price = 420000,
  double? originalPrice,
  String? priceUnit,
  int? quantity,
  int? minOrder,
  String tradeType = MarketplaceTradeType.retail,
  DateTime? startsAt,
  DateTime? endsAt,
  Map<String, String> attributes = const {
    'model_year': '2019',
    'km_driven': '48000',
    'fuel': 'Petrol',
  },
  List<MarketplacePostAction> actions = const [
    MarketplacePostAction(
      toStatus: 'Paused',
      name: 'Pause',
      needsConfirm: false,
    ),
    MarketplacePostAction(
      toStatus: 'Closed',
      name: 'Close (sold / done)',
      needsConfirm: true,
    ),
  ],
}) => MarketplacePost(
  id: id,
  categoryId: categoryId,
  categoryName: categoryName,
  kind: kind,
  status: status,
  title: title,
  price: price,
  originalPrice: originalPrice,
  priceUnit: priceUnit,
  quantity: quantity,
  minOrderQuantity: minOrder,
  tradeType: tradeType,
  startsAt: startsAt,
  endsAt: endsAt,
  districtId: 'd-kk',
  districtName: 'Kanyakumari',
  stateId: 's-tn',
  stateName: 'Tamil Nadu',
  area: 'Marthandam',
  attributes: attributes,
  imageUrls: const {},
  actions: actions,
);

/// Answers like the Marketplace server, remembering what was sent.
class _FakeMarketplaceRepository implements MarketplaceRepository {
  _FakeMarketplaceRepository({
    this.posts = const [],
    MarketplacePlan? plan,
    this.categories = const [_vehicles, _farm, _food, _ads],
  }) : plan = plan ?? _plan(used: posts.length > 1 ? 1 : posts.length);

  List<MarketplacePost> posts;
  MarketplacePlan plan;
  List<MarketplaceCategory> categories;
  Object? failList;
  Object? failSummary;
  Object? failCreate;

  final created = <MarketplacePostInput>[];
  final updated = <(String, MarketplacePostInput)>[];
  final statusChanges = <(String, String)>[];
  final deleted = <String>[];
  final uploads = <(String, int)>[];
  final savedCategories = <MarketplaceCategoryInput>[];
  int syncs = 0;

  @override
  Future<List<MarketplaceCategory>> getCategories() async =>
      categories.where((c) => c.isActive).toList();

  @override
  Future<List<MarketplaceCategory>> getAllCategories() async => categories;

  @override
  Future<MarketplaceOptions> getOptions() async => _options;

  @override
  Future<MarketplaceSummary> getSummary() async {
    if (failSummary case final error?) throw error;
    return MarketplaceSummary(
      active: plan.usedActivePosts,
      paused: posts.where((p) => p.status == 'Paused').length,
      expired: posts.where((p) => p.status == 'Expired').length,
      closed: 0,
      plan: plan,
    );
  }

  @override
  Future<List<MarketplacePost>> getMyPosts({
    String? kind,
    String? status,
  }) async {
    if (failList case final error?) throw error;
    return posts
        .where((p) => kind == null || p.kind == kind)
        .where((p) => status == null || p.status == status)
        .toList();
  }

  @override
  Future<MarketplacePost> create(MarketplacePostInput input) async {
    if (failCreate case final error?) throw error;
    created.add(input);
    return _post(id: 'new', title: input.title);
  }

  @override
  Future<MarketplacePost> update(String id, MarketplacePostInput input) async {
    updated.add((id, input));
    return _post(id: id, title: input.title);
  }

  @override
  Future<MarketplacePost> changeStatus(String id, String status) async {
    statusChanges.add((id, status));
    return _post(id: id, status: status);
  }

  @override
  Future<void> delete(String id) async => deleted.add(id);

  @override
  Future<MarketplacePost> uploadImage(
    String id,
    int slot,
    Uint8List bytes,
  ) async {
    uploads.add((id, slot));
    return _post(id: id);
  }

  @override
  Future<MarketplacePost> removeImage(String id, int slot) async =>
      _post(id: id);

  @override
  Future<MarketplaceBusiness> syncProfile() async {
    syncs++;
    return const MarketplaceBusiness(
      name: 'shajil',
      isVerified: true,
      isKnown: true,
    );
  }

  @override
  Future<MarketplaceCategory> createCategory(
    MarketplaceCategoryInput input,
  ) async {
    savedCategories.add(input);
    return _vehicles;
  }

  @override
  Future<MarketplaceCategory> updateCategory(
    String id,
    MarketplaceCategoryInput input,
  ) async {
    savedCategories.add(input);
    return _vehicles;
  }

  @override
  Future<MarketplaceCategory> createField(
    String categoryId,
    MarketplaceFieldInput input,
  ) async => _vehicles;

  @override
  Future<MarketplaceCategory> updateField(
    String categoryId,
    String fieldId,
    MarketplaceFieldInput input,
  ) async => _vehicles;
}

class _NoServices extends BusinessServicesNotifier {
  @override
  Future<List<BusinessService>> build() async => const [];
}

Future<_FakeMarketplaceRepository> _pump(
  WidgetTester tester,
  Widget child, {
  _FakeMarketplaceRepository? repository,
}) async {
  // A tall phone, so a long form needs no scrolling to reach a field.
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final repo = repository ?? _FakeMarketplaceRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        marketplaceRepositoryProvider.overrideWithValue(repo),
        businessServicesProvider.overrideWith(_NoServices.new),
        currentAppOptionsProvider.overrideWithValue(AppOptions.defaults),
        locationStatesProvider.overrideWith(
          (ref) async => const [LocationState(id: 's-tn', name: 'Tamil Nadu')],
        ),
        districtsForStatesProvider.overrideWith(
          (ref, csv) async => const [_kanyakumari],
        ),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

/// Opens the add sheet from the Marketplace tab and picks [category].
Future<void> _openFormFor(
  WidgetTester tester,
  MarketplaceCategory category,
) async {
  await tester.tap(find.byKey(const ValueKey('marketplace-add-post')));
  await tester.pumpAndSettle();
  await _choose(tester, 'marketplace-category', category.id);
}

Future<void> _choose(WidgetTester tester, String field, String value) async {
  await tester.ensureVisible(find.byKey(ValueKey(field)));
  await tester.tap(find.byKey(ValueKey(field)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('select-option-$value')));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String field, String text) async {
  await tester.ensureVisible(find.byKey(ValueKey(field)));
  await tester.enterText(find.byKey(ValueKey(field)), text);
}

Future<void> _save(WidgetTester tester) async {
  final save = find.byKey(const ValueKey('primary-button'));
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

void main() {
  final now = DateTime(2026, 11, 11, 12);

  group('card lines', () {
    test('a listing shows its price, and a unit when it has one', () {
      expect(marketplacePriceLine(_post()), rupees(420000));
      expect(
        marketplacePriceLine(_post(price: 45, priceUnit: 'kg')),
        '${rupees(45)}/kg',
      );
      expect(marketplacePriceLine(_post(price: null)), isNull);
    });

    test('a food offer shows the usual price, then the offer', () {
      final food = _post(
        kind: MarketplacePostKind.foodOffer,
        price: 99,
        originalPrice: 180,
        priceUnit: 'plate',
      );

      expect(
        marketplacePriceLine(food),
        '${rupees(180)} → ${rupees(99)}/plate',
      );
    });

    test('quantity reads by kind: portions, or wholesale terms', () {
      expect(marketplaceQuantityLine(_post()), isNull);
      expect(
        marketplaceQuantityLine(
          _post(kind: MarketplacePostKind.foodOffer, quantity: 20),
        ),
        '20 portions',
      );
      expect(
        marketplaceQuantityLine(
          _post(
            tradeType: MarketplaceTradeType.wholesale,
            minOrder: 100,
            quantity: 2000,
            priceUnit: 'kg',
          ),
        ),
        'Wholesale · min 100 kg · 2000 kg for sale',
      );
    });

    test('a food offer runs hours on one day; an advert runs dates', () {
      final food = _post(
        kind: MarketplacePostKind.foodOffer,
        startsAt: DateTime(2026, 11, 11, 20),
        endsAt: DateTime(2026, 11, 11, 22),
      );
      final ad = _post(
        kind: MarketplacePostKind.advertisement,
        startsAt: DateTime(2026, 7, 17),
        endsAt: DateTime(2026, 8, 16, 23, 59),
      );

      expect(marketplaceWindowLine(food, now: now), 'Today 20:00 – 22:00');
      expect(marketplaceWindowLine(ad, now: now), '17 Jul – 16 Aug');
      expect(marketplaceWindowLine(_post(), now: now), isNull);
    });

    test('details follow the category order, with units', () {
      expect(
        marketplaceDetailsLine(_post(), const [_vehicles]),
        '2019 · 48000 km · Petrol',
      );
      expect(
        marketplaceDetailsLine(_post(attributes: const {}), const [_vehicles]),
        isNull,
      );
    });

    test('before the categories load, details show as they came', () {
      expect(
        marketplaceDetailsLine(_post(), const []),
        '2019 · 48000 · Petrol',
      );
    });
  });

  group('Service | Rent | Marketplace tabs', () {
    testWidgets('Marketplace is the third tab and shows the posts', (
      tester,
    ) async {
      final repo = await _pump(
        tester,
        const BusinessCatalogTab(),
        repository: _FakeMarketplaceRepository(posts: [_post()]),
      );

      expect(find.text('Service'), findsOneWidget);
      expect(find.text('Rent'), findsOneWidget);
      await tester.tap(find.text('Marketplace'));
      await tester.pumpAndSettle();

      expect(find.text('Swift VXi 2019'), findsOneWidget);
      expect(find.text('Add post'), findsOneWidget);
      expect(
        repo.syncs,
        1,
        reason: 'opening the list refreshes how customers see the business',
      );
    });
  });

  group('Marketplace list', () {
    testWidgets('a card shows category, place, price, status and details', (
      tester,
    ) async {
      await _pump(
        tester,
        const BusinessMarketplaceTab(),
        repository: _FakeMarketplaceRepository(posts: [_post()]),
      );

      expect(find.text('Vehicles · Marthandam, Kanyakumari'), findsOneWidget);
      expect(find.text(rupees(420000)), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('2019 · 48000 km · Petrol'), findsOneWidget);
    });

    testWidgets('status names come from the server table', (tester) async {
      await _pump(
        tester,
        const BusinessMarketplaceTab(),
        repository: _FakeMarketplaceRepository(
          posts: [_post(status: 'Paused', actions: const [])],
        ),
      );

      expect(find.text('On hold'), findsOneWidget);
    });

    testWidgets('empty: says what to post', (tester) async {
      await _pump(tester, const BusinessMarketplaceTab());

      expect(find.text('Nothing posted yet'), findsOneWidget);
      expect(
        find.textContaining('food offer or an advertisement'),
        findsOneWidget,
      );
    });

    testWidgets('a failed load says why and tries again', (tester) async {
      final repo = _FakeMarketplaceRepository(posts: [_post()])
        ..failList = const NetworkAppException('Marketplace is down');
      await _pump(tester, const BusinessMarketplaceTab(), repository: repo);
      expect(find.textContaining('Marketplace is down'), findsOneWidget);

      repo.failList = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Swift VXi 2019'), findsOneWidget);
    });

    testWidgets('the plan banner says how much is used', (tester) async {
      await _pump(
        tester,
        const BusinessMarketplaceTab(),
        repository: _FakeMarketplaceRepository(
          posts: [_post()],
          plan: _plan(used: 1),
        ),
      );

      expect(find.text('Free plan · 1 of 1 active post used'), findsOneWidget);
      expect(find.textContaining('Pause or close a post'), findsOneWidget);
    });

    testWidgets('kind chips count and filter the posts', (tester) async {
      await _pump(
        tester,
        const BusinessMarketplaceTab(),
        repository: _FakeMarketplaceRepository(
          posts: [
            _post(),
            _post(
              id: 'p-2',
              title: 'Veg biryani',
              kind: MarketplacePostKind.foodOffer,
              status: 'Paused',
            ),
          ],
        ),
      );

      expect(find.text('All 2'), findsOneWidget);
      expect(find.text('Food offer 1'), findsOneWidget);
      expect(find.text('Advertisement 0'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('marketplace-kind-FoodOffer')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Veg biryani'), findsOneWidget);
      expect(find.text('Swift VXi 2019'), findsNothing);
    });

    testWidgets('a full plan explains instead of opening the form', (
      tester,
    ) async {
      await _pump(
        tester,
        const BusinessMarketplaceTab(),
        repository: _FakeMarketplaceRepository(
          posts: [_post()],
          plan: _plan(used: 1),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('marketplace-add-post')));
      await tester.pumpAndSettle();

      expect(find.byType(MarketplacePostFormSheet), findsNothing);
      expect(
        find.text(
          'Your Free plan allows 1 active post. Pause or close one to put up another.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Pause is sent straight away', (tester) async {
      final repo = await _pump(
        tester,
        const BusinessMarketplaceTab(),
        repository: _FakeMarketplaceRepository(posts: [_post()]),
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();

      expect(repo.statusChanges, [('p-1', 'Paused')]);
    });

    testWidgets('Close asks first; cancelling sends nothing', (tester) async {
      final repo = await _pump(
        tester,
        const BusinessMarketplaceTab(),
        repository: _FakeMarketplaceRepository(posts: [_post()]),
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close (sold / done)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('cannot be put up again'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.statusChanges, isEmpty);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close (sold / done)'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Close (sold / done)'),
      );
      await tester.pumpAndSettle();
      expect(repo.statusChanges, [('p-1', 'Closed')]);
    });

    testWidgets('Remove asks first, then takes the post off', (tester) async {
      final repo = await _pump(
        tester,
        const BusinessMarketplaceTab(),
        repository: _FakeMarketplaceRepository(posts: [_post()]),
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(repo.deleted, ['p-1']);
    });

    testWidgets('a closed post cannot be edited', (tester) async {
      await _pump(
        tester,
        const BusinessMarketplaceTab(),
        repository: _FakeMarketplaceRepository(
          posts: [_post(status: 'Closed', actions: const [])],
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsNothing);
      expect(find.text('Remove'), findsOneWidget);
    });
  });

  group('Post form', () {
    testWidgets('a vehicle asks its own details, in the category order', (
      tester,
    ) async {
      await _pump(tester, const BusinessMarketplaceTab());
      await _openFormFor(tester, _vehicles);

      final year = tester.getTopLeft(
        find.byKey(const ValueKey('marketplace-field-model_year')),
      );
      final km = tester.getTopLeft(
        find.byKey(const ValueKey('marketplace-field-km_driven')),
      );
      expect(year.dy, lessThan(km.dy));
      expect(
        find.byKey(const ValueKey('marketplace-field-fuel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('marketplace-trade-type')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('marketplace-starts-at')), findsNothing);
    });

    testWidgets('saving empty names every missing thing and sends nothing', (
      tester,
    ) async {
      final repo = await _pump(tester, const BusinessMarketplaceTab());
      await _openFormFor(tester, _vehicles);

      await _save(tester);

      expect(find.text('Title is required.'), findsOneWidget);
      expect(find.text('KM driven is required.'), findsOneWidget);
      expect(find.text('Choose Fuel.'), findsOneWidget);
      expect(find.text('Choose the state.'), findsOneWidget);
      expect(repo.created, isEmpty);
    });

    testWidgets('a vehicle is saved with its details and district', (
      tester,
    ) async {
      final repo = await _pump(tester, const BusinessMarketplaceTab());
      await _openFormFor(tester, _vehicles);

      await _type(tester, 'marketplace-title', 'Swift VXi 2019');
      await _type(tester, 'marketplace-price', '420000');
      await _type(tester, 'marketplace-field-model_year', '2019');
      await _type(tester, 'marketplace-field-km_driven', '48000');
      await _choose(tester, 'marketplace-field-fuel', 'Petrol');
      await _choose(tester, 'marketplace-state', 's-tn');
      await _choose(tester, 'marketplace-district-s-tn', 'd-kk');
      await _save(tester);

      final input = repo.created.single;
      expect(input.categoryId, 'cat-vehicles');
      expect(input.price, 420000);
      expect(input.districtId, 'd-kk');
      expect(input.tradeType, MarketplaceTradeType.retail);
      expect(input.startsAt, isNull);
      expect(input.attributes, {
        'model_year': '2019',
        'km_driven': '48000',
        'fuel': 'Petrol',
      });
    });

    testWidgets('changing the category drops the details of the old one', (
      tester,
    ) async {
      final repo = await _pump(tester, const BusinessMarketplaceTab());
      await _openFormFor(tester, _vehicles);
      await _type(tester, 'marketplace-field-km_driven', '48000');

      await _choose(tester, 'marketplace-category', _farm.id);
      await _type(tester, 'marketplace-title', 'Nendran banana');
      await _type(tester, 'marketplace-price', '45');
      await _choose(tester, 'marketplace-state', 's-tn');
      await _choose(tester, 'marketplace-district-s-tn', 'd-kk');
      await _save(tester);

      expect(repo.created.single.attributes, isEmpty);
    });

    testWidgets(
      'wholesale only where the category allows it, and asks the smallest order',
      (tester) async {
        final repo = await _pump(tester, const BusinessMarketplaceTab());
        await _openFormFor(tester, _farm);

        await _choose(
          tester,
          'marketplace-trade-type',
          MarketplaceTradeType.wholesale,
        );
        await _type(tester, 'marketplace-title', 'Nendran banana');
        await _type(tester, 'marketplace-price', '45');
        await _type(tester, 'marketplace-price-unit', 'kg');
        await _choose(tester, 'marketplace-state', 's-tn');
        await _choose(tester, 'marketplace-district-s-tn', 'd-kk');
        await _save(tester);
        expect(find.text('Required.'), findsOneWidget);
        expect(repo.created, isEmpty);

        await _type(tester, 'marketplace-min-order', '100');
        await _save(tester);

        final input = repo.created.single;
        expect(input.tradeType, MarketplaceTradeType.wholesale);
        expect(input.minOrderQuantity, 100);
        expect(input.priceUnit, 'kg');
      },
    );

    testWidgets('a food offer asks usual and offer price, portions and hours', (
      tester,
    ) async {
      await _pump(tester, const BusinessMarketplaceTab());
      await _openFormFor(tester, _food);

      expect(
        find.byKey(const ValueKey('marketplace-original-price')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('marketplace-quantity')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('marketplace-starts-at')),
        findsOneWidget,
      );
      expect(find.textContaining('Up to 24 hours'), findsOneWidget);

      await _type(tester, 'marketplace-original-price', '180');
      await _type(tester, 'marketplace-price', '180');
      await _save(tester);

      expect(find.text('Must be less than the usual price.'), findsOneWidget);
      expect(find.text('Choose when it starts.'), findsOneWidget);
      expect(find.text('Required.'), findsOneWidget);
    });

    testWidgets('an advertisement asks dates and a phone, not a price', (
      tester,
    ) async {
      await _pump(tester, const BusinessMarketplaceTab());
      await _openFormFor(tester, _ads);

      expect(find.byKey(const ValueKey('marketplace-price')), findsNothing);
      expect(find.byKey(const ValueKey('marketplace-ends-at')), findsOneWidget);
      expect(find.textContaining('Up to 60 days'), findsOneWidget);

      await _type(tester, 'marketplace-contact-phone', '12ab');
      await _save(tester);
      expect(find.text('Enter 10 to 15 digits.'), findsOneWidget);
    });

    testWidgets('the server refusing says why, in the form', (tester) async {
      final repo = _FakeMarketplaceRepository()
        ..failCreate = const ValidationAppException(
          'One or more validation errors occurred.',
          {
            'Attributes.km_driven': ['KM driven must be a number.'],
          },
        );
      await _pump(tester, const BusinessMarketplaceTab(), repository: repo);
      await _openFormFor(tester, _farm);

      await _type(tester, 'marketplace-title', 'Nendran banana');
      await _type(tester, 'marketplace-price', '45');
      await _choose(tester, 'marketplace-state', 's-tn');
      await _choose(tester, 'marketplace-district-s-tn', 'd-kk');
      await _save(tester);

      expect(find.text('KM driven must be a number.'), findsOneWidget);
      expect(find.byType(MarketplacePostFormSheet), findsOneWidget);
    });

    testWidgets('editing starts from the saved post and updates it', (
      tester,
    ) async {
      final repo = await _pump(
        tester,
        const BusinessMarketplaceTab(),
        repository: _FakeMarketplaceRepository(posts: [_post()]),
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Edit post'), findsOneWidget);
      await _type(tester, 'marketplace-price', '400000');
      final save = find.byKey(const ValueKey('primary-button'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      final (id, input) = repo.updated.single;
      expect(id, 'p-1');
      expect(input.price, 400000);
      expect(input.districtId, 'd-kk');
      expect(input.attributes['fuel'], 'Petrol');
    });
  });

  group('Marketplace tiles on the business home screen', () {
    testWidgets('show live, paused, expired and the plan', (tester) async {
      await _pump(
        tester,
        const MarketplaceDashboardTiles(),
        repository: _FakeMarketplaceRepository(
          posts: [
            _post(),
            _post(id: 'p-2', status: 'Paused'),
          ],
          plan: _plan(used: 1),
        ),
      );

      String valueOf(String key) => tester
          .widget<StatTile>(find.byKey(ValueKey('marketplace-tile-$key')))
          .value;
      expect(valueOf('active'), '1');
      expect(valueOf('paused'), '1');
      expect(valueOf('expired'), '0');
      expect(valueOf('plan'), '1 / 1');
      expect(find.text('Free plan'), findsOneWidget);
    });

    testWidgets('a tile opens its posts', (tester) async {
      await _pump(
        tester,
        const MarketplaceDashboardTiles(),
        repository: _FakeMarketplaceRepository(
          posts: [
            _post(title: 'Live one'),
            _post(id: 'p-2', title: 'Held one', status: 'Paused'),
          ],
        ),
      );

      await tester.tap(find.byKey(const ValueKey('marketplace-tile-paused')));
      await tester.pumpAndSettle();

      expect(find.byType(MarketplacePostListScreen), findsOneWidget);
      expect(find.text('Held one'), findsOneWidget);
      expect(find.text('Live one'), findsNothing);
      expect(find.text('Add post'), findsNothing);
    });

    testWidgets(
      'a server that cannot be reached shows only this section failing',
      (tester) async {
        await _pump(
          tester,
          const MarketplaceDashboardTiles(),
          repository: _FakeMarketplaceRepository()
            ..failSummary = const NetworkAppException('Marketplace is down'),
        );

        expect(find.textContaining('Marketplace is down'), findsOneWidget);
        expect(find.byType(StatTile), findsNothing);
      },
    );
  });

  group('Super admin categories', () {
    testWidgets('lists every category, hidden ones marked', (tester) async {
      await _pump(
        tester,
        const AdminMarketplaceCategoriesScreen(),
        repository: _FakeMarketplaceRepository(
          categories: const [
            _vehicles,
            MarketplaceCategory(
              id: 'cat-old',
              name: 'Old stuff',
              slug: 'old-stuff',
              kind: MarketplacePostKind.listing,
              allowsWholesale: false,
              displayOrder: 9,
              isActive: false,
              fields: [],
            ),
          ],
        ),
      );

      expect(find.text('Vehicles'), findsOneWidget);
      expect(find.text('Listing · 3 details'), findsOneWidget);
      expect(find.text('Hidden'), findsOneWidget);
    });

    testWidgets('a new category is saved', (tester) async {
      final repo = await _pump(
        tester,
        const AdminMarketplaceCategoriesScreen(),
      );

      await tester.tap(
        find.byKey(const ValueKey('admin-marketplace-add-category')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('admin-marketplace-category-name')),
        'Mobiles',
      );
      await tester.tap(find.byKey(const ValueKey('primary-button')));
      await tester.pumpAndSettle();

      expect(repo.savedCategories.single.name, 'Mobiles');
      expect(repo.savedCategories.single.kind, MarketplacePostKind.listing);
    });

    testWidgets('a category needs a name', (tester) async {
      final repo = await _pump(
        tester,
        const AdminMarketplaceCategoriesScreen(),
      );

      await tester.tap(
        find.byKey(const ValueKey('admin-marketplace-add-category')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('primary-button')));
      await tester.pumpAndSettle();

      expect(find.text('Name is required.'), findsOneWidget);
      expect(repo.savedCategories, isEmpty);
    });
  });
}
