import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/worker/presentation/providers/worker_job_filter_provider.dart';
import 'package:zuno/features/worker/presentation/widgets/single_job_map_screen.dart';

/// Setting where the journey starts, from the map itself.
///
/// The map could only draw the way there when it was handed a starting point, which it read from the
/// Find work filter. A worker opening a job they were invited to has usually never been near that
/// filter — so they got a pin on the venue and nothing else, and the only way to fix it was to leave
/// for another tab.
HiringPost _job() => HiringPost(
  id: 'p1',
  businessOwnerProfileId: 'b1',
  businessName: 'Test Owner',
  title: 'NEARBY A - Technopark canteen crew',
  eventDate: DateTime.now().add(const Duration(days: 12)),
  location: 'Technopark Phase 1',
  latitude: 8.5566,
  longitude: 76.8812,
  workersNeeded: 2,
  salaryAmount: 900,
  salaryUnit: 'PerEvent',
  status: 'Open',
  confirmedCount: 0,
  filledCount: 0,
  createdDate: DateTime.now(),
);

Future<void> pump(WidgetTester tester, {LatLng? from}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: SingleJobMapScreen(job: _job(), from: from),
      ),
    ),
  );
  // Pumped by hand: the map fetches tiles and a route, so settling waits on network calls that
  // never come in a test.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('with no starting point', () {
    testWidgets('offers one in words, not only as an icon', (tester) async {
      await pump(tester);

      // An icon alone answers somebody who already knows what is missing. This says what the map
      // cannot show, and offers to fix it.
      expect(find.text('Show the way from where you are'), findsOneWidget);
    });

    testWidgets('and as a control in the bar', (tester) async {
      await pump(tester);

      expect(find.byIcon(Icons.my_location_outlined), findsWidgets);
      expect(find.byTooltip('Show the way from where you are'), findsOneWidget);
    });
  });

  group('with a starting point', () {
    testWidgets('drops the prompt and says where it is measuring from', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workerJobFilterProvider.overrideWith(_FilterWithPosition.new),
          ],
          child: MaterialApp(
            home: SingleJobMapScreen(
              job: _job(),
              from: const LatLng(8.4875, 76.9525),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Show the way from where you are'), findsNothing);
      // A fix that landed in the wrong district would otherwise be invisible.
      expect(find.text('From Thiruvananthapuram'), findsOneWidget);
    });

    testWidgets('still lets it be changed', (tester) async {
      await pump(tester, from: const LatLng(8.4875, 76.9525));

      expect(
        find.byTooltip('Change where you are measuring from'),
        findsOneWidget,
      );
    });

    /// Zooming in is otherwise a one-way door. The map is draggable and pinchable so a worker can
    /// see which turning it is, and without this they are left holding one corner of the route
    /// with no way back to the whole of it but leaving the screen.
    testWidgets('and offers the whole route back', (tester) async {
      await pump(tester, from: const LatLng(8.4875, 76.9525));

      expect(find.byTooltip('Show the whole route'), findsOneWidget);
    });
  });

  // Nothing to frame with one point: the control would promise a journey the map does not have.
  testWidgets('with no starting point there is no route to show', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byTooltip('Show the whole route'), findsNothing);
  });
}

class _FilterWithPosition extends WorkerJobFilterNotifier {
  @override
  WorkerJobFilter build() => const WorkerJobFilter(
    latitude: 8.4875,
    longitude: 76.9525,
    placeLabel: 'Thiruvananthapuram',
    radiusKm: 25,
  );
}
