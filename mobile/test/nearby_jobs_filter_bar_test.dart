import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/location/location_service.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/theme/app_theme.dart';
import 'package:zuno/features/worker/presentation/providers/worker_job_filter_provider.dart';
import 'package:zuno/features/worker/presentation/widgets/nearby_jobs_filter_bar.dart';

/// The distance filter: one line above the jobs, with the choices behind a tap.
///
/// Two earlier versions of this control failed on screen and both are pinned here. The first used
/// `ChoiceChip`, which the app's global `chipTheme` renders without a border and at 11.5px — pale
/// rectangles a worker could not see. The second spread nine buttons over two rows and ate the top of
/// the feed. So these tests assert the two things that matter: the bar stays one row, and everything
/// on it is legible under the worker's own theme.
class _FakeLocationService implements LocationService {
  _FakeLocationService(this._result);

  final LocationResult _result;
  int openSettingsCalls = 0;

  @override
  Future<LocationResult> current() async => _result;

  @override
  Future<void> openSettings() async => openSettingsCalls++;

  int openLocationSettingsCalls = 0;

  @override
  Future<void> openLocationSettings() async => openLocationSettingsCalls++;
}

void main() {
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester, {
    LocationResult? location,
    double? latitude,
    double? longitude,
    int? radiusKm,
    bool isApproximate = false,
  }) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    container = ProviderContainer(
      overrides: [
        locationServiceProvider.overrideWithValue(
          _FakeLocationService(
            location ??
                const LocationResult.unavailable(LocationProblem.denied),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    if (latitude != null && longitude != null) {
      container.read(workerJobFilterProvider.notifier).setPosition(
        latitude: latitude,
        longitude: longitude,
        placeLabel: isApproximate
            ? 'Near your last known location'
            : 'Your current location',
        isApproximate: isApproximate,
      );
      if (radiusKm != null) {
        container.read(workerJobFilterProvider.notifier).setRadius(radiusKm);
      }
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          // The worker's own theme, because that is where the contrast problem lived.
          theme: AppTheme.forRole(ZunoRole.worker, Brightness.light),
          home: Scaffold(
            body: NearbyJobsFilterBar(showingMap: false, onToggleMap: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('before a location is known', () {
    testWidgets('shows one clear action and nothing else', (tester) async {
      await pump(tester);

      expect(find.text('Jobs near me'), findsOneWidget);
      // No distance control until there is a position to measure from.
      expect(find.textContaining('Within'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('that action is a filled button, not a faint text link', (
      tester,
    ) async {
      await pump(tester);

      expect(find.byType(FilledButton), findsOneWidget);
    });
  });

  group('once located', () {
    testWidgets('the bar is a single compact row', (tester) async {
      // The regression that prompted this rewrite: nine buttons over two rows pushed the jobs down
      // the screen. One pill, one location line, one map toggle.
      await pump(tester, latitude: 8.5686, longitude: 76.8742, radiusKm: 15);

      expect(find.text('Within 15 km'), findsOneWidget);
      expect(find.text('Your current location'), findsOneWidget);

      // Nothing is laid out as a grid of distance buttons any more.
      expect(find.byType(Wrap), findsNothing);
      expect(find.text('5 km'), findsNothing);
      expect(find.text('200 km'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the whole bar fits in one row of sensible height', (
      tester,
    ) async {
      await pump(tester, latitude: 8.5686, longitude: 76.8742, radiusKm: 15);

      final barHeight = tester
          .getSize(find.byType(NearbyJobsFilterBar))
          .height;

      // One 42px control plus its padding. Two rows of buttons was about 110.
      expect(barHeight, lessThan(70));
    });

    testWidgets('the distance pill is a real tap target', (tester) async {
      await pump(tester, latitude: 8.5686, longitude: 76.8742, radiusKm: 15);

      final size = tester.getSize(
        find
            .ancestor(
              of: find.text('Within 15 km'),
              matching: find.byType(Container),
            )
            .first,
      );

      expect(size.height, greaterThanOrEqualTo(42));
    });

    testWidgets('says so when the fix is only approximate', (tester) async {
      // A stale or coarse position must not be presented as a live one.
      await pump(
        tester,
        latitude: 8.5686,
        longitude: 76.8742,
        radiusKm: 15,
        isApproximate: true,
      );

      expect(find.textContaining('approximate'), findsOneWidget);
    });

    testWidgets('reads "Anywhere" when no radius is set', (tester) async {
      await pump(tester, latitude: 8.5686, longitude: 76.8742);
      container.read(workerJobFilterProvider.notifier).setRadius(15);
      await tester.pumpAndSettle();

      // setPosition defaults to 15km, so clearing is what produces Anywhere.
      container.read(workerJobFilterProvider.notifier).clear();
      await tester.pumpAndSettle();

      expect(find.text('Jobs near me'), findsOneWidget);
    });
  });

  group('the distance sheet', () {
    testWidgets('lists every step with the current one ticked', (tester) async {
      await pump(tester, latitude: 8.5686, longitude: 76.8742, radiusKm: 15);

      await tester.tap(find.text('Within 15 km'));
      await tester.pumpAndSettle();

      expect(find.text('How far will you travel?'), findsOneWidget);
      for (final km in WorkerJobFilterNotifier.radiusSteps) {
        // skipOffstage: false because the sheet scrolls — the longest distances sit below the fold
        // and are built but not painted. They exist and are reachable, which is what matters.
        expect(
          find.text('Within $km km', skipOffstage: false),
          findsWidgets,
          reason: '$km km should be offered',
        );
      }
      expect(find.text('Anywhere', skipOffstage: false), findsOneWidget);
      // The current choice is unmistakable rather than a subtle tint.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('says once that distances are straight-line', (tester) async {
      // Stated here rather than on every card. Road distance in Kerala runs meaningfully further.
      await pump(tester, latitude: 8.5686, longitude: 76.8742, radiusKm: 15);

      await tester.tap(find.text('Within 15 km'));
      await tester.pumpAndSettle();

      expect(find.textContaining('straight line'), findsOneWidget);
    });

    testWidgets('choosing a distance applies it', (tester) async {
      await pump(tester, latitude: 8.5686, longitude: 76.8742, radiusKm: 15);

      await tester.tap(find.text('Within 15 km'));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('Within 50 km').last,
        find.byType(ListView).last,
        const Offset(0, -60),
      );
      await tester.tap(find.text('Within 50 km').last);
      await tester.pumpAndSettle();

      expect(container.read(workerJobFilterProvider).radiusKm, 50);
      expect(find.text('Within 50 km'), findsOneWidget);
    });

    testWidgets('choosing Anywhere drops the radius but keeps the position', (
      tester,
    ) async {
      await pump(tester, latitude: 8.5686, longitude: 76.8742, radiusKm: 15);

      await tester.tap(find.text('Within 15 km'));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('Anywhere'),
        find.byType(ListView).last,
        const Offset(0, -60),
      );
      await tester.tap(find.text('Anywhere'));
      await tester.pumpAndSettle();

      // "Anywhere" means no limit on distance, not "forget where I am". It used to mean the second,
      // which threw the position away and bounced the worker back to the location prompt — so this
      // pins the position surviving, which is the whole point of the option.
      expect(container.read(workerJobFilterProvider).radiusKm, isNull);
      expect(container.read(workerJobFilterProvider).hasPosition, isTrue);
      expect(container.read(workerJobFilterProvider).placeLabel, isNotNull);
    });

    testWidgets('dismissing it changes nothing', (tester) async {
      await pump(tester, latitude: 8.5686, longitude: 76.8742, radiusKm: 15);

      await tester.tap(find.text('Within 15 km'));
      await tester.pumpAndSettle();
      // Tap the scrim above the sheet.
      await tester.tapAt(const Offset(180, 40));
      await tester.pumpAndSettle();

      expect(container.read(workerJobFilterProvider).radiusKm, 15);
    });
  });

  group('clearing the location', () {
    testWidgets('is offered once a location is set', (tester) async {
      // There must always be a way back. Fixing "Anywhere" to keep the position once left nothing
      // able to clear it at all, which stranded a worker on a place they had picked by mistake.
      await pump(tester, latitude: 8.5686, longitude: 76.8742, radiusKm: 2);

      await tester.tap(find.text('Your current location'));
      await tester.pumpAndSettle();

      expect(find.text('Clear my location'), findsOneWidget);
    });

    testWidgets('is not offered before one is set', (tester) async {
      // Nothing to undo, so the control would never do anything.
      await pump(tester);

      await tester.tap(find.text('Enter'));
      await tester.pumpAndSettle();

      expect(find.text('Clear my location'), findsNothing);
    });

    testWidgets('actually clears it', (tester) async {
      await pump(tester, latitude: 8.5686, longitude: 76.8742, radiusKm: 2);

      await tester.tap(find.text('Your current location'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear my location'));
      await tester.pumpAndSettle();

      expect(container.read(workerJobFilterProvider).hasPosition, isFalse);
      expect(container.read(workerJobFilterProvider).radiusKm, isNull);
      // Back to the invitation, so the feature can be started again.
      expect(find.text('Jobs near me'), findsOneWidget);
    });
  });
}
