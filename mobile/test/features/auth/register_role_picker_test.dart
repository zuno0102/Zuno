import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/theme/app_theme.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/auth/presentation/providers/auth_state.dart';
import 'package:zuno/features/auth/presentation/screens/register_screen.dart';

/// "I am a…" on sign-up: the chosen role is shown by its fill alone. A tick beside it took enough
/// room to break "Business" over two lines on a phone.
class _SignedOut extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState.unauthenticated();
}

void main() {
  Future<void> pump(WidgetTester tester, Size size, ThemeData theme) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith(_SignedOut.new)],
        child: MaterialApp(theme: theme, home: const RegisterScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// One line of the label: its height is a single line of its own text.
  void expectOneLine(WidgetTester tester, String label) {
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byType(SegmentedButton<String>),
        matching: find.text(label),
      ),
    );
    final lineHeight = paragraph.getFullHeightForCaret(
      const TextPosition(offset: 0),
    );
    expect(
      paragraph.size.height,
      lessThan(lineHeight * 1.5),
      reason: '"$label" must stay on one line',
    );
  }

  for (final (name, size) in [
    ('360dp phone', const Size(360, 780)),
    ('320dp small phone', const Size(320, 700)),
  ]) {
    for (final (mode, theme) in [
      ('light', AppTheme.light),
      ('dark', AppTheme.dark),
    ]) {
      testWidgets('$name, $mode: no tick, every role on one line', (
        tester,
      ) async {
        await pump(tester, size, theme);

        final labels = tester
            .widgetList<Text>(
              find.descendant(
                of: find.byType(SegmentedButton<String>),
                matching: find.byType(Text),
              ),
            )
            .map((t) => t.data!)
            .toList();
        expect(labels, hasLength(3));

        for (final label in labels) {
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();

          expect(
            find.descendant(
              of: find.byType(SegmentedButton<String>),
              matching: find.byIcon(Icons.check),
            ),
            findsNothing,
            reason: 'the chosen role is shown by its fill, not a tick',
          );
          for (final each in labels) {
            expectOneLine(tester, each);
          }
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('choosing a role still switches it', (tester) async {
    await pump(tester, const Size(360, 780), AppTheme.light);
    final picker = find.byType(SegmentedButton<String>);

    final before = tester.widget<SegmentedButton<String>>(picker).selected;
    final business = tester
        .widgetList<Text>(
          find.descendant(of: picker, matching: find.byType(Text)),
        )
        .map((t) => t.data!)
        .firstWhere((l) => l.startsWith('Busin'));
    await tester.tap(find.text(business));
    await tester.pumpAndSettle();

    final after = tester.widget<SegmentedButton<String>>(picker).selected;
    expect(after, isNot(before));
    expect(after, {'BusinessOwner'});
  });
}
