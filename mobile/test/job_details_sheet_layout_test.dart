import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/worker/presentation/widgets/job_details_sheet.dart';

/// The job details sheet, and the one control that has to be on screen when it opens.
///
/// It used to open at 70% of the screen with everything in a single scroll, so on a normal phone the
/// Apply button sat below the fold: the sheet whose whole job is to let somebody take the work
/// opened without the way to take it. The button is pinned below the scroll now, so it is there on
/// open and stays there however long the description runs.
HiringPost _post({String? description, bool applied = false}) => HiringPost(
  id: 'p1',
  businessOwnerProfileId: 'b1',
  businessName: 'Test Owner',
  title: 'NEARBY D - Varkala cliff catering',
  description: description,
  eventDate: DateTime.now().add(const Duration(days: 20)),
  location: 'Varkala cliff',
  latitude: 8.73,
  longitude: 76.71,
  distanceKm: 34,
  workersNeeded: 3,
  salaryAmount: 900,
  salaryUnit: 'PerEvent',
  status: 'Open',
  confirmedCount: 0,
  filledCount: 0,
  createdDate: DateTime.now().subtract(const Duration(days: 2)),
  myApplicationStatus: applied ? 'Applied' : null,
);

Future<void> openSheet(WidgetTester tester, HiringPost job) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showJobDetailsSheet(context, job: job),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Whether a widget's box sits fully inside the phone screen.
bool isOnScreen(WidgetTester tester, Finder finder) {
  final box = tester.getRect(finder);
  final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
  return box.top >= 0 && box.bottom <= screen.height;
}

void main() {
  testWidgets('Apply is on screen the moment the sheet opens', (tester) async {
    await openSheet(tester, _post());

    final apply = find.widgetWithText(FilledButton, 'Apply for this job');
    expect(apply, findsOneWidget);
    expect(
      isOnScreen(tester, apply),
      isTrue,
      reason: 'a worker should not have to drag the sheet to find the way to take the job',
    );
  });

  testWidgets('and stays on screen under a long description', (tester) async {
    await openSheet(
      tester,
      _post(
        description: List.filled(
          60,
          'Seeded test post for the nearby-jobs radius filter.',
        ).join(' '),
      ),
    );

    final apply = find.widgetWithText(FilledButton, 'Apply for this job');
    expect(isOnScreen(tester, apply), isTrue);

    // The detail above it still scrolls, so nothing is lost to the pinned footer.
    await tester.drag(find.text('About the work'), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(isOnScreen(tester, apply), isTrue);
  });

  testWidgets('the details are all there to read', (tester) async {
    await openSheet(tester, _post());

    // What a worker sees without touching anything: the job, the pay, where and how far.
    expect(find.text('NEARBY D - Varkala cliff catering'), findsOneWidget);
    expect(find.textContaining('900'), findsWidgets);
    expect(find.text('Varkala cliff'), findsOneWidget);
    expect(find.text('34 km away'), findsOneWidget);

    // The rest is a scroll away. The list builds lazily, so these are not merely off screen —
    // they do not exist until scrolled to, which is why the finder has to scroll.
    await tester.drag(find.text('Varkala cliff'), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('See it on the map'), findsOneWidget);

    await tester.drag(find.text('See it on the map'), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(find.text('About Test Owner'), findsOneWidget);
  });

  testWidgets('somebody who already applied sees that, in Apply\'s place', (
    tester,
  ) async {
    await openSheet(tester, _post(applied: true));

    expect(find.text('You have applied'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Apply for this job'), findsNothing);
  });
}
