import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/customer/domain/entities/service_listing.dart';
import 'package:zuno/features/customer/presentation/providers/daily_banners_provider.dart';
import 'package:zuno/features/customer/presentation/widgets/home_banner_section.dart';

/// The banner strip on the customer's home screen.
///
/// It replaced a painted card reading "Make your events special" above a button that did nothing.
/// Every banner is now a real service, and the strip moves on by itself every five seconds so all
/// seven are seen rather than only the first.
///
/// A timer that keeps running after its widget is gone is the classic way to make this crash, so the
/// tests below lean on `pumpAndSettle` and on disposal: both would throw if a timer outlived the
/// screen or if two were ever left running at once.
void main() {
  ServiceListing listing(int i) => ServiceListing(
    id: 's-$i',
    name: 'Service $i',
    serviceCategoryName: 'Catering',
    serviceCategoryId: 'c-1',
    price: 1000.0 * i,
    priceType: 'Fixed',
    imageUrl: null,
    businessOwnerProfileId: 'bo-$i',
    businessName: 'Business $i',
  );

  Future<void> pump(WidgetTester tester, List<ServiceListing> banners) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyBannersProvider.overrideWith((ref) async => banners),
        ],
        child: const MaterialApp(
          home: Scaffold(body: HomeBannerSection()),
        ),
      ),
    );
    await tester.pump(); // resolve the future
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Which banner is actually centred.
  ///
  /// Read from the controller rather than from what is on screen: the strip shows a sliver of the
  /// next banner alongside the current one, so finding its text proves nothing about which one the
  /// customer is looking at.
  double? centredPage(WidgetTester tester) {
    final pageView = tester.widget<PageView>(find.byType(PageView));
    return pageView.controller?.page;
  }

  testWidgets('shows the first banner, with its service and business', (
    tester,
  ) async {
    await pump(tester, [listing(1), listing(2), listing(3)]);

    expect(find.text('Service 1'), findsOneWidget);
    expect(find.text('Business 1'), findsOneWidget);
    expect(centredPage(tester), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('moves itself on after five seconds', (tester) async {
    await pump(tester, [listing(1), listing(2), listing(3)]);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(centredPage(tester), 1);
  });

  testWidgets('and keeps going, one every five seconds', (tester) async {
    await pump(tester, [listing(1), listing(2), listing(3)]);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(centredPage(tester), 2);
  });

  testWidgets('comes back round to the first after the last', (tester) async {
    await pump(tester, [listing(1), listing(2)]);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(centredPage(tester), 1);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(centredPage(tester), 0);
  });

  testWidgets('does not move before its five seconds are up', (tester) async {
    // A strip that changed under somebody mid-read would be worse than one that never moved.
    await pump(tester, [listing(1), listing(2)]);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(centredPage(tester), 0);
  });

  testWidgets('a single banner never scrolls', (tester) async {
    // One banner has nowhere to go, and a timer firing against it would only burn battery.
    await pump(tester, [listing(1)]);

    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();

    expect(centredPage(tester), 0);
    expect(find.text('Service 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stops when the screen goes away', (tester) async {
    // The test fails on a pending timer at teardown, which is exactly the leak worth catching: the
    // customer shell disposes this tab every time they open Bookings.
    await pump(tester, [listing(1), listing(2), listing(3)]);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );
    await tester.pump(const Duration(seconds: 10));

    expect(tester.takeException(), isNull);
  });

  testWidgets('no banners means no strip at all', (tester) async {
    await pump(tester, []);

    expect(find.byType(PageView), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
