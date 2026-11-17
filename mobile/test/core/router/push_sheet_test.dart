import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zuno/core/router/push_screen.dart';
import 'package:zuno/shared/widgets/sheet_drag_handle.dart';

/// A sheet with something unsaved until [dirty] is false: it asks before it goes, by Back, a tap
/// outside, its handle, or the router taking it away (the browser's back button).
class _Sheet extends StatefulWidget {
  const _Sheet({required this.answer});

  /// What the "Discard?" question answers.
  final bool answer;

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  bool dirty = true;
  int asked = 0;

  Future<bool> _mayLeave() async {
    if (!dirty) return true;
    asked++;
    return widget.answer;
  }

  @override
  void initState() {
    super.initState();
    SheetLeaveGuard.watch(widget, _mayLeave);
  }

  @override
  void dispose() {
    SheetLeaveGuard.forget(widget);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop) return;
      final navigator = Navigator.of(context);
      if (await _mayLeave()) {
        dirty = false;
        navigator.pop();
      }
    },
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetDragHandle(onDismiss: () => Navigator.maybePop(context)),
        const SizedBox(height: 200, child: Text('The sheet')),
      ],
    ),
  );
}

void main() {
  late GoRouter router;

  Future<void> pump(WidgetTester tester) async {
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      pushSheet<void>(context, _Sheet(answer: _answer)),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/sheet',
          onExit: (context, state) => SheetLeaveGuard.mayLeave(state.extra),
          pageBuilder: (context, state) => SheetPage<Object?>(
            key: state.pageKey,
            child: state.extra! as Widget,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('The sheet'), findsOneWidget);
  }

  setUp(() => _answer = true);

  testWidgets('the sheet is a page of its own: Back closes it, not the app', (
    tester,
  ) async {
    await pump(tester);
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      '/sheet',
      reason: 'the browser gets a history entry for it',
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('The sheet'), findsNothing);
    expect(find.text('Open'), findsOneWidget, reason: 'still in the app');
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      '/',
    );
  });

  testWidgets('with something unsaved, Back asks; Keep editing stays', (
    tester,
  ) async {
    _answer = false;
    await pump(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('The sheet'), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      '/sheet',
    );
  });

  testWidgets('the router taking it away asks too (the web back button)', (
    tester,
  ) async {
    _answer = false;
    await pump(tester);

    router.go('/');
    await tester.pumpAndSettle();

    expect(find.text('The sheet'), findsOneWidget, reason: 'Keep editing');

    _answer = true;
    // A fresh question now answers Discard.
    final state = tester.state<_SheetState>(find.byType(_Sheet));
    expect(state.asked, greaterThan(0));
  });

  testWidgets('pulling the handle down closes it, asking first', (
    tester,
  ) async {
    _answer = false;
    await pump(tester);

    await tester.drag(
      find.byKey(const ValueKey('sheet-drag-handle')),
      const Offset(0, 120),
    );
    await tester.pumpAndSettle();
    expect(find.text('The sheet'), findsOneWidget, reason: 'Keep editing');
    expect(tester.state<_SheetState>(find.byType(_Sheet)).asked, 1);

    tester.state<_SheetState>(find.byType(_Sheet)).dirty = false;
    await tester.drag(
      find.byKey(const ValueKey('sheet-drag-handle')),
      const Offset(0, 120),
    );
    await tester.pumpAndSettle();
    expect(find.text('The sheet'), findsNothing);
  });

  testWidgets('a short nudge of the handle does not close it', (tester) async {
    await pump(tester);
    tester.state<_SheetState>(find.byType(_Sheet)).dirty = false;

    await tester.drag(
      find.byKey(const ValueKey('sheet-drag-handle')),
      const Offset(0, 10),
    );
    await tester.pumpAndSettle();

    expect(find.text('The sheet'), findsOneWidget);
  });
}

bool _answer = true;
