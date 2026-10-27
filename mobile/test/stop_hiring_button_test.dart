import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_hiring_posts_tab.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/presentation/providers/business_hiring_posts_notifier.dart';

/// Stop hiring on a hire post card.
///
/// It was a bare text link and read as a label, so businesses did not know it was the way to close
/// a post. It is now a bordered button with a line saying what it does, and the confirmation says
/// exactly who stopping affects, since the server cannot undo it.
class _FakePosts extends BusinessHiringPostsNotifier {
  _FakePosts(this._posts, {this.failWith});

  final List<HiringPost> _posts;
  final String? failWith;
  final stopped = <String>[];

  @override
  Future<List<HiringPost>> build() async => _posts;

  /// Like the real notifier: it reloads (showing the spinner meanwhile), and the reloaded list no
  /// longer holds the stopped post, so the card that asked is gone before this returns.
  @override
  Future<void> stopHiring(String id) async {
    if (failWith != null) throw Exception(failWith);
    stopped.add(id);
    state = const AsyncLoading();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    state = AsyncData([
      for (final p in _posts)
        if (p.id != id) p,
    ]);
  }
}

void main() {
  HiringPost post({
    int filled = 0,
    int needed = 1,
    int pendingOffers = 0,
    DateTime? hiringStoppedAt,
  }) => HiringPost(
    id: 'p-1',
    businessOwnerProfileId: 'b-1',
    businessName: 'Test Owner',
    title: 'Work on 30 Oct 2026',
    eventDate: DateTime.now().add(const Duration(days: 3)),
    workersNeeded: needed,
    salaryAmount: 700,
    confirmedCount: filled,
    filledCount: filled,
    pendingOfferCount: pendingOffers,
    hiringStoppedAt: hiringStoppedAt,
    status: 'Open',
    createdDate: DateTime(2026, 10, 1),
  );

  Future<_FakePosts> pump(
    WidgetTester tester,
    HiringPost data, {
    String? failWith,
  }) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final fake = _FakePosts([data], failWith: failWith);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [businessHiringPostsProvider.overrideWith(() => fake)],
        child: const MaterialApp(
          home: Scaffold(body: BusinessHiringPostsTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return fake;
  }

  final stopButton = find.widgetWithText(OutlinedButton, 'Stop hiring');

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(stopButton);
    await tester.pumpAndSettle();
  }

  String dialogText(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Text),
        ),
      )
      .map((t) => t.data ?? '')
      .join('\n');

  testWidgets('looks like a button, with its meaning behind an info icon', (
    tester,
  ) async {
    await pump(tester, post());

    expect(tester.takeException(), isNull);
    expect(stopButton, findsOneWidget);
    expect(
      find.descendant(
        of: stopButton,
        matching: find.byIcon(Icons.front_hand_outlined),
      ),
      findsOneWidget,
    );

    // Hidden until asked for.
    const hint = 'Close this post to new workers';
    expect(find.text(hint), findsNothing);

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(hint), findsOneWidget);

    // Tapping the info icon explains; it never stops hiring.
    expect(find.byType(AlertDialog), findsNothing);

    // And it goes away on its own.
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text(hint), findsNothing);
  });

  testWidgets('sits apart from the hiring details above it', (tester) async {
    await pump(tester, post());

    final salary = tester.getRect(find.text('₹700 per event'));
    final button = tester.getRect(stopButton);

    expect(button.top - salary.bottom, greaterThanOrEqualTo(12));
  });

  testWidgets('nobody hired, one offer waiting: says so plainly', (
    tester,
  ) async {
    // The case from the report: 0 of 1 hired, 1 awaiting reply.
    await pump(tester, post(pendingOffers: 1));
    await openDialog(tester);

    final text = dialogText(tester);
    expect(text, contains('Nobody is hired for this job yet.'));
    expect(
      text,
      contains('The 1 offer still awaiting a reply can no longer be accepted.'),
    );
    expect(text, contains('removed once its time is over'));
    expect(text, contains('This cannot be undone.'));
    // No longer "manage with 0".
    expect(text, isNot(contains('with 0')));
  });

  testWidgets('short of workers: names the crew it will run with', (
    tester,
  ) async {
    await pump(tester, post(filled: 1, needed: 3, pendingOffers: 2));
    await openDialog(tester);

    final text = dialogText(tester);
    expect(text, contains('You have 1 of 3 workers.'));
    expect(text, contains('The 2 offers still awaiting a reply'));
    expect(text, contains('Run the job with 1'));
  });

  testWidgets('fully staffed, no offers: no offer sentence', (tester) async {
    await pump(tester, post(filled: 2, needed: 2));
    await openDialog(tester);

    final text = dialogText(tester);
    expect(text, contains('Everyone you need is hired.'));
    expect(text, isNot(contains('awaiting a reply')));
  });

  testWidgets('Keep hiring leaves the post alone', (tester) async {
    final fake = await pump(tester, post());
    await openDialog(tester);

    await tester.tap(find.text('Keep hiring'));
    await tester.pumpAndSettle();

    expect(fake.stopped, isEmpty);
    expect(stopButton, findsOneWidget);
  });

  testWidgets('confirming stops hiring and says so', (tester) async {
    final fake = await pump(tester, post(filled: 1, needed: 2));
    await openDialog(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Stop hiring'),
      ),
    );
    await tester.pumpAndSettle();

    expect(fake.stopped, ['p-1']);
    // The post has left the list, and the confirmation still shows: it must not depend on the
    // card that asked, which is gone by now.
    expect(stopButton, findsNothing);
    expect(
      find.text('Hiring stopped for Work on 30 Oct 2026.'),
      findsOneWidget,
    );
  });

  testWidgets('a failure is shown and the button works again', (tester) async {
    final fake = await pump(
      tester,
      post(filled: 1, needed: 2),
      failWith: 'Hiring for this job has already been stopped.',
    );
    await openDialog(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Stop hiring'),
      ),
    );
    await tester.pumpAndSettle();

    expect(fake.stopped, isEmpty);
    expect(
      find.text('Hiring for this job has already been stopped.'),
      findsOneWidget,
    );
    final button = tester.widget<OutlinedButton>(stopButton);
    expect(button.onPressed, isNotNull);
  });
}
