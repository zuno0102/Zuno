import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/location/location_service.dart';
import 'package:zuno/features/worker/presentation/widgets/worker_location_picker.dart';

/// What the worker is told when their location cannot be read, and whether a button can fix it.
///
/// The browser is the reason these exist. A web page cannot open an app settings screen or the
/// phone's location switch, so an "Open settings" button there does nothing whatsoever — the worker
/// presses the one thing that looks like the way out and stays exactly where they were.
void main() {
  group('in a browser', () {
    test('a blocked permission offers no settings button', () {
      final (title, message, actionLabel, fix) = workerLocationHelp(
        LocationProblem.deniedForever,
        isWeb: true,
      );

      expect(fix, isNull);
      expect(actionLabel, 'Try again');
      expect(title, 'Allow location for this site');
      // Where it actually lives, since nothing can take them there.
      expect(message, contains('padlock'));
    });

    test('and location switched off offers none either', () {
      final (_, message, actionLabel, fix) = workerLocationHelp(
        LocationProblem.serviceDisabled,
        isWeb: true,
      );

      expect(fix, isNull);
      expect(actionLabel, 'Try again');
      expect(message, contains('quick settings'));
    });
  });

  group('in the installed app', () {
    test('a blocked permission opens Zuno\'s own settings', () {
      final (title, _, actionLabel, fix) = workerLocationHelp(
        LocationProblem.deniedForever,
        isWeb: false,
      );

      expect(fix, WorkerLocationFix.appSettings);
      expect(actionLabel, 'Open settings');
      expect(title, 'Location is blocked');
    });

    /// A different page from the one above: Zuno's own permissions cannot switch the radio on.
    test('and location switched off opens the phone\'s own page', () {
      final (_, _, _, fix) = workerLocationHelp(
        LocationProblem.serviceDisabled,
        isWeb: false,
      );

      expect(fix, WorkerLocationFix.phoneLocationSettings);
    });
  });

  // Nothing to open for these, on either platform — trying again is the whole remedy.
  test('the problems no settings page can fix just retry', () {
    for (final isWeb in [true, false]) {
      for (final problem in [
        LocationProblem.denied,
        LocationProblem.timedOut,
        LocationProblem.failed,
        null,
      ]) {
        final (_, _, actionLabel, fix) = workerLocationHelp(
          problem,
          isWeb: isWeb,
        );

        expect(fix, isNull, reason: '$problem on web=$isWeb');
        expect(actionLabel, 'Try again', reason: '$problem on web=$isWeb');
      }
    }
  });
}
