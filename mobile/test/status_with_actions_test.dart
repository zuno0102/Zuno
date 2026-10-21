import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/shared/widgets/status_with_actions.dart';

/// The status-then-actions block every order and job card now shares, so the business, customer
/// and worker see the same layout: status on top, a clear gap, buttons underneath.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(alignment: Alignment.topRight, child: child),
      ),
    ),
  );

  const status = SizedBox(key: Key('status'), width: 80, height: 24);
  Widget button(String tip, IconData icon) =>
      IconButton(tooltip: tip, icon: Icon(icon), onPressed: () {});

  testWidgets('StatusWithActions_WithButtons_LeavesGapUnderTheStatus', (
    tester,
  ) async {
    await pump(
      tester,
      StatusWithActions(status: status, actions: [button('Call', Icons.call)]),
    );

    final top = tester.getRect(find.byKey(const Key('status')));
    final call = tester.getRect(find.byType(IconButton));
    expect(call.top - top.bottom, StatusWithActions.statusGap);
  });

  testWidgets('StatusWithActions_Buttons_AreAtLeastTheMinimumTapTarget', (
    tester,
  ) async {
    await pump(
      tester,
      StatusWithActions(
        status: status,
        actions: [
          button('Message', Icons.chat_bubble_outline),
          button('Call', Icons.call),
        ],
      ),
    );

    for (final size
        in tester
            .widgetList(find.byType(IconButton))
            .map((w) => tester.getSize(find.byWidget(w)))) {
      expect(size.width, greaterThanOrEqualTo(StatusWithActions.minTapTarget));
      expect(size.height, greaterThanOrEqualTo(StatusWithActions.minTapTarget));
    }
  });

  testWidgets('StatusWithActions_TwoButtons_SpacedApartAndRightAligned', (
    tester,
  ) async {
    await pump(
      tester,
      StatusWithActions(
        status: status,
        actions: [
          button('Message', Icons.chat_bubble_outline),
          button('Call', Icons.call),
        ],
      ),
    );

    final message = tester.getRect(find.byTooltip('Message'));
    final call = tester.getRect(find.byTooltip('Call'));
    expect(call.left - message.right, StatusWithActions.actionGap);
    // Right edges line up: the buttons sit under the status, not centred below it.
    expect(call.right, tester.getRect(find.byKey(const Key('status'))).right);
  });

  testWidgets('StatusWithActions_NoButtons_ShowsStatusOnly', (tester) async {
    await pump(tester, StatusWithActions(status: status));

    expect(find.byType(IconButton), findsNothing);
    expect(
      tester.getSize(find.byType(StatusWithActions)).height,
      tester.getSize(find.byKey(const Key('status'))).height,
    );
  });
}
