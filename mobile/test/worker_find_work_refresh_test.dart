import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/location/location_service.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/presentation/providers/worker_hiring_posts_notifier.dart';
import 'package:zuno/features/worker/presentation/providers/worker_job_filter_provider.dart';
import 'package:zuno/features/worker/presentation/screens/worker_hiring_posts_tab.dart';

/// Pulling the Find work list down starts the search over.
///
/// This gesture has been asked for twice, and once implemented the other way round, so it is pinned
/// here: a pull clears the location rather than silently re-running the last search. The screen must
/// end up back at the prompt with nothing remembered, not on an empty list that looks like a failure.
class _FakeLocationService implements LocationService {
  @override
  Future<LocationResult> current() async =>
      const LocationResult.unavailable(LocationProblem.denied);

  @override
  Future<void> openSettings() async {}

  @override
  Future<void> openLocationSettings() async {}
}

class _NoPosts extends WorkerHiringPostsNotifier {
  @override
  Future<List<HiringPost>> build() async => const [];
}

void main() {
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    container = ProviderContainer(
      overrides: [
        locationServiceProvider.overrideWithValue(_FakeLocationService()),
        workerHiringPostsProvider.overrideWith(_NoPosts.new),
      ],
    );
    addTearDown(container.dispose);

    // Already located, which is the only state the list — and so the pull — exists in.
    container.read(workerJobFilterProvider.notifier).setPosition(
      latitude: 8.5686,
      longitude: 76.8742,
      placeLabel: 'Kazhakoottam',
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: WorkerHiringPostsTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('starts out showing the chosen place', (tester) async {
    await pump(tester);

    expect(find.text('Kazhakoottam'), findsOneWidget);
    expect(find.text('Within 2 km'), findsOneWidget);
  });

  testWidgets('a pull down clears the location', (tester) async {
    await pump(tester);

    await tester.fling(find.byType(ListView), const Offset(0, 320), 1200);
    await tester.pumpAndSettle();

    final filter = container.read(workerJobFilterProvider);
    expect(filter.hasPosition, isFalse);
    expect(filter.placeLabel, isNull);
    expect(filter.radiusKm, isNull);
  });

  testWidgets('and puts the screen back at the prompt, saying why', (
    tester,
  ) async {
    await pump(tester);

    await tester.fling(find.byType(ListView), const Offset(0, 320), 1200);
    await tester.pumpAndSettle();

    // The place is gone from the bar and the invitation is back, so the next search starts clean.
    expect(find.text('Kazhakoottam'), findsNothing);
    expect(find.text('Jobs near me'), findsOneWidget);
    expect(find.text('Where are you working from?'), findsOneWidget);

    // An emptied list is otherwise indistinguishable from a load that failed.
    expect(
      find.text('Location cleared. Set where you are to see jobs.'),
      findsOneWidget,
    );
  });
}
