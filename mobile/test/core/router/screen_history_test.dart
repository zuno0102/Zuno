import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zuno/core/router/app_router.dart';
import 'package:zuno/core/router/push_screen.dart';

/// The web app's back button: the browser hands back a saved history entry, and the router must
/// rebuild the page from it. A pushed screen used to come back empty — `extra!` threw and the web
/// app showed a grey page on almost every back.
void main() {
  GoRouter router() => GoRouter(
    extraCodec: const ScreenExtraCodec(),
    routes: [
      GoRoute(path: '/', builder: (_, _) => const _Page('Home')),
      GoRoute(
        path: '/screen',
        builder: (_, state) => switch (state.extra) {
          final Widget screen => screen,
          _ => const _Page('Home (screen not found)'),
        },
      ),
    ],
  );

  /// What the browser keeps for the page on show now.
  RouteInformation saved(GoRouter router) => router.routeInformationParser
      .restoreRouteInformation(router.routerDelegate.currentConfiguration)!;

  /// The browser's back button: the saved entry is handed back and rebuilt from.
  Future<void> browserBack(
    WidgetTester tester,
    GoRouter router,
    RouteInformation entry,
  ) async {
    final context = tester.element(find.byType(Navigator).first);
    final parsed = await router.routeInformationParser
        .parseRouteInformationWithDependencies(entry, context);
    await router.routerDelegate.setNewRoutePath(parsed);
    await tester.pumpAndSettle();
  }

  testWidgets('back to a pushed screen shows that screen, not a grey page', (
    tester,
  ) async {
    final r = router();
    addTearDown(r.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: r));

    final home = tester.element(find.text('Home'));
    pushScreen<void>(home, const _Page('Orders'));
    await tester.pumpAndSettle();
    final ordersEntry = saved(r);

    pushScreen<void>(
      tester.element(find.text('Orders')),
      const _Page('Order 12'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Order 12'), findsOneWidget);

    await browserBack(tester, r, ordersEntry);

    expect(tester.takeException(), isNull);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Order 12'), findsNothing);
  });

  testWidgets(
    'an entry whose screen is gone (page reloaded) goes home, no crash',
    (tester) async {
      final r = router();
      addTearDown(r.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: r));

      // An entry as a reloaded page would hand back: a number nothing is kept under.
      final entry = RouteInformation(
        uri: Uri.parse('/screen'),
        state: {
          'location': '/screen',
          'state': {
            'codec': 'custom',
            'encoded': {'screen': -1},
          },
        },
      );
      await browserBack(tester, r, entry);

      expect(tester.takeException(), isNull);
      expect(find.text('Home (screen not found)'), findsOneWidget);
    },
  );

  test('a screen is kept under one number, and only the newest are kept', () {
    const codec = ScreenExtraCodec();
    const screen = _Page('Orders');

    final number = codec.encode(screen);
    expect(codec.encode(screen), number, reason: 'written twice, one number');
    expect(identical(codec.decode(number), screen), isTrue);
    expect(codec.decode({'screen': -1}), isNull);
    expect(codec.encode('not a screen'), isNull);

    for (var i = 0; i < 150; i++) {
      codec.encode(_Page('page $i'));
    }
    expect(ScreenExtraCodec.remembered, lessThanOrEqualTo(100));
    expect(codec.decode(number), isNull, reason: 'the oldest is forgotten');
  });
}

class _Page extends StatelessWidget {
  const _Page(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(title));
}
