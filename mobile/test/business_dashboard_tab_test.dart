import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/business_owner/data/models/business_dashboard_model.dart';
import 'package:zuno/features/business_owner/domain/entities/business_dashboard.dart';
import 'package:zuno/features/business_owner/domain/entities/business_service.dart';
import 'package:zuno/features/business_owner/domain/entities/business_profile.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_dashboard_notifier.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_profile_notifier.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_services_notifier.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_dashboard_tab.dart';
import 'package:zuno/features/business_owner/presentation/screens/dashboard_detail_screens.dart';
import 'package:zuno/features/catalog/domain/entities/order_stage.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zuno/shared/domain/business_trust.dart';
import 'package:zuno/shared/widgets/profile_incomplete_banner.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_payment.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_summary.dart';
import 'package:zuno/features/vacancy/presentation/providers/vacancy_providers.dart';
import 'package:zuno/features/vacancy/presentation/screens/business_vacancies_tab.dart';
import 'package:zuno/features/vacancy/presentation/screens/vacancy_applicants_screen.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:zuno/features/rental/domain/entities/rental_item.dart';
import 'package:zuno/features/rental/presentation/providers/rental_providers.dart';
import 'package:zuno/features/rental/presentation/screens/business_catalog_tab.dart';

import 'features/vacancy/vacancy_fixtures.dart';

const _summary = VacancySummary(
  activePosts: 21,
  totalPosts: 26,
  newCount: 22,
  waitingCount: 23,
  shortlistedCount: 24,
  hiredCount: 25,
);

/// The business home screen must render every section on a phone-sized screen.
///
/// Worth a test of its own because the stat tiles are laid out in wrapped rows inside a
/// ListView, where the height is unbounded: a row that tries to stretch into that fails the
/// whole viewport's layout, and takes the headline card and the trend chart down with it — the
/// screen goes blank rather than showing one broken tile.
void main() {
  final dashboard = BusinessDashboard(
    eventsCompleted: 5,
    upcomingEvents: 1,
    awaitingPaymentEvents: 9,
    awaitingPayment: [
      DashboardEvent(
        id: 'b-2',
        serviceName: 'Paintings',
        categoryName: 'Painting',
        subCategoryName: 'Wall painting',
        customerName: 'Test Customer',
        scheduledDate: DateTime(2026, 10, 1),
        price: 3000,
        status: 'Completed',
        stage: 'AwaitingPayment',
      ),
    ],
    cancelledEvents: 1,
    crewEventsCompleted: 6,
    activeWorkers: 4,
    activeServices: 7,
    inactiveServices: 3,
    totalRevenue: 13400,
    byCategory: const [
      CategoryBreakdown(
        serviceCategoryId: 'c-1',
        categoryName: 'Painting',
        count: 2,
        revenue: 8400,
        subCategories: [
          SubCategoryBreakdown(
            name: 'Acrylic painting',
            count: 2,
            revenue: 8400,
          ),
        ],
      ),
    ],
    trend: const [
      MonthlyActivity(
        label: 'Jul',
        year: 2026,
        month: 7,
        completed: 2,
        revenue: 4900,
      ),
      MonthlyActivity(
        label: 'Aug',
        year: 2026,
        month: 8,
        completed: 2,
        revenue: 6000,
      ),
      MonthlyActivity(
        label: 'Sep',
        year: 2026,
        month: 9,
        completed: 1,
        revenue: 2500,
      ),
    ],
    workers: [
      DashboardWorker(
        workerProfileId: 'w-1',
        workerName: '',
        availabilityStatus: 'Active',
        jobsCompleted: 3,
        sinceDate: DateTime(2026, 6, 1),
      ),
      DashboardWorker(
        workerProfileId: 'w-2',
        workerName: 'Binu K',
        availabilityStatus: 'Booked',
        workerPhone: '9876543210',
        sinceDate: DateTime(2026, 7, 14),
        busyOn: DateTime(2026, 9, 23, 9),
      ),
    ],
    trust: const BusinessTrust(),
  );

  Future<void> pump(
    WidgetTester tester,
    BusinessDashboard data, {
    BusinessProfile? profile,
    VacancySummary vacancies = _summary,
    RentalSummary? rent,
    MarketplaceSummary? marketplace,
    ValueChanged<int>? onOpenCatalog,
  }) async {
    // A narrow phone, where five tiles across would never have fitted. Tall enough that every
    // section is built: the list is lazy, and the Full-time jobs section pushed the last ones down.
    tester.view.physicalSize = const Size(720, 3200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (profile != null)
            businessProfileProvider.overrideWith(() => _Profile(profile)),
          businessDashboardProvider.overrideWith((ref) async => data),
          vacancySummaryProvider.overrideWith((ref) async => vacancies),
          // Rent and Marketplace are their own servers: answered here when a test gives them.
          if (rent != null)
            rentalSummaryProvider.overrideWith((ref) async => rent),
          if (marketplace != null) ...[
            marketplaceSummaryProvider.overrideWith((ref) async => marketplace),
            marketplaceCategoriesProvider.overrideWith(
              (ref) async => _categories,
            ),
          ],
          // A stage name that is not the live one: the row must show what the server sends.
          orderStagesProvider.overrideWith(
            (ref) async => const [
              OrderStage(code: 'AwaitingPayment', label: 'Pay pending'),
            ],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: BusinessDashboardTab(onOpenCatalog: onOpenCatalog),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a profile without a UPI ID is asked for first on the home', (
    tester,
  ) async {
    await pump(
      tester,
      dashboard,
      profile: const BusinessProfile(
        id: 'b1',
        businessName: 'Joy Events',
        verificationStatus: 'Verified',
        missingDetails: ['UPI ID'],
      ),
    );

    expect(find.byType(ProfileIncompleteBanner), findsOneWidget);
    expect(find.text('Finish your profile: add your UPI ID'), findsOneWidget);
  });

  testWidgets('a complete profile shows no banner on the home', (tester) async {
    await pump(
      tester,
      dashboard,
      profile: const BusinessProfile(
        id: 'b1',
        businessName: 'Joy Events',
        verificationStatus: 'Verified',
        upiId: 'joyevents@okhdfcbank',
      ),
    );

    expect(find.byType(ProfileIncompleteBanner), findsNothing);
  });

  testWidgets('renders every section without a layout failure', (tester) async {
    await pump(tester, dashboard);

    // The single most important assertion: nothing threw. A stretch into an unbounded height
    // shows up here and nowhere else.
    expect(tester.takeException(), isNull);

    // The headline and the chart sit either side of the tiles, so if the viewport had failed
    // these would be the casualties.
    expect(find.text('ORDERS FINISHED'), findsOneWidget);
    // Below the Marketplace groups, so scrolled to.
    await tester.scrollUntilVisible(
      find.text('Customer activity'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Customer activity'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the seven stat tiles', (tester) async {
    await pump(tester, dashboard);

    for (final label in [
      'Upcoming',
      'Awaiting payment',
      'Cancelled',
      'Crew events',
      'Active workers',
      'Active services',
      'Inactive services',
    ]) {
      expect(
        find.text(label),
        findsOneWidget,
        reason: '$label tile is missing',
      );
    }
  });

  testWidgets('Finished is shown once: on the card, with no tile of its own', (
    tester,
  ) async {
    await pump(tester, dashboard);

    expect(find.text('ORDERS FINISHED'), findsOneWidget);
    expect(find.text('Finished'), findsNothing);
  });

  testWidgets('the Orders finished card opens the split by category', (
    tester,
  ) async {
    await pump(tester, dashboard);

    await tester.tap(find.text('ORDERS FINISHED'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Orders finished'), findsOneWidget);
    expect(find.text('5 finished across 1 category'), findsOneWidget);
  });

  testWidgets('tiles show the counts they were given', (tester) async {
    await pump(tester, dashboard);

    expect(find.text('4'), findsOneWidget); // active workers
    expect(find.text('6'), findsOneWidget); // crew events
    expect(find.text('9'), findsOneWidget); // awaiting payment
    expect(find.text('7'), findsOneWidget); // active services
    expect(find.text('3'), findsOneWidget); // inactive services
  });

  /// Each service tile opens its own list, the way Awaiting payment and Active workers do.
  ///
  /// They used to switch to the Services tab, which lists every service — so two tiles showing
  /// different numbers landed on the same page and the tap said nothing about which was pressed.
  /// Each service tile opens its own list, the way Awaiting payment and Active workers do.
  ///
  /// They used to switch to the Services tab, which lists every service — so two tiles showing
  /// different numbers landed on the same page and the tap said nothing about which was pressed.
  /// One test per tile, because the two must be told apart and a shared pump would not: a second
  /// `pumpWidget` of the same tree keeps the Navigator's State, and with it the page just pushed.
  Future<void> tapServiceTile(WidgetTester tester, String label) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessDashboardProvider.overrideWith((ref) async => dashboard),
          vacancySummaryProvider.overrideWith((ref) async => _summary),
          businessServicesProvider.overrideWith(_NoServices.new),
        ],
        child: const MaterialApp(home: Scaffold(body: BusinessDashboardTab())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();

    expect(find.byType(BusinessServiceListScreen), findsOneWidget);
    // Titled by the tile that opened it, which is the only thing telling the two apart once you
    // are looking at the page.
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text(label)),
      findsOneWidget,
    );
  }

  testWidgets('the Active services tile opens the live ones', (tester) async {
    await tapServiceTile(tester, 'Active services');
  });

  testWidgets('and the Inactive tile opens the switched-off ones', (
    tester,
  ) async {
    await tapServiceTile(tester, 'Inactive services');
  });

  testWidgets('Awaiting payment opens the work still owing wages', (
    tester,
  ) async {
    await pump(tester, dashboard);

    await tester.tap(find.text('Awaiting payment'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('1 booking with a wage still owed'), findsOneWidget);
    expect(find.text('Wall painting'), findsOneWidget);
    // The order reads Completed in the database; the row shows the server's stage for it.
    expect(find.text('Pay pending'), findsOneWidget);
    expect(find.text('Completed'), findsNothing);
  });

  testWidgets('the API fields reach the tile', (tester) async {
    final model = BusinessDashboardModel.fromJson({
      'upcomingEvents': 3,
      'awaitingPaymentEvents': 7,
      'activeServices': 5,
      'inactiveServices': 2,
      'awaitingPayment': [
        {
          'id': 'b-9',
          'serviceName': 'Paintings',
          'categoryName': 'Painting',
          'customerName': 'A Customer',
          'scheduledDate': '2026-10-01T09:00:00Z',
          'price': 1000,
          'status': 'Completed',
        },
      ],
    }).toEntity();

    expect(model.upcomingEvents, 3);
    expect(model.awaitingPaymentEvents, 7);
    expect(model.activeServices, 5);
    expect(model.inactiveServices, 2);
    expect(model.awaitingPayment.single.id, 'b-9');
  });

  group('Home shows only the areas in use', () {
    // The section headers, top to bottom.
    List<String> sections(WidgetTester tester) {
      final headers = [
        for (final code in ['Service', 'FullTime', 'Rent', 'Marketplace'])
          if (find.byKey(ValueKey('home-section-$code')).evaluate().isNotEmpty)
            code,
      ];
      headers.sort(
        (a, b) => tester
            .getTopLeft(find.byKey(ValueKey('home-section-$a')))
            .dy
            .compareTo(
              tester.getTopLeft(find.byKey(ValueKey('home-section-$b'))).dy,
            ),
      );
      return headers;
    }

    testWidgets('a new business gets the Start card, which opens Services', (
      tester,
    ) async {
      final opened = <int>[];
      await pump(
        tester,
        const BusinessDashboard(),
        vacancies: _noVacancies,
        rent: _noRent,
        marketplace: _noPosts,
        onOpenCatalog: opened.add,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('What do you want to do?'), findsOneWidget);
      expect(sections(tester), isEmpty);
      expect(find.text('Customer activity'), findsNothing);

      for (final key in [
        'home-start-service',
        'home-start-rent',
        'home-start-marketplace',
      ]) {
        await tester.tap(find.byKey(ValueKey(key)));
      }
      expect(opened, [
        BusinessCatalogTab.serviceTab,
        BusinessCatalogTab.rentTab,
        BusinessCatalogTab.marketplaceTab,
      ]);
    });

    testWidgets('A · Service only: Service and Full-time jobs', (tester) async {
      await pump(tester, dashboard, rent: _noRent, marketplace: _noPosts);

      expect(sections(tester), ['Service', 'FullTime']);
      expect(find.byKey(const ValueKey('home-start-card')), findsNothing);
    });

    testWidgets('no vacancy ever posted: no Full-time jobs part', (
      tester,
    ) async {
      await pump(
        tester,
        dashboard,
        vacancies: _noVacancies,
        rent: _noRent,
        marketplace: _noPosts,
      );

      expect(sections(tester), ['Service']);
    });

    testWidgets('B · Rent only: Rent, with the customer cards', (tester) async {
      await pump(
        tester,
        const BusinessDashboard(),
        vacancies: _noVacancies,
        rent: _threeRentItems,
        marketplace: _noPosts,
      );

      expect(sections(tester), ['Rent']);
      expect(find.text('Customer activity'), findsOneWidget);
    });

    testWidgets('C · Marketplace only: its used groups, no customer cards', (
      tester,
    ) async {
      await pump(
        tester,
        const BusinessDashboard(),
        vacancies: _noVacancies,
        rent: _noRent,
        marketplace: _productsAndFood,
      );

      expect(sections(tester), ['Marketplace']);
      expect(find.text('Customer activity'), findsNothing);
      expect(
        find.byKey(const ValueKey('marketplace-tile-active')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('marketplace-tile-food-live')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('marketplace-tile-b2b-live')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('marketplace-tile-ads-live')),
        findsNothing,
      );
    });

    testWidgets('all three: Service, Full-time, Rent, Marketplace in order', (
      tester,
    ) async {
      await pump(
        tester,
        dashboard,
        rent: _threeRentItems,
        marketplace: _productsAndFood,
      );

      expect(tester.takeException(), isNull);
      expect(sections(tester), ['Service', 'FullTime', 'Rent', 'Marketplace']);
    });

    testWidgets('a server that cannot be reached keeps its section off Home', (
      tester,
    ) async {
      // Rent and Marketplace are not answered here: their servers fail in a test.
      await pump(tester, dashboard);

      expect(sections(tester), ['Service', 'FullTime']);
      expect(find.byKey(const ValueKey('home-start-card')), findsNothing);
    });
  });

  group('the profile card', () {
    testWidgets('is on the home tab, since it is no longer a bottom tab', (
      tester,
    ) async {
      await pump(tester, dashboard);

      expect(find.text('YOUR BUSINESS'), findsOneWidget);
    });

    testWidgets('opens the profile page when tapped', (tester) async {
      await pump(tester, dashboard);

      await tester.tap(find.text('YOUR BUSINESS'));
      // Pumped by hand rather than settled: the page lands on its loading spinner, which never
      // stops animating here, so pumpAndSettle would wait for it forever.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Business profile'), findsOneWidget);
    });

    testWidgets('draws before the profile has loaded', (tester) async {
      // It watches its own provider, which is not overridden here and so never resolves. The
      // card must still render rather than blanking the home screen behind it.
      await pump(tester, dashboard);

      expect(tester.takeException(), isNull);
      expect(find.text('Tap to add your details'), findsOneWidget);
    });
  });

  // Full-time hiring is its own section, apart from the order tiles, and each tile leads to the jobs.
  testWidgets(
    'the Full-time jobs section shows its counts and opens the jobs',
    (tester) async {
      tester.view.physicalSize = const Size(720, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final repo = FakeVacancyRepository()
        ..myVacancies = () async => const VacancyPage<Vacancy>(items: []);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessDashboardProvider.overrideWith((ref) async => dashboard),
            businessServicesProvider.overrideWith(_NoServices.new),
            vacancySummaryProvider.overrideWith((ref) async => _summary),
            // Marketplace is its own server; its tiles get a fixed answer here.
            marketplaceSummaryProvider.overrideWith(
              (ref) async => _marketplace,
            ),
            vacancyRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: Scaffold(body: BusinessDashboardTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Service jobs'), findsOneWidget);
      expect(find.text('Full-time jobs'), findsOneWidget);
      for (final (label, value) in const [
        ('Active posts', '21'),
        ('New applicants', '22'),
        ('Waiting', '23'),
        ('Shortlisted', '24'),
        ('Hired', '25'),
      ]) {
        final tile = find.ancestor(
          of: find.text(label),
          matching: find.byType(Card),
        );
        expect(
          find.descendant(of: tile, matching: find.text(value)),
          findsOneWidget,
          reason: label,
        );
      }

      // A count tile opens every job's applicants, on that tile's own tab.
      await tester.ensureVisible(find.text('Shortlisted'));
      await tester.tap(find.text('Shortlisted'));
      await tester.pumpAndSettle();

      expect(find.byType(VacancyApplicantsScreen), findsOneWidget);
      expect(find.text('All applicants'), findsOneWidget);
      final tabs = tester.widget<TabBar>(find.byType(TabBar));
      expect(
        DefaultTabController.of(tester.element(find.byWidget(tabs))).index,
        2,
        reason: 'Shortlisted is the third list',
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('applicants-tab-Shortlisted')),
          matching: find.text('24'),
        ),
        findsOneWidget,
      );

      // Active posts opens the jobs themselves.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Active posts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Active posts'));
      await tester.pumpAndSettle();

      expect(find.byType(BusinessVacanciesScreen), findsOneWidget);
    },
  );
}

/// The service list the tiles open fetches for itself, so a test that only cares about the
/// navigation still has to answer it.
class _NoServices extends BusinessServicesNotifier {
  @override
  Future<List<BusinessService>> build() async => const [];
}

class _Profile extends BusinessProfileNotifier {
  _Profile(this._profile);

  final BusinessProfile _profile;

  @override
  Future<BusinessProfile> build() async => _profile;
}

const _marketplace = MarketplaceSummary(
  active: 1,
  paused: 0,
  expired: 0,
  closed: 0,
  plan: MarketplacePlan(
    code: 'free',
    name: 'Free',
    price: 0,
    maxActivePosts: 1,
    usedActivePosts: 1,
  ),
);

MarketplaceCategory _category(String id, String kind, String tradeMode) =>
    MarketplaceCategory(
      id: id,
      name: id,
      shortName: id,
      slug: id,
      kind: kind,
      tradeMode: tradeMode,
      displayOrder: 1,
      isActive: true,
      subCategories: const [],
      fields: const [],
    );

final _categories = [
  _category(
    'products',
    MarketplacePostKind.listing,
    MarketplaceTradeMode.retailOnly,
  ),
  _category(
    'b2b',
    MarketplacePostKind.listing,
    MarketplaceTradeMode.wholesaleOnly,
  ),
  _category(
    'food',
    MarketplacePostKind.foodOffer,
    MarketplaceTradeMode.retailOnly,
  ),
  _category(
    'ads',
    MarketplacePostKind.advertisement,
    MarketplaceTradeMode.retailOnly,
  ),
];

/// A business with posts in Products and Food only.
const _productsAndFood = MarketplaceSummary(
  active: 3,
  paused: 0,
  expired: 0,
  closed: 0,
  liveItems: 2,
  liveFood: 1,
  plan: MarketplacePlan(
    code: 'free',
    name: 'Free',
    price: 0,
    maxActivePosts: 5,
    usedActivePosts: 3,
  ),
  categories: [
    MarketplaceCategoryCount(
      categoryId: 'products',
      active: 2,
      paused: 0,
      expired: 0,
      closed: 0,
    ),
    MarketplaceCategoryCount(
      categoryId: 'food',
      active: 1,
      paused: 0,
      expired: 0,
      closed: 0,
    ),
  ],
);

const _noPosts = MarketplaceSummary(
  active: 0,
  paused: 0,
  expired: 0,
  closed: 0,
  plan: MarketplacePlan(
    code: 'free',
    name: 'Free',
    price: 0,
    maxActivePosts: 1,
    usedActivePosts: 0,
  ),
);

const _noVacancies = VacancySummary(
  activePosts: 0,
  newCount: 0,
  waitingCount: 0,
  shortlistedCount: 0,
  hiredCount: 0,
);

const _noRent = RentalSummary(
  totalItems: 0,
  availableItems: 0,
  unavailableItems: 0,
  unitsAvailable: 0,
);

const _threeRentItems = RentalSummary(
  totalItems: 3,
  availableItems: 2,
  unavailableItems: 1,
  unitsAvailable: 40,
);
