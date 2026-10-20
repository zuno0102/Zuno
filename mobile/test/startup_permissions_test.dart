import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuno/core/location/location_service.dart';
import 'package:zuno/core/permissions/permission_service.dart';
import 'package:zuno/core/permissions/startup_permission_primer.dart';

/// What the app asks the phone for, and when.
///
/// Two rules, and they pull in opposite directions:
///
///   * **the camera is asked for up front.** Every role sets a profile picture and a worker scans a
///     job code, so the system dialog used to arrive mid-task — somebody tapped their own avatar and
///     met a question with no explanation attached.
///   * **location is never asked for up front.** It is the one permission the app can do without:
///     somebody who never opens Find work and never picks a service area never needs it. Asking at
///     launch for something not yet used is how people learn to refuse everything.
class FakePermissionService implements PermissionService {
  FakePermissionService({this.cameraAlreadyGranted = false});

  final bool cameraAlreadyGranted;
  final PermissionSnapshot snapshotValue = const PermissionSnapshot(
    camera: PermissionState.notAsked,
    location: PermissionState.notAsked,
  );

  int essentialsRequested = 0;
  int snapshotsTaken = 0;

  @override
  Future<bool> hasCamera() async => cameraAlreadyGranted;

  @override
  Future<PermissionSnapshot> snapshot() async {
    snapshotsTaken++;
    return snapshotValue;
  }

  @override
  Future<PermissionOutcome> requestEssentials() async {
    essentialsRequested++;
    return const PermissionOutcome(cameraGranted: true, photosGranted: true);
  }

  @override
  Future<void> openAppSettings() async {}
}

/// Counts any attempt to touch location. Nothing at startup may reach this.
class SpyLocationService implements LocationService {
  int asked = 0;

  @override
  Future<LocationResult> current({bool precise = false}) async {
    asked++;
    return const LocationResult.unavailable(LocationProblem.denied);
  }

  @override
  Future<void> openSettings() async {}

  @override
  Future<void> openLocationSettings() async {}
}

Future<FakePermissionService> pumpDashboard(
  WidgetTester tester, {
  bool cameraAlreadyGranted = false,
  SpyLocationService? location,
}) async {
  final permissions = FakePermissionService(
    cameraAlreadyGranted: cameraAlreadyGranted,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        permissionServiceProvider.overrideWithValue(permissions),
        if (location != null) locationServiceProvider.overrideWithValue(location),
      ],
      child: const MaterialApp(
        home: StartupPermissionPrimer(
          child: Scaffold(body: Text('dashboard')),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return permissions;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the first time somebody reaches a dashboard', () {
    testWidgets('the dashboard is on screen behind the question', (
      tester,
    ) async {
      await pumpDashboard(tester);

      // Asked after the first frame, so somebody can see what it is being asked on behalf of.
      expect(find.text('dashboard'), findsOneWidget);
      expect(find.text('Zuno needs your camera'), findsOneWidget);
    });

    testWidgets('it says what the camera is for, and what it is not', (
      tester,
    ) async {
      await pumpDashboard(tester);

      expect(
        find.textContaining('profile picture'),
        findsOneWidget,
      );
      // The promise this whole design rests on.
      expect(
        find.textContaining('location is only asked for later'),
        findsOneWidget,
      );
    });

    testWidgets('Continue asks the phone', (tester) async {
      final permissions = await pumpDashboard(tester);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(permissions.essentialsRequested, 1);
    });

    testWidgets('Not now asks for nothing', (tester) async {
      final permissions = await pumpDashboard(tester);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      // The camera still asks for itself when it is opened. This was the explanation, not the
      // only chance.
      expect(permissions.essentialsRequested, 0);
    });
  });

  group('location at startup', () {
    testWidgets('is never touched, whichever answer is given', (tester) async {
      final location = SpyLocationService();
      await pumpDashboard(tester, location: location);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(
        location.asked,
        0,
        reason: 'location must be asked for on the control that needs a place, not at launch',
      );
    });
  });

  group('asking twice', () {
    testWidgets('does not happen — the answer is remembered', (tester) async {
      await pumpDashboard(tester);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      // A second visit to a dashboard, on the same install.
      final second = await pumpDashboard(tester);

      expect(find.text('Zuno needs your camera'), findsNothing);
      expect(second.essentialsRequested, 0);
    });

    testWidgets('and does not happen when the camera is already granted', (
      tester,
    ) async {
      final permissions = await pumpDashboard(
        tester,
        cameraAlreadyGranted: true,
      );

      // Reinstalls and upgrades land here: nothing to ask, so nothing is asked.
      expect(find.text('Zuno needs your camera'), findsNothing);
      expect(permissions.essentialsRequested, 0);
    });
  });
}
