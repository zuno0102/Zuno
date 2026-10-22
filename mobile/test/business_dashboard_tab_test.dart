import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/business_owner/data/models/business_dashboard_model.dart';
import 'package:zuno/features/business_owner/domain/entities/business_dashboard.dart';
import 'package:zuno/features/business_owner/domain/entities/business_service.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_dashboard_notifier.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_services_notifier.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_dashboard_tab.dart';
import 'package:zuno/features/business_owner/presentation/screens/dashboard_detail_screens.dart';
import 'package:zuno/shared/domain/business_trust.dart';

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

  Future<void> pump(WidgetTester tester, BusinessDashboard data) async {
    // A narrow phone, where five tiles across would never have fitted.
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessDashboardProvider.overrideWith((ref) async => data),
        ],
        child: const MaterialApp(home: Scaffold(body: BusinessDashboardTab())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders every section without a layout failure', (tester) async {
    await pump(tester, dashboard);

    // The single most important assertion: nothing threw. A stretch into an unbounded height
    // shows up here and nowhere else.
    expect(tester.takeException(), isNull);

    // The headline and the chart sit either side of the tiles, so if the viewport had failed
    // these would be the casualties.
    expect(find.text('ORDERS FINISHED'), findsOneWidget);
    expect(find.text('Customer activity'), findsOneWidget);
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
    // The order reads Completed in the database; here it must say what is left to do.
    expect(find.text('Awaiting payment'), findsWidgets);
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

  testWidgets('an empty dashboard still lays out', (tester) async {
    await pump(tester, const BusinessDashboard());

    expect(tester.takeException(), isNull);
    expect(find.text('Active workers'), findsOneWidget);
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
}

/// The service list the tiles open fetches for itself, so a test that only cares about the
/// navigation still has to answer it.
class _NoServices extends BusinessServicesNotifier {
  @override
  Future<List<BusinessService>> build() async => const [];
}
