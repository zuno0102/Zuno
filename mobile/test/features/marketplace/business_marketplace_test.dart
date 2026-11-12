import 'dart:async';
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
import 'package:zuno/features/marketplace/presentation/screens/business_marketplace_orders_tab.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_dashboard_tiles.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_post_form_sheet.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_post_lines.dart';
import 'package:zuno/features/rental/presentation/screens/business_catalog_tab.dart';
import 'package:zuno/shared/widgets/stat_tile.dart';

const _products = MarketplaceCategory(
  id: 'cat-products',
  tracksStock: true,
  name: 'Products',
  shortName: 'Products',
  description: 'Sarees, shirts, toys',
  slug: 'products',
  iconName: 'shopping_bag_outlined',
  kind: MarketplacePostKind.listing,
  tradeMode: MarketplaceTradeMode.retailOnly,
  displayOrder: 1,
  isActive: true,
  subCategories: [
    MarketplaceSubCategory(
      id: 's-sarees',
      name: 'Sarees',
      slug: 'sarees',
      displayOrder: 1,
      isActive: true,
    ),
    MarketplaceSubCategory(
      id: 's-vehicles',
      name: 'Vehicles',
      slug: 'vehicles',
      displayOrder: 2,
      isActive: true,
    ),
  ],
  fields: [
    MarketplaceCategoryField(
      id: 'f-condition',
      key: 'condition',
      label: 'Condition',
      fieldType: MarketplaceFieldType.select,
      options: ['New', 'Used'],
      isRequired: false,
      displayOrder: 1,
      isActive: true,
    ),
    MarketplaceCategoryField(
      id: 'f-km',
      subCategoryId: 's-vehicles',
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
      subCategoryId: 's-vehicles',
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
      subCategoryId: 's-vehicles',
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

const _b2b = MarketplaceCategory(
  id: 'cat-b2b',
  name: 'B2B Wholesale',
  shortName: 'B2B',
  description: 'Banana, coconut, chicken in bulk',
  slug: 'b2b-wholesale',
  iconName: 'agriculture_outlined',
  kind: MarketplacePostKind.listing,
  tradeMode: MarketplaceTradeMode.wholesaleOnly,
  displayOrder: 2,
  isActive: true,
  subCategories: [
    MarketplaceSubCategory(
      id: 's-fruits',
      name: 'Fruits',
      slug: 'fruits',
      displayOrder: 1,
      isActive: true,
    ),
  ],
  fields: [],
);

const _food = MarketplaceCategory(
  id: 'cat-food',
  name: 'Nearby food',
  shortName: 'Food',
  slug: 'nearby-food',
  iconName: 'restaurant_outlined',
  kind: MarketplacePostKind.foodOffer,
  tradeMode: MarketplaceTradeMode.retailOnly,
  displayOrder: 3,
  isActive: true,
  subCategories: [
    MarketplaceSubCategory(
      id: 's-biryani',
      name: 'Biryani & meals',
      slug: 'biryani-meals',
      displayOrder: 1,
      isActive: true,
    ),
  ],
  fields: [],
);

const _ads = MarketplaceCategory(
  id: 'cat-ads',
  name: 'Advertisements',
  shortName: 'Ads',
  slug: 'advertisements',
  iconName: 'campaign_outlined',
  kind: MarketplacePostKind.advertisement,
  tradeMode: MarketplaceTradeMode.retailOnly,
  displayOrder: 4,
  isActive: true,
  subCategories: [
    MarketplaceSubCategory(
      id: 's-cricket',
      name: 'Cricket tournament',
      slug: 'cricket-tournament',
      displayOrder: 1,
      isActive: true,
    ),
  ],
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
    MarketplaceOption(code: 'Sold', name: 'Sold', tone: 'success'),
  ],
  conditions: [
    MarketplaceOption(
      code: 'New',
      name: 'New',
      detail: 'Brand new — keep a stock count',
    ),
    MarketplaceOption(
      code: 'Used',
      name: 'Used',
      detail: 'One piece — mark it sold when it goes',
    ),
  ],
  tradeModes: [
    MarketplaceOption(code: 'RetailOnly', name: 'Retail only'),
    MarketplaceOption(code: 'WholesaleOnly', name: 'Wholesale only (B2B)'),
    MarketplaceOption(code: 'Either', name: 'Either'),
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
  String categoryId = 'cat-products',
  String categoryName = 'Products',
  String? subCategoryId = 's-vehicles',
  String? subCategoryName = 'Vehicles',
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
  String? condition,
  bool isOutOfStock = false,
  bool canUpdateStock = false,
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
  condition: condition,
  isOutOfStock: isOutOfStock,
  canUpdateStock: canUpdateStock,
  categoryId: categoryId,
  categoryName: categoryName,
  subCategoryId: subCategoryId,
  subCategoryName: subCategoryName,
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
    this.categories = const [_products, _b2b, _food, _ads],
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
  final stockChanges = <(String, int)>[];
  final deleted = <String>[];
  final uploads = <(String, int)>[];
  final savedCategories = <MarketplaceCategoryInput>[];
  final savedSubCategories = <(String, MarketplaceSubCategoryInput)>[];
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
      sold: posts.where((p) => p.status == MarketplacePostStatus.sold).length,
      plan: plan,
      categories: [
        for (final id in {for (final p in posts) p.categoryId})
          MarketplaceCategoryCount(
            categoryId: id,
            active: _countOf(id, MarketplacePostStatus.active),
            paused: _countOf(id, MarketplacePostStatus.paused),
            expired: _countOf(id, MarketplacePostStatus.expired),
            closed: _countOf(id, MarketplacePostStatus.closed),
            sold: _countOf(id, MarketplacePostStatus.sold),
          ),
      ],
    );
  }

  int _countOf(String categoryId, String status) => posts
      .where((p) => p.categoryId == categoryId && p.status == status)
      .length;

  @override
  Future<List<MarketplacePost>> getMyPosts({
    String? categoryId,
    String? status,
  }) async {
    if (failList case final error?) throw error;
    return posts
        .where((p) => categoryId == null || p.categoryId == categoryId)
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
  Future<MarketplacePost> updateStock(String id, int quantity) async {
    stockChanges.add((id, quantity));
    return _post(id: id, quantity: quantity);
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
    return _products;
  }

  @override
  Future<MarketplaceCategory> updateCategory(
    String id,
    MarketplaceCategoryInput input,
  ) async {
    savedCategories.add(input);
    return _products;
  }

  @override
  Future<MarketplaceCategory> createSubCategory(
    String categoryId,
    MarketplaceSubCategoryInput input,
  ) async {
    savedSubCategories.add((categoryId, input));
    return _products;
  }

  @override
  Future<MarketplaceCategory> updateSubCategory(
    String categoryId,
    String subId,
    MarketplaceSubCategoryInput input,
  ) async {
    savedSubCategories.add((categoryId, input));
    return _products;
  }

  @override
  Future<MarketplaceCategory> createField(
    String categoryId,
    MarketplaceFieldInput input,
  ) async => _products;

  @override
  Future<MarketplaceCategory> updateField(
    String categoryId,
    String fieldId,
    MarketplaceFieldInput input,
  ) async => _products;
}

class _NoServices extends BusinessServicesNotifier {
  @override
  Future<List<BusinessService>> build() async => const [];
}

Future<_FakeMarketplaceRepository> _pump(
  WidgetTester tester,
  Widget child, {
  _FakeMarketplaceRepository? repository,
  Future<List<District>> Function()? districts,
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
          (ref, csv) => districts?.call() ?? Future.value(const [_kanyakumari]),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

/// Opens the add sheet from the Marketplace tab and picks [category], then [sub] — its first
/// sub-category unless said otherwise, none when [pickSub] is false. In a category that keeps stock it
/// also picks [condition] — Used unless said otherwise, so no stock is asked.
Future<void> _openFormFor(
  WidgetTester tester,
  MarketplaceCategory category, {
  String? sub,
  bool pickSub = true,
  String condition = MarketplaceItemCondition.used,
}) async {
  await tester.tap(find.byKey(const ValueKey('marketplace-add-post')));
  await tester.pumpAndSettle();
  await _choose(tester, 'marketplace-category', category.id);
  if (pickSub && category.subCategories.isNotEmpty) {
    await _choose(
      tester,
      'marketplace-sub-category',
      sub ?? category.subCategories.first.id,
    );
  }
  if (category.tracksStock) {
    await _choose(tester, 'marketplace-condition', condition);
  }
}

/// Fills what a B2B post needs beyond a title and price: what the price is per, and a smallest order.
Future<void> _fillWholesale(WidgetTester tester) async {
  await _type(tester, 'marketplace-price-unit', 'kg');
  await _type(tester, 'marketplace-min-order', '100');
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
        marketplaceDetailsLine(_post(), const [_products]),
        '2019 · 48000 km · Petrol',
      );
      expect(
        marketplaceDetailsLine(_post(attributes: const {}), const [_products]),
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

      expect(
        find.text('Products › Vehicles · Marthandam, Kanyakumari'),
        findsOneWidget,
      );
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
        find.textContaining(
          'products, b2b wholesale, nearby food or advertisements',
        ),
        findsOneWidget,
        reason: 'named from the category table',
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

    testWidgets(
      'a square per main category, without counts, starts a post in it',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(
          tester,
          const BusinessMarketplaceTab(),
          repository: _FakeMarketplaceRepository(
            posts: [_post()],
            plan: _plan(max: 2, used: 1),
          ),
        );

        // Names only: counting and filtering live on Orders › Marketplace.
        for (final c in [_products, _b2b, _food, _ads]) {
          expect(find.bySemanticsLabel(c.shortName), findsOneWidget);
        }
        expect(find.bySemanticsLabel('Products, 1'), findsNothing);

        await tester.tap(find.byKey(ValueKey('category-square-${_food.id}')));
        await tester.pumpAndSettle();

        expect(find.byType(MarketplacePostFormSheet), findsOneWidget);
        final category = find.byKey(const ValueKey('marketplace-category'));
        expect(
          find.descendant(of: category, matching: find.text(_food.name)),
          findsOneWidget,
          reason: 'the tapped category is already picked',
        );
        // Next comes its sub-category.
        expect(
          find.byKey(const ValueKey('marketplace-sub-category')),
          findsOneWidget,
        );
        handle.dispose();
      },
    );

    testWidgets('a square saves straight into its category', (tester) async {
      final repo = await _pump(tester, const BusinessMarketplaceTab());

      await tester.tap(find.byKey(ValueKey('category-square-${_b2b.id}')));
      await tester.pumpAndSettle();
      await _choose(
        tester,
        'marketplace-sub-category',
        _b2b.subCategories.first.id,
      );
      await _type(tester, 'marketplace-title', 'Nendran banana');
      await _type(tester, 'marketplace-price', '45');
      await _fillWholesale(tester);
      await _choose(tester, 'marketplace-state', 's-tn');
      await _choose(tester, 'marketplace-district-s-tn', 'd-kk');
      await _save(tester);

      expect(repo.created.single.categoryId, _b2b.id);
      expect(repo.created.single.tradeType, MarketplaceTradeType.wholesale);
    });

    testWidgets('a full plan: a square explains instead of opening the form', (
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

      await tester.tap(find.byKey(ValueKey('category-square-${_food.id}')));
      await tester.pumpAndSettle();

      expect(find.byType(MarketplacePostFormSheet), findsNothing);
      expect(
        find.text(
          'Your Free plan allows 1 active post. Pause or close one to put up another.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a home tile list has no squares — it does not add', (
      tester,
    ) async {
      await _pump(
        tester,
        const BusinessMarketplaceTab(status: MarketplacePostStatus.paused),
        repository: _FakeMarketplaceRepository(
          posts: [_post(status: MarketplacePostStatus.paused)],
        ),
      );

      expect(
        find.byKey(ValueKey('category-square-${_products.id}')),
        findsNothing,
      );
      expect(find.text('Swift VXi 2019'), findsOneWidget);
    });

    testWidgets('the four squares fit a 360 dp phone', (tester) async {
      await _pump(tester, const BusinessMarketplaceTab());
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpAndSettle();

      for (final c in [_products, _b2b, _food, _ads]) {
        final rect = tester.getRect(
          find.byKey(ValueKey('category-square-${c.id}')),
        );
        expect(rect.right, lessThanOrEqualTo(360 - 16));
        expect(rect.height, lessThan(90));
      }
      expect(tester.takeException(), isNull);
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
      await _openFormFor(tester, _products, sub: 's-vehicles');

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
      await _openFormFor(tester, _products, sub: 's-vehicles');

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
      await _openFormFor(tester, _products, sub: 's-vehicles');

      await _type(tester, 'marketplace-title', 'Swift VXi 2019');
      await _type(tester, 'marketplace-price', '420000');
      await _type(tester, 'marketplace-field-model_year', '2019');
      await _type(tester, 'marketplace-field-km_driven', '48000');
      await _choose(tester, 'marketplace-field-fuel', 'Petrol');
      await _choose(tester, 'marketplace-state', 's-tn');
      await _choose(tester, 'marketplace-district-s-tn', 'd-kk');
      await _save(tester);

      final input = repo.created.single;
      expect(input.categoryId, 'cat-products');
      expect(input.subCategoryId, 's-vehicles');
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
      await _openFormFor(tester, _products, sub: 's-vehicles');
      await _type(tester, 'marketplace-field-km_driven', '48000');

      await _choose(tester, 'marketplace-category', _b2b.id);
      await _choose(tester, 'marketplace-sub-category', 's-fruits');
      await _type(tester, 'marketplace-title', 'Nendran banana');
      await _type(tester, 'marketplace-price', '45');
      await _fillWholesale(tester);
      await _choose(tester, 'marketplace-state', 's-tn');
      await _choose(tester, 'marketplace-district-s-tn', 'd-kk');
      await _save(tester);

      expect(repo.created.single.attributes, isEmpty);
    });

    testWidgets(
      'B2B is always wholesale: no "Sell as", and the unit and smallest order are asked',
      (tester) async {
        final repo = await _pump(tester, const BusinessMarketplaceTab());
        await _openFormFor(tester, _b2b);

        expect(
          find.byKey(const ValueKey('marketplace-trade-type')),
          findsNothing,
        );
        expect(find.text('Price per unit'), findsOneWidget);
        await _type(tester, 'marketplace-title', 'Nendran banana');
        await _type(tester, 'marketplace-price', '45');
        await _choose(tester, 'marketplace-state', 's-tn');
        await _choose(tester, 'marketplace-district-s-tn', 'd-kk');
        await _save(tester);
        expect(find.text('e.g. kg'), findsOneWidget);
        expect(find.text('Required.'), findsOneWidget);
        expect(repo.created, isEmpty);

        await _fillWholesale(tester);
        await _save(tester);

        final input = repo.created.single;
        expect(input.categoryId, _b2b.id);
        expect(input.subCategoryId, 's-fruits');
        expect(input.tradeType, MarketplaceTradeType.wholesale);
        expect(input.minOrderQuantity, 100);
        expect(input.priceUnit, 'kg');
      },
    );

    testWidgets('a retail-only category never offers wholesale', (
      tester,
    ) async {
      await _pump(tester, const BusinessMarketplaceTab());
      await _openFormFor(tester, _products);

      expect(
        find.byKey(const ValueKey('marketplace-trade-type')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('marketplace-min-order')), findsNothing);
      expect(find.text('Per (optional)'), findsOneWidget);
    });

    testWidgets(
      'the sub-category is asked, and the category says what goes in it',
      (tester) async {
        final repo = await _pump(tester, const BusinessMarketplaceTab());
        await tester.tap(find.byKey(const ValueKey('marketplace-add-post')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('marketplace-category')));
        await tester.pumpAndSettle();

        expect(find.text('Sarees, shirts, toys'), findsOneWidget);
        await tester.tap(find.byKey(ValueKey('select-option-${_products.id}')));
        await tester.pumpAndSettle();
        await _save(tester);

        expect(find.text('Choose what kind it is.'), findsOneWidget);
        expect(repo.created, isEmpty);
      },
    );

    testWidgets("a sarees post is not asked a vehicle's details", (
      tester,
    ) async {
      await _pump(tester, const BusinessMarketplaceTab());
      await _openFormFor(tester, _products, sub: 's-sarees');

      expect(
        find.byKey(const ValueKey('marketplace-field-km_driven')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('marketplace-field-condition')),
        findsOneWidget,
        reason: 'asked in every Products sub-category',
      );
    });

    testWidgets("changing the sub-category drops only the old one's details", (
      tester,
    ) async {
      final repo = await _pump(tester, const BusinessMarketplaceTab());
      await _openFormFor(tester, _products, sub: 's-vehicles');
      await _choose(tester, 'marketplace-field-condition', 'Used');
      await _type(tester, 'marketplace-field-km_driven', '48000');

      await _choose(tester, 'marketplace-sub-category', 's-sarees');
      await _type(tester, 'marketplace-title', 'Silk saree');
      await _type(tester, 'marketplace-price', '2400');
      await _choose(tester, 'marketplace-state', 's-tn');
      await _choose(tester, 'marketplace-district-s-tn', 'd-kk');
      await _save(tester);

      expect(repo.created.single.subCategoryId, 's-sarees');
      expect(repo.created.single.attributes, {'condition': 'Used'});
    });

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
      await _openFormFor(tester, _b2b);

      await _type(tester, 'marketplace-title', 'Nendran banana');
      await _type(tester, 'marketplace-price', '45');
      await _fillWholesale(tester);
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
        repository: _FakeMarketplaceRepository(
          posts: [_post(condition: MarketplaceItemCondition.used)],
        ),
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

  group('Saving shows it worked', () {
    testWidgets(
      '"Post added." shows over the form after saving from the bottom',
      (tester) async {
        await _pump(tester, const BusinessMarketplaceTab());
        await _openFormFor(tester, _b2b);
        await _type(tester, 'marketplace-title', 'Nendran banana');
        await _type(tester, 'marketplace-price', '45');
        await _fillWholesale(tester);
        await _choose(tester, 'marketplace-state', 's-tn');
        await _choose(tester, 'marketplace-district-s-tn', 'd-kk');

        final save = find.byKey(const ValueKey('primary-button'));
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final banner = find.byKey(const ValueKey('marketplace-post-saved'));
        expect(banner, findsOneWidget);
        expect(
          find.descendant(of: banner, matching: find.text('Post added.')),
          findsOneWidget,
        );
        final sheetTop = tester
            .getTopLeft(find.byType(MarketplacePostFormSheet))
            .dy;
        expect(
          tester.getTopLeft(banner).dy - sheetTop,
          lessThan(60),
          reason: 'pinned to the top of the sheet',
        );

        await tester.pumpAndSettle();
        expect(find.byType(MarketplacePostFormSheet), findsNothing);
      },
    );

    testWidgets('a refused save scrolls up to the reason', (tester) async {
      final repo = _FakeMarketplaceRepository()
        ..failCreate = const UnknownAppException(
          'Your Free plan allows 1 active post. Pause or close one to put up another.',
        );
      await _pump(tester, const BusinessMarketplaceTab(), repository: repo);
      await _openFormFor(tester, _b2b);
      await _type(tester, 'marketplace-title', 'Nendran banana');
      await _type(tester, 'marketplace-price', '45');
      await _fillWholesale(tester);
      await _choose(tester, 'marketplace-state', 's-tn');
      await _choose(tester, 'marketplace-district-s-tn', 'd-kk');
      await _save(tester);

      final reason = find.textContaining('Free plan allows 1 active post');
      expect(reason, findsOneWidget);
      final sheet = tester.getRect(find.byType(MarketplacePostFormSheet));
      final at = tester.getTopLeft(reason).dy;
      expect(at, greaterThanOrEqualTo(sheet.top));
      expect(at - sheet.top, lessThan(200));
    });
  });

  group('District', () {
    testWidgets('stays locked and says so until the districts have loaded', (
      tester,
    ) async {
      final loading = Completer<List<District>>();
      await _pump(
        tester,
        const BusinessMarketplaceTab(),
        districts: () => loading.future,
      );
      await _openFormFor(tester, _food);
      await _choose(tester, 'marketplace-state', 's-tn');

      final district = find.byKey(const ValueKey('marketplace-district-s-tn'));
      expect(find.text('Loading districts…'), findsOneWidget);
      await tester.tap(district);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('select-option-d-kk')),
        findsNothing,
        reason: 'no empty list opens while loading',
      );

      loading.complete(const [_kanyakumari]);
      await tester.pumpAndSettle();
      expect(find.text('Loading districts…'), findsNothing);
      await _choose(tester, 'marketplace-district-s-tn', 'd-kk');
      expect(
        find.descendant(of: district, matching: find.text('Kanyakumari')),
        findsOneWidget,
      );
    });
  });

  group('Products: stock for new, Sold for used', () {
    testWidgets('a new item asks its stock, and 0 is allowed', (tester) async {
      final repo = await _pump(tester, const BusinessMarketplaceTab());
      await _openFormFor(
        tester,
        _products,
        sub: 's-sarees',
        condition: MarketplaceItemCondition.newItem,
      );

      expect(find.byKey(const ValueKey('marketplace-stock')), findsOneWidget);
      await _type(tester, 'marketplace-title', 'Silk saree');
      await _type(tester, 'marketplace-price', '2400');
      await _choose(tester, 'marketplace-state', 's-tn');
      await _choose(tester, 'marketplace-district-s-tn', 'd-kk');
      await _save(tester);
      expect(repo.created, isEmpty, reason: 'stock is required');
      expect(find.text('Required.'), findsOneWidget);

      await _type(tester, 'marketplace-stock', '0');
      await _save(tester);

      final input = repo.created.single;
      expect(input.condition, MarketplaceItemCondition.newItem);
      expect(input.quantity, 0);
    });

    testWidgets('a used item is one piece: no stock asked or sent', (
      tester,
    ) async {
      final repo = await _pump(tester, const BusinessMarketplaceTab());
      await _openFormFor(tester, _products, sub: 's-sarees');

      expect(find.byKey(const ValueKey('marketplace-stock')), findsNothing);
      expect(find.text('One piece — mark it sold when it goes'), findsNothing);
      await _type(tester, 'marketplace-title', 'Silk saree');
      await _type(tester, 'marketplace-price', '900');
      await _choose(tester, 'marketplace-state', 's-tn');
      await _choose(tester, 'marketplace-district-s-tn', 'd-kk');
      await _save(tester);

      final input = repo.created.single;
      expect(input.condition, MarketplaceItemCondition.used);
      expect(input.quantity, isNull);
    });

    testWidgets('a product must say New or Used', (tester) async {
      final repo = await _pump(tester, const BusinessMarketplaceTab());
      // By hand, not _openFormFor: that one picks a condition.
      await tester.tap(find.byKey(const ValueKey('marketplace-add-post')));
      await tester.pumpAndSettle();
      await _choose(tester, 'marketplace-category', _products.id);
      await _choose(tester, 'marketplace-sub-category', 's-sarees');

      await _type(tester, 'marketplace-title', 'Silk saree');
      await _type(tester, 'marketplace-price', '900');
      await _choose(tester, 'marketplace-state', 's-tn');
      await _choose(tester, 'marketplace-district-s-tn', 'd-kk');
      await _save(tester);

      expect(repo.created, isEmpty);
      expect(find.text('Choose New or Used.'), findsOneWidget);
    });

    testWidgets('the card says New with its stock, Used as one piece', (
      tester,
    ) async {
      await _pump(
        tester,
        const BusinessMarketplaceTab(),
        repository: _FakeMarketplaceRepository(
          posts: [
            _post(
              title: 'Silk saree',
              condition: MarketplaceItemCondition.newItem,
              quantity: 12,
              canUpdateStock: true,
            ),
            _post(
              id: 'p-2',
              title: 'Cotton saree',
              condition: MarketplaceItemCondition.newItem,
              quantity: 0,
              isOutOfStock: true,
              canUpdateStock: true,
            ),
            _post(
              id: 'p-3',
              title: 'Swift VXi 2019',
              condition: MarketplaceItemCondition.used,
            ),
          ],
          plan: _plan(max: 3, used: 3),
        ),
      );

      expect(find.text('New · 12 in stock'), findsOneWidget);
      expect(find.text('New'), findsOneWidget, reason: 'the empty one');
      expect(
        find.byKey(const ValueKey('marketplace-out-of-stock')),
        findsOneWidget,
      );
      expect(find.text('Used · one piece'), findsOneWidget);
    });

    testWidgets('Update stock sets the count without the whole form', (
      tester,
    ) async {
      final repo = await _pump(
        tester,
        const BusinessMarketplaceTab(),
        repository: _FakeMarketplaceRepository(
          posts: [
            _post(
              title: 'Silk saree',
              condition: MarketplaceItemCondition.newItem,
              quantity: 12,
              canUpdateStock: true,
            ),
          ],
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update stock'));
      await tester.pumpAndSettle();

      expect(find.byType(MarketplacePostFormSheet), findsNothing);
      await tester.tap(find.byKey(const ValueKey('marketplace-stock-less')));
      await tester.pump();
      expect(find.text('11'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('marketplace-stock-save')));
      await tester.pumpAndSettle();

      expect(repo.stockChanges, [('p-1', 11)]);
      expect(find.text('Silk saree: 11 in stock.'), findsOneWidget);
    });

    testWidgets('a used item has no Update stock', (tester) async {
      await _pump(
        tester,
        const BusinessMarketplaceTab(),
        repository: _FakeMarketplaceRepository(
          posts: [_post(condition: MarketplaceItemCondition.used)],
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Update stock'), findsNothing);
    });

    testWidgets('Mark as sold asks first, then moves the post to Sold', (
      tester,
    ) async {
      final repo = await _pump(
        tester,
        const BusinessMarketplaceTab(),
        repository: _FakeMarketplaceRepository(
          posts: [
            _post(
              condition: MarketplaceItemCondition.used,
              actions: const [
                MarketplacePostAction(
                  toStatus: MarketplacePostStatus.sold,
                  name: 'Mark as sold',
                  needsConfirm: true,
                ),
              ],
            ),
          ],
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as sold'));
      await tester.pumpAndSettle();
      expect(find.text('Mark as sold?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Mark as sold'));
      await tester.pumpAndSettle();

      expect(repo.statusChanges, [('p-1', MarketplacePostStatus.sold)]);
    });

    testWidgets('a sold post cannot be edited', (tester) async {
      await _pump(
        tester,
        const BusinessMarketplaceTab(),
        repository: _FakeMarketplaceRepository(
          posts: [
            _post(
              status: MarketplacePostStatus.sold,
              condition: MarketplaceItemCondition.used,
              actions: const [],
            ),
          ],
        ),
      );

      expect(find.text('Sold'), findsOneWidget);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('Orders › Marketplace has a Sold chip from the status table', (
      tester,
    ) async {
      await _pump(
        tester,
        const BusinessMarketplaceOrdersTab(),
        repository: _FakeMarketplaceRepository(
          posts: [
            _post(
              status: MarketplacePostStatus.sold,
              condition: MarketplaceItemCondition.used,
              actions: const [],
            ),
          ],
        ),
      );

      final sold = find.byKey(const ValueKey('marketplace-orders-Sold'));
      await tester.ensureVisible(sold);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: sold, matching: find.text('Sold 1')),
        findsOneWidget,
      );
    });

    testWidgets('the super admin turns stock on for a category', (
      tester,
    ) async {
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
      final toggle = find.byKey(
        const ValueKey('admin-marketplace-tracks-stock'),
      );
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.tap(find.byKey(const ValueKey('primary-button')));
      await tester.pumpAndSettle();

      expect(repo.savedCategories.single.tracksStock, isTrue);
    });
  });

  group('Orders › Marketplace', () {
    testWidgets('posts by status, named from the server table, with counts', (
      tester,
    ) async {
      await _pump(
        tester,
        const BusinessMarketplaceOrdersTab(),
        repository: _FakeMarketplaceRepository(
          posts: [
            _post(title: 'Live one'),
            _post(
              id: 'p-2',
              title: 'Held one',
              status: 'Paused',
              actions: const [],
            ),
          ],
          plan: _plan(used: 1),
        ),
      );

      expect(find.text('All 2'), findsNWidgets(2), reason: 'both rows');
      expect(find.text('Active 1'), findsOneWidget);
      expect(find.text('On hold 1'), findsOneWidget);
      expect(find.text('Live one'), findsOneWidget);
      expect(find.text('Held one'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('marketplace-orders-Paused')));
      await tester.pumpAndSettle();

      expect(find.text('Held one'), findsOneWidget);
      expect(find.text('Live one'), findsNothing);
    });

    testWidgets(
      'a row of main categories with counts sits above the statuses, and both combine',
      (tester) async {
        await _pump(
          tester,
          const BusinessMarketplaceOrdersTab(),
          repository: _FakeMarketplaceRepository(
            posts: [
              _post(title: 'Swift VXi 2019'),
              _post(
                id: 'p-2',
                title: 'Veg biryani',
                kind: MarketplacePostKind.foodOffer,
                categoryId: _food.id,
                categoryName: _food.name,
                subCategoryId: 's-biryani',
                subCategoryName: 'Biryani & meals',
                status: MarketplacePostStatus.paused,
                actions: const [],
              ),
              _post(
                id: 'p-3',
                title: 'Chicken biryani',
                kind: MarketplacePostKind.foodOffer,
                categoryId: _food.id,
                categoryName: _food.name,
                subCategoryId: 's-biryani',
                subCategoryName: 'Biryani & meals',
                status: MarketplacePostStatus.closed,
                actions: const [],
              ),
            ],
            plan: _plan(used: 1),
          ),
        );

        Finder chip(String key) => find.byKey(ValueKey(key));
        String labelOf(String key) => tester
            .widget<Text>(
              find.descendant(of: chip(key), matching: find.byType(Text)),
            )
            .data!;

        // Short names from the category table, above the status row.
        expect(
          labelOf('marketplace-orders-category-${_products.id}'),
          'Products 1',
        );
        expect(labelOf('marketplace-orders-category-${_b2b.id}'), 'B2B 0');
        expect(labelOf('marketplace-orders-category-${_food.id}'), 'Food 2');
        expect(labelOf('marketplace-orders-category-${_ads.id}'), 'Ads 0');
        expect(
          tester.getTopLeft(chip('marketplace-orders-category-all')).dy,
          lessThan(tester.getTopLeft(chip('marketplace-orders-all')).dy),
        );

        // Food: the list and the status counts narrow to food.
        await tester.ensureVisible(
          chip('marketplace-orders-category-${_food.id}'),
        );
        await tester.pumpAndSettle();
        await tester.tap(chip('marketplace-orders-category-${_food.id}'));
        await tester.pumpAndSettle();
        expect(find.text('Swift VXi 2019'), findsNothing);
        expect(find.text('Veg biryani'), findsOneWidget);
        expect(find.text('Chicken biryani'), findsOneWidget);
        expect(labelOf('marketplace-orders-all'), 'All 2');
        expect(labelOf('marketplace-orders-Active'), 'Active 0');
        expect(labelOf('marketplace-orders-Paused'), 'On hold 1');

        // Food + On hold: one post, and the category counts follow the status.
        await tester.ensureVisible(chip('marketplace-orders-Paused'));
        await tester.pumpAndSettle();
        await tester.tap(chip('marketplace-orders-Paused'));
        await tester.pumpAndSettle();
        expect(find.text('Veg biryani'), findsOneWidget);
        expect(find.text('Chicken biryani'), findsNothing);
        expect(labelOf('marketplace-orders-category-${_food.id}'), 'Food 1');
        expect(
          labelOf('marketplace-orders-category-${_products.id}'),
          'Products 0',
        );

        // Products + On hold: nothing, and it says which.
        await tester.ensureVisible(
          chip('marketplace-orders-category-${_products.id}'),
        );
        await tester.pumpAndSettle();
        await tester.tap(chip('marketplace-orders-category-${_products.id}'));
        await tester.pumpAndSettle();
        expect(find.text('No on hold posts in Products'), findsOneWidget);
      },
    );

    testWidgets('an empty status says where posts come from', (tester) async {
      await _pump(tester, const BusinessMarketplaceOrdersTab());

      final expired = find.byKey(const ValueKey('marketplace-orders-Expired'));
      await tester.ensureVisible(expired);
      await tester.tap(expired);
      await tester.pumpAndSettle();

      expect(find.text('No expired posts'), findsOneWidget);
      expect(find.textContaining('Services › Marketplace'), findsOneWidget);
    });

    testWidgets('Orders has Service, Rent and Marketplace', (tester) async {
      await _pump(tester, const BusinessCatalogTab());
      expect(find.text('Marketplace'), findsOneWidget);
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
            _products,
            MarketplaceCategory(
              id: 'cat-old',
              name: 'Old stuff',
              slug: 'old-stuff',
              kind: MarketplacePostKind.listing,
              shortName: 'Old stuff',
              tradeMode: MarketplaceTradeMode.retailOnly,
              displayOrder: 9,
              isActive: false,
              subCategories: [],
              fields: [],
            ),
          ],
        ),
      );

      expect(find.text('Products'), findsOneWidget);
      expect(
        find.text(
          'Listing · Retail only · New / used, with stock · 2 sub-categories',
        ),
        findsOneWidget,
      );
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
