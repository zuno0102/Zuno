import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/theme/app_theme.dart';
import 'package:zuno/shared/widgets/stop_hiring_button.dart';

/// "Stop hiring" on hire posts and full-time jobs: bordered, in the primary colour — not red.
void main() {
  Future<void> pump(
    WidgetTester tester,
    ThemeData theme, {
    VoidCallback? onPressed,
    bool isStopping = false,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Center(
          child: StopHiringButton(onPressed: onPressed, isStopping: isStopping),
        ),
      ),
    ),
  );

  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    testWidgets('text, icon and border are the primary colour ($name)', (
      tester,
    ) async {
      await pump(tester, theme, onPressed: () {});
      final scheme = theme.colorScheme;
      final style = tester
          .widget<OutlinedButton>(find.byType(OutlinedButton))
          .style!;
      const on = <WidgetState>{};

      expect(style.foregroundColor!.resolve(on), scheme.primary);
      expect(style.side!.resolve(on)!.color, scheme.primary);
      expect(style.foregroundColor!.resolve(on), isNot(scheme.error));
      expect(
        tester.widget<Icon>(find.byIcon(Icons.front_hand_outlined)).color ??
            IconTheme.of(
              tester.element(find.byIcon(Icons.front_hand_outlined)),
            ).color,
        scheme.primary,
      );
    });
  }

  testWidgets('tapping it calls back', (tester) async {
    var taps = 0;
    await pump(tester, AppTheme.light, onPressed: () => taps++);
    await tester.tap(find.text('Stop hiring'));
    expect(taps, 1);
  });

  testWidgets('while stopping it is off and says so', (tester) async {
    var taps = 0;
    await pump(
      tester,
      AppTheme.light,
      onPressed: () => taps++,
      isStopping: true,
    );
    expect(find.text('Stopping…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Stopping…'));
    expect(taps, 0);
  });
}
