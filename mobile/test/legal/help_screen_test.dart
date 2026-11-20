import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/theme/app_theme.dart';
import 'package:zuno/shared/legal/help_screen.dart';
import 'package:zuno/shared/legal/legal_document.dart';

/// Help and support: topics from the `##` headings, questions from the `###` headings, each answer
/// folded away until tapped, and a way to write to us only once there is an address to write to.
void main() {
  const sample = '''
# Help and support

Answers to common questions.

## Account

### I forgot my password

Write to us from the email on your account.

- Or change it in Profile.

## Marketplace

### Where is my order?

Open My orders.
''';

  test('the page is read into an intro, topics, questions and answers', () {
    final help = HelpContent.parse(sample);

    expect(help.intro.single.text, 'Answers to common questions.');
    expect([for (final t in help.topics) t.title], ['Account', 'Marketplace']);
    final q = help.topics.first.questions.single;
    expect(q.question, 'I forgot my password');
    expect(q.answer.first, isA<LegalParagraph>());
    expect(q.answer.last, isA<LegalBullet>());
  });

  test("the app's own help file gives topics with questions in each", () {
    final help = HelpContent.parse(
      File(LegalDoc.help.asset).readAsStringSync(),
    );
    expect(help.topics, isNotEmpty);
    for (final topic in help.topics) {
      expect(topic.questions, isNotEmpty, reason: topic.title);
    }
  });

  Future<void> pump(WidgetTester tester, {required String email}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: HelpView(help: HelpContent.parse(sample), email: email),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an answer shows only once its question is tapped', (
    tester,
  ) async {
    await pump(tester, email: 'help@zuno.example');

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Open My orders.'), findsNothing);
    await tester.tap(find.text('Where is my order?'));
    await tester.pumpAndSettle();
    expect(find.text('Open My orders.'), findsOneWidget);
  });

  testWidgets('with an address, it offers to email us', (tester) async {
    await pump(tester, email: 'help@zuno.example');

    expect(find.byKey(const ValueKey('help-email')), findsOneWidget);
    expect(find.text('Email help@zuno.example'), findsOneWidget);
  });

  testWidgets('without one, no button that goes nowhere', (tester) async {
    await pump(tester, email: '');

    expect(find.byKey(const ValueKey('help-email')), findsNothing);
    expect(find.textContaining('will be added here soon'), findsOneWidget);
  });
}
