import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_hiring_posts_tab.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post_application.dart';
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
    int applicants = 0,
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
    applications: [
      for (var i = 0; i < applicants; i++)
        HiringPostApplication(
          id: 'ap-$i',
          workerProfileId: 'w-$i',
          workerName: 'Applicant $i',
          status: 'Applied',
          appliedAt: DateTime(2026, 10, 1),
        ),
    ],
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

  // Changed: a full post with nobody waiting used to offer Stop hiring too, though stopping it
  // changed nothing. The button is now only there when there is something to stop.
  for (final (filled, needed) in [(1, 1), (4, 4)]) {
    testWidgets('$filled/$needed hired, nobody waiting: no Stop hiring', (
      tester,
    ) async {
      await pump(tester, post(filled: filled, needed: needed));

      expect(find.text('Work on 30 Oct 2026'), findsOneWidget);
      expect(stopButton, findsNothing);
      expect(find.byIcon(Icons.info_outline), findsNothing);
    });
  }

  // A full post with somebody still waiting: the server refuses that offer or applicant
  // ("all places filled"), so stopping would change nothing either.
  for (final (label, full) in [
    (
      '2/2 hired, an offer still unanswered',
      post(filled: 2, needed: 2, pendingOffers: 1),
    ),
    ('3/3 hired, 2 people applied', post(filled: 3, needed: 3, applicants: 2)),
  ]) {
    testWidgets('$label: no Stop hiring', (tester) async {
      await pump(tester, full);

      expect(stopButton, findsNothing);
    });
  }

  // The example from the business: 3 needed, 1 accepted, 2 applied but not yet confirmed.
  testWidgets('1 accepted + 2 only applied reads 1/3, with Stop hiring', (
    tester,
  ) async {
    await pump(tester, post(filled: 1, needed: 3, applicants: 2));

    expect(find.textContaining('1/3 hired'), findsOneWidget);
    expect(stopButton, findsOneWidget);
  });

  testWidgets('after the 2 are confirmed and accept: 3/3, no Stop hiring', (
    tester,
  ) async {
    await pump(tester, post(filled: 3, needed: 3));

    expect(find.textContaining('3/3 hired'), findsOneWidget);
    expect(stopButton, findsNothing);
  });

  testWidgets('1/2 hired, one applicant: both sentences of what stops', (
    tester,
  ) async {
    await pump(tester, post(filled: 1, needed: 2, applicants: 1));
    await openDialog(tester);

    final text = dialogText(tester);
    expect(text, contains('You have 1 of 2 workers.'));
    expect(text, contains('The 1 person who applied will not be taken on.'));
  });

  group('canStopHiring', () {
    for (final (label, p, expected) in [
      ('1/1, nobody waiting', post(filled: 1, needed: 1), false),
      ('1/2', post(filled: 1, needed: 2), true),
      ('0/1, one offer waiting', post(needed: 1, pendingOffers: 1), true),
      // Full: the server refuses whoever is still waiting, so nothing is left to stop.
      (
        '2/2, one offer waiting',
        post(filled: 2, needed: 2, pendingOffers: 1),
        false,
      ),
      ('3/3, two applicants', post(filled: 3, needed: 3, applicants: 2), false),
      ('1/3, two applicants', post(filled: 1, needed: 3, applicants: 2), true),
      (
        '1/2 but already stopped',
        post(filled: 1, needed: 2, hiringStoppedAt: DateTime(2026, 10, 2)),
        false,
      ),
    ]) {
      test('$label -> $expected', () => expect(p.canStopHiring(), expected));
    }
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
