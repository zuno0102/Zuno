import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/business_owner/domain/entities/business_service.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_services_notifier.dart';
import 'package:zuno/features/business_owner/presentation/screens/dashboard_detail_screens.dart';

/// The page behind the home screen's Active services and Inactive services tiles.
///
/// It exists because those two tiles used to open the Services tab, which lists everything — so a
/// tile reading 7 and a tile reading 3 landed on the same page of 10. The whole job of this screen
/// is that what it lists matches the tile that opened it, so that is what these check.
class _FakeServices extends BusinessServicesNotifier {
  _FakeServices(this._services);

  final List<BusinessService> _services;

  @override
  Future<List<BusinessService>> build() async => _services;
}

void main() {
  BusinessService service(String name, {required bool isActive}) =>
      BusinessService(
        id: 'svc-${name.hashCode}',
        serviceCategoryId: 'cat-1',
        serviceCategoryName: 'Cleaning',
        name: name,
        priceType: 'Daily',
        price: 1400,
        isActive: isActive,
      );

  final mixed = [
    service('Deep home cleaning', isActive: true),
    service('Office cleaning', isActive: true),
    service('Carpet shampoo', isActive: false),
  ];

  Future<void> pump(
    WidgetTester tester, {
    required bool active,
    required List<BusinessService> services,
    String? title,
  }) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessServicesProvider.overrideWith(() => _FakeServices(services)),
        ],
        child: MaterialApp(
          home: BusinessServiceListScreen(
            title: title ?? (active ? 'Active services' : 'Inactive services'),
            active: active,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the active page lists only what customers can find', (
    tester,
  ) async {
    await pump(tester, active: true, services: mixed);

    expect(find.text('Deep home cleaning'), findsOneWidget);
    expect(find.text('Office cleaning'), findsOneWidget);
    expect(find.text('Carpet shampoo'), findsNothing);
  });

  testWidgets('and the inactive page is its mirror', (tester) async {
    await pump(tester, active: false, services: mixed);

    expect(find.text('Carpet shampoo'), findsOneWidget);
    expect(find.text('Deep home cleaning'), findsNothing);
    expect(find.text('Office cleaning'), findsNothing);
  });

  /// The two pages are the same screen, so the title is the only thing naming which half you are
  /// looking at — and it is handed in by the tile that opened it.
  testWidgets('the page is named by the tile that opened it', (tester) async {
    await pump(
      tester,
      active: false,
      services: mixed,
      title: 'Inactive services',
    );

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Inactive services'),
      ),
      findsOneWidget,
    );
  });

  /// Tapping a tile that reads 0 is exactly how somebody finds out what it means. A blank page
  /// would answer nothing, and the two sides do not mean the same thing: nothing switched off is
  /// good news, nothing live is not.
  testWidgets('nothing switched off says so rather than showing a blank', (
    tester,
  ) async {
    await pump(
      tester,
      active: false,
      services: [service('Deep home cleaning', isActive: true)],
    );

    expect(find.text('Nothing switched off'), findsOneWidget);
  });

  testWidgets('and nothing live says something different', (tester) async {
    await pump(
      tester,
      active: true,
      services: [service('Carpet shampoo', isActive: false)],
    );

    expect(find.text('Nothing live for customers'), findsOneWidget);
  });

  /// This list is a row of cards inside a column whose height is unbounded, which is the shape
  /// that has blanked screens in this app before.
  testWidgets('a full page lays out without overflowing', (tester) async {
    await pump(tester, active: true, services: mixed);

    expect(tester.takeException(), isNull);
  });
}
