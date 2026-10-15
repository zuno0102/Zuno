import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/worker/domain/entities/hiring_business.dart';
import 'package:zuno/shared/domain/business_trust.dart';
import 'package:zuno/features/worker/presentation/providers/worker_providers.dart';
import 'package:zuno/features/worker/presentation/screens/hiring_business_screen.dart';

/// "Open jobs right now", on a business's page as a worker sees it.
///
/// The list used to be plain rows with no tap: a worker could see that a business had four jobs
/// open, with pay and dates, and had no way to take any of them — applying meant going back to Find
/// work and hunting for the same job in the feed. Each row now opens the same details sheet the feed
/// and the map pins open, Apply included, and carries the two facts the feed card leads with: how
/// far away the job is, and where.
HiringPost _post({
  required String title,
  double? distanceKm,
  String? location,
  double? latitude,
  double? longitude,
}) => HiringPost(
  id: 'p-$title',
  businessOwnerProfileId: 'b1',
  businessName: 'Boss T',
  title: title,
  description: null,
  eventDate: DateTime.utc(2027, 3, 1, 12),
  location: location,
  latitude: latitude,
  longitude: longitude,
  distanceKm: distanceKm,
  workersNeeded: 2,
  salaryAmount: 700,
  salaryUnit: 'PerEvent',
  status: 'Open',
  confirmedCount: 0,
  filledCount: 0,
  createdDate: DateTime.utc(2026, 10, 1),
);

HiringBusiness _business(List<HiringPost> posts) => HiringBusiness(
  id: 'b1',
  businessName: 'Boss T',
  logoUrl: null,
  city: 'Kollam',
  state: 'Kerala',
  level: 1,
  levelName: 'New',
  isVerified: true,
  pay: const WorkerFacingTrust(
    averageSalary: 700,
    lowestSalary: 500,
    highestSalary: 900,
    salaryUnit: 'PerEvent',
    totalHires: 3,
    crewsPaid: 2,
  ),
  openPosts: posts,
);

Future<void> pump(
  WidgetTester tester,
  HiringBusiness business, {
  String? fromPostId,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hiringBusinessProvider('b1').overrideWith((ref) async => business),
      ],
      child: MaterialApp(
        home: HiringBusinessScreen(businessId: 'b1', fromPostId: fromPostId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('every open job is a row that leads somewhere', (tester) async {
    await pump(
      tester,
      _business([
        _post(title: 'Wedding catering'),
        _post(title: 'Corporate lunch'),
      ]),
    );

    expect(find.text('Wedding catering'), findsOneWidget);
    expect(find.text('Corporate lunch'), findsOneWidget);

    // The tap target, and the chevron that says there is one.
    final rows = find.byType(ListTile);
    expect(rows, findsNWidgets(2));
    for (final row in tester.widgetList<ListTile>(rows)) {
      expect(row.onTap, isNotNull, reason: 'a job a worker cannot open is a job they cannot take');
    }
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
  });

  testWidgets('tapping one opens the details, where Apply is', (tester) async {
    await pump(tester, _business([_post(title: 'Wedding catering')]));

    await tester.tap(find.text('Wedding catering'));
    await tester.pumpAndSettle();

    expect(find.text('Apply for this job'), findsOneWidget);
  });

  group('the job the worker came from', () {
    /// Somebody who opened this page from a job already knows about that job — they are standing in
    /// it. Listing it back wasted the top of the one section that shows what *else* is here, and
    /// tapping it led in a circle: details, about the business, the same job, details again.
    testWidgets('is left out, and the rest are shown', (tester) async {
      await pump(
        tester,
        _business([
          _post(title: 'B service'),
          _post(title: 'C service'),
          _post(title: 'D service'),
        ]),
        fromPostId: 'p-B service',
      );

      expect(find.text('B service'), findsNothing);
      expect(find.text('C service'), findsOneWidget);
      expect(find.text('D service'), findsOneWidget);
    });

    testWidgets('and the heading says so, rather than promising all of them', (
      tester,
    ) async {
      await pump(
        tester,
        _business([_post(title: 'B service'), _post(title: 'C service')]),
        fromPostId: 'p-B service',
      );

      expect(find.text('Other jobs open right now'), findsOneWidget);
      expect(find.text('Open jobs right now'), findsNothing);
    });

    testWidgets('leaves the heading alone when nothing was left out', (
      tester,
    ) async {
      await pump(
        tester,
        _business([_post(title: 'B service'), _post(title: 'C service')]),
      );

      expect(find.text('Open jobs right now'), findsOneWidget);
    });

    testWidgets('the section goes entirely when it was the only job', (
      tester,
    ) async {
      await pump(
        tester,
        _business([_post(title: 'B service')]),
        fromPostId: 'p-B service',
      );

      // An empty "other jobs" list says nothing worth a heading.
      expect(find.textContaining('jobs open right now'), findsNothing);
      expect(find.text('Open jobs right now'), findsNothing);
      expect(find.byType(ListTile), findsNothing);
    });
  });

  group('how far away it is', () {
    testWidgets('is shown with the place when the worker has a location', (
      tester,
    ) async {
      await pump(
        tester,
        _business([
          _post(
            title: 'Wedding catering',
            distanceKm: 12.4,
            location: 'Nila nagar',
            latitude: 8.9,
            longitude: 76.6,
          ),
        ]),
      );

      // Rounded past 10 km, as everywhere else: nobody chooses between 12.4 and 12.
      expect(find.textContaining('12 km away'), findsOneWidget);
      expect(find.textContaining('Nila nagar'), findsOneWidget);
    });

    testWidgets('is left out rather than guessed at when there is none', (
      tester,
    ) async {
      await pump(
        tester,
        _business([_post(title: 'Wedding catering', location: 'Nila nagar')]),
      );

      expect(find.textContaining('km'), findsNothing);
      // The place still shows: it is what the business typed, and needs no position to be true.
      expect(find.textContaining('Nila nagar'), findsOneWidget);
    });

    testWidgets('a job with no location at all shows no place line', (
      tester,
    ) async {
      await pump(tester, _business([_post(title: 'Wedding catering')]));

      expect(find.byIcon(Icons.place_outlined), findsNothing);
    });
  });
}
