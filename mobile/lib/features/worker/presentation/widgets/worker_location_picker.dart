import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/location/location_service.dart';
import 'package:zuno/features/worker/presentation/providers/worker_job_filter_provider.dart';
import 'package:zuno/features/worker/presentation/widgets/place_search_sheet.dart';
import 'package:zuno/shared/widgets/app_messages.dart';

// Asking a worker where they are, and remembering the answer.
///
/// Lifted out of the Find work filter bar, which was the only screen that could ask. The map behind
/// a job needs the same answer — it cannot draw the way there without a starting point — and the
/// moment a worker most wants that is on a job they were invited to, which is exactly when they are
/// least likely to have been through the Find work filter first.
///
/// Sending them to another tab to set it would be the wrong answer, and writing a thinner second
/// copy here would be worse: the hard part is not reading a coordinate, it is the four ways that
/// fails — permission refused, refused for ever, location off for the whole phone, and no fix
/// arriving — each of which needs different words and a different way out. One implementation.
///
/// The answer is stored in [workerJobFilterProvider], so setting it once on a map also narrows the
/// Find work feed rather than being thrown away.
/// Opens the full control: type a place, use the phone's position, or clear what is set.
///
/// Returns true when a position was set or cleared, so a caller can react.
Future<bool> chooseWorkerLocation(BuildContext context, WidgetRef ref) async {
  final choice = await showPlaceSearchSheet(
    context,
    hasLocation: ref.read(workerJobFilterProvider).hasPosition,
  );

  if (choice == null || !context.mounted) return false;

  if (choice.clearLocation) {
    // The way back to no location at all. Fixing "Anywhere" to keep the position left nothing able
    // to clear it, so a worker who set the wrong place was stuck with it.
    ref.read(workerJobFilterProvider.notifier).clear();
    context.showInfoMessage('Location cleared.');
    return true;
  }

  if (choice.useCurrentLocation) {
    return useCurrentWorkerLocation(context, ref);
  }

  if (choice.place case final place?) {
    ref
        .read(workerJobFilterProvider.notifier)
        .setPosition(
          latitude: place.latitude,
          longitude: place.longitude,
          placeLabel: place.name,
        );

    context.showSuccessMessage('Location set to ${place.name}.');
    return true;
  }

  return false;
}

/// Reads the phone's position and stores it, explaining itself when it cannot.
///
/// Returns true when a position was set.
Future<bool> useCurrentWorkerLocation(
  BuildContext context,
  WidgetRef ref,
) async {
  final service = ref.read(locationServiceProvider);
  final notifier = ref.read(workerJobFilterProvider.notifier);
  final result = await service.current();

  if (!context.mounted) return false;

  if (result.hasPosition) {
    // Named, not just held. "Your current location" tells a worker nothing they can check — if the
    // fix landed in the wrong district they would never know. A name makes it verifiable.
    final named = await ref
        .read(placeSearchClientProvider)
        .reverse(latitude: result.latitude!, longitude: result.longitude!);

    if (!context.mounted) return false;

    final label = named?.name.isNotEmpty == true
        ? named!.name
        : result.isApproximate
        ? 'Near your last known location'
        : 'Your current location';

    notifier.setPosition(
      latitude: result.latitude!,
      longitude: result.longitude!,
      placeLabel: label,
      isApproximate: result.isApproximate,
    );

    context.showSuccessMessage(
      named == null ? 'Location set.' : 'Location set to $label.',
    );
    return true;
  }

  // Each problem needs different words, because each has a different way out.
  //
  // A dialog, not a snackbar: this is the thing standing between the worker and what they asked
  // for, so it needs a button that fixes it rather than a notice that slides off the screen.
  final (title, message, actionLabel, onAction) = switch (result.problem) {
    LocationProblem.serviceDisabled => (
      'Turn on location',
      'Location is switched off for this phone, so no app can find you. Turn it on, then try '
          'again — or type a place instead.',
      'Open settings',
      // The phone's own location page: the app's permission screen cannot switch the radio on.
      service.openLocationSettings,
    ),
    LocationProblem.deniedForever => (
      'Location is blocked',
      'Zuno is not allowed to read your location. You can change that in the app settings, or '
          'type a place instead.',
      'Open settings',
      service.openSettings,
    ),
    LocationProblem.denied => (
      'Location needed',
      'Zuno needs to know where you are to measure the distance. You can also type a place '
          'instead.',
      'Try again',
      null,
    ),
    LocationProblem.timedOut => (
      'Could not find you',
      'No location came back — that often happens indoors. Try again outside, or type a place '
          'instead.',
      'Try again',
      null,
    ),
    _ => (
      'Could not read your location',
      'Something went wrong finding you. You can type a place instead.',
      'Try again',
      null,
    ),
  };

  final retry = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        // Always offered, because typing needs no permission and must never be a dead end.
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Type a place'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(actionLabel),
        ),
      ],
    ),
  );

  if (!context.mounted) return false;

  if (retry == true) {
    if (onAction != null) {
      await onAction();
      return false;
    }
    return useCurrentWorkerLocation(context, ref);
  }

  if (retry == false) {
    return chooseWorkerLocation(context, ref);
  }

  return false;
}
