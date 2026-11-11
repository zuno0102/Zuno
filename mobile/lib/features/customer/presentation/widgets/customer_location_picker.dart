import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/location/location_service.dart';
import 'package:zuno/features/catalog/domain/entities/district.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zuno/features/customer/data/datasources/customer_location_api.dart';
import 'package:zuno/features/customer/domain/entities/customer_location.dart';
import 'package:zuno/features/customer/presentation/providers/customer_home_location_provider.dart';
import 'package:zuno/features/customer/presentation/providers/customer_location_sync.dart';
import 'package:zuno/features/customer/presentation/providers/customer_search_filter_provider.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/multi_select_sheet.dart';
import 'package:zuno/shared/widgets/select_field.dart';

enum _LocationChoice { current, pick, everywhere }

/// The search filter behind the pin button: the phone's district, districts picked by hand, or
/// everywhere — kept in [customerSearchFilterProvider], on this device. A filter only: it does not
/// change the customer's own location (set up on first open, kept in their account).
Future<void> pickCustomerLocation(BuildContext context, WidgetRef ref) async {
  final hasLocation = ref.read(customerSearchFilterProvider).hasLocation;
  final choice = await showModalBottomSheet<_LocationChoice>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('Search where?')),
          ListTile(
            key: const ValueKey('location-use-current'),
            leading: const Icon(Icons.my_location),
            title: const Text('Use my current location'),
            onTap: () => Navigator.of(context).pop(_LocationChoice.current),
          ),
          ListTile(
            key: const ValueKey('location-pick'),
            leading: const Icon(Icons.map_outlined),
            title: const Text('Choose state and district'),
            onTap: () => Navigator.of(context).pop(_LocationChoice.pick),
          ),
          if (hasLocation)
            ListTile(
              key: const ValueKey('location-everywhere'),
              leading: const Icon(Icons.public),
              title: const Text('Show everywhere'),
              onTap: () =>
                  Navigator.of(context).pop(_LocationChoice.everywhere),
            ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;

  switch (choice) {
    case _LocationChoice.current:
      await _filterByCurrentLocation(context, ref);
    case _LocationChoice.pick:
      await _pickDistricts(context, ref);
    case _LocationChoice.everywhere:
      ref.read(customerSearchFilterProvider.notifier).clearLocation();
  }
}

/// Narrows the search to the district the phone is in, saying in a line what happened.
Future<void> _filterByCurrentLocation(
  BuildContext context,
  WidgetRef ref,
) async {
  final messenger = AppMessenger.of(context);
  try {
    final outcome = await locateCustomerFromPhone(
      locationService: ref.read(locationServiceProvider),
      api: ref.read(customerLocationApiProvider),
      onFound: ref
          .read(customerSearchFilterProvider.notifier)
          .setDetectedLocation,
      askPermission: true,
    );
    if (outcome.district case final district?) {
      messenger.showSuccess('Showing listings near ${district.name}.');
    } else {
      messenger.showInfo(_problemText(outcome));
    }
  } on Object {
    messenger.showFailure(
      'Could not find your district. Check your connection and try again.',
    );
  }
}

String _problemText(PhoneLocationOutcome outcome) {
  if (outcome.isOutsideArea) {
    return 'Zuno does not serve where you are yet. Choose a district instead.';
  }
  return switch (outcome.problem) {
    // A browser remembers "Block" for the site and never shows the popup again by itself.
    LocationProblem.deniedForever when kIsWeb =>
      'Location is blocked for this website. Click the icon left of the web address, '
          'allow Location and reload — or choose a district.',
    LocationProblem.deniedForever =>
      'Location is blocked for Zuno. Allow it in your phone settings, or choose a district.',
    LocationProblem.serviceDisabled when kIsWeb =>
      'Location is off on this computer or browser. Turn it on, or choose a district.',
    LocationProblem.serviceDisabled =>
      'Location is off on your phone. Turn it on, or choose a district.',
    LocationProblem.denied =>
      'Allow location to find services near you, or choose a district.',
    _ => 'Could not read your location. Try again, or choose a district.',
  };
}

enum _SetupChoice { turnOn, pick }

/// Location setup is required: a customer without a location gets this sheet, and it comes back
/// until one is set — from the phone ("Turn on location") or a district picked by hand. It cannot be
/// closed. Why the last try gave nothing is shown inside it (a message at the bottom of the screen
/// would sit behind it).
///
/// Sets the customer's own location ([customerHomeLocationProvider]), saved to their account — never
/// the search filter.
Future<void> requireCustomerLocation(
  BuildContext context,
  WidgetRef ref,
) async {
  String? problem;
  while (context.mounted && !ref.read(customerHomeLocationProvider).isSet) {
    try {
      problem = await _setupOnce(context, ref, problem);
    } on Object {
      // The district list failed to load (offline): the sheet comes back so they can try again.
      problem =
          'Could not load the districts. Check your connection and try again.';
    }
  }
}

Future<String?> _setupOnce(
  BuildContext context,
  WidgetRef ref,
  String? problem,
) async {
  final choice = await showModalBottomSheet<_SetupChoice>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (context) => PopScope(
      canPop: false,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              key: ValueKey('location-first-time'),
              title: Text('Find services near you'),
              subtitle: Text(
                'Turn on your location so we can show services and rentals in your district. '
                'It is saved to your account.',
              ),
            ),
            if (problem != null)
              Padding(
                key: const ValueKey('location-problem'),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  problem,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: FilledButton.icon(
                key: const ValueKey('location-turn-on'),
                onPressed: () => Navigator.of(context).pop(_SetupChoice.turnOn),
                icon: const Icon(Icons.my_location),
                label: const Text('Turn on location'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
            ListTile(
              key: const ValueKey('location-pick'),
              leading: const Icon(Icons.map_outlined),
              title: const Text('Choose state and district'),
              onTap: () => Navigator.of(context).pop(_SetupChoice.pick),
            ),
          ],
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return problem;

  switch (choice) {
    case _SetupChoice.turnOn:
      return _turnOnLocation(context, ref);
    case _SetupChoice.pick:
      await _pickHomeDistrict(context, ref);
      return null;
  }
}

/// Reads the phone's location — asking for the permission — and saves its district as the
/// customer's location. On a phone where location is off or blocked, opens the settings page that
/// turns it on. Returns why no district was set, or null when one was.
Future<String?> _turnOnLocation(BuildContext context, WidgetRef ref) async {
  final messenger = AppMessenger.of(context);
  final service = ref.read(locationServiceProvider);
  final home = ref.read(customerHomeLocationProvider.notifier);
  try {
    final outcome = await locateCustomerFromPhone(
      locationService: service,
      api: ref.read(customerLocationApiProvider),
      onFound: (d) => home.set(d, CustomerLocationSource.gps),
      askPermission: true,
    );
    if (outcome.district case final district?) {
      messenger.showSuccess('Your location is set to ${district.name}.');
      return null;
    }
    // A phone can take the customer straight to the switch; a browser cannot.
    if (!kIsWeb) {
      if (outcome.problem == LocationProblem.serviceDisabled) {
        await service.openLocationSettings();
        return 'Turn on location, then come back and tap Turn on location again.';
      }
      if (outcome.problem == LocationProblem.deniedForever) {
        await service.openSettings();
        return 'Allow location for Zuno in settings, then tap Turn on location again.';
      }
    }
    return _problemText(outcome);
  } on Object {
    return 'Could not find your district. Check your connection and try again.';
  }
}

/// One state, then one district, as the customer's location.
Future<void> _pickHomeDistrict(BuildContext context, WidgetRef ref) async {
  final states = await ref.read(locationStatesProvider.future);
  if (!context.mounted) return;

  final state = await showSelectSheet<String>(
    context,
    title: 'Your state',
    options: [for (final s in states) SelectOption(s.id, s.name)],
  );
  if (state == null || !context.mounted) return;

  final districts = await ref.read(
    districtsForStatesProvider(state.value).future,
  );
  if (!context.mounted) return;

  final picked = await showSelectSheet<String>(
    context,
    title: 'Your district',
    options: [for (final d in districts) SelectOption(d.id, d.name)],
  );
  if (picked == null) return;

  final District district = districts.firstWhere((d) => d.id == picked.value);
  await ref
      .read(customerHomeLocationProvider.notifier)
      .set(district, CustomerLocationSource.manual);
}

/// States, then districts, picked by hand.
Future<void> _pickDistricts(BuildContext context, WidgetRef ref) async {
  final filter = ref.read(customerSearchFilterProvider.notifier);
  final current = ref.read(customerSearchFilterProvider);
  final states = await ref.read(locationStatesProvider.future);
  if (!context.mounted) return;

  final states0 = await showMultiSelectSheet(
    context: context,
    title: 'States',
    options: states
        .map((s) => MultiSelectOption(id: s.id, label: s.name))
        .toList(),
    initialSelectedIds: current.stateIds,
    // The way out. Clearing the filter otherwise meant unticking every state by hand, and a
    // customer who had picked four had to remember which four.
    clearLabel: 'Clear location',
  );
  if (states0 == null) return;

  if (states0.isEmpty) {
    filter.clearLocation();
    return;
  }

  final stateIdsCsv = (states0.toList()..sort()).join(',');
  final districts = await ref.read(
    districtsForStatesProvider(stateIdsCsv).future,
  );
  if (!context.mounted) return;

  final districtIds = await showMultiSelectSheet(
    context: context,
    title: 'Districts',
    options: districts
        .map(
          (d) =>
              MultiSelectOption(id: d.id, label: '${d.name} (${d.stateName})'),
        )
        .toList(),
    initialSelectedIds: current.districtIds
        .where((id) => districts.any((d) => d.id == id))
        .toSet(),
    // Offered here too, so somebody two sheets deep does not have to back out to find it.
    clearLabel: 'Clear location',
  );
  if (districtIds == null) return;

  if (districtIds.isEmpty) {
    // No districts means no location filter, whichever states are ticked behind it. Said plainly
    // rather than stored as "these states, no districts", which would read as a filter that
    // matches nothing.
    filter.clearLocation();
    return;
  }

  filter.setLocation(
    stateIds: states0,
    districtIds: districtIds,
    // The first one they ticked, named. The sheet hands the ids back in the order they were
    // chosen, so this is their own first choice rather than whichever sorts first.
    primaryDistrictName: districts
        .where((d) => d.id == districtIds.first)
        .map((d) => d.name)
        .firstOrNull,
  );
}

/// A compact location filter that says how many districts are chosen.
class CustomerLocationButton extends StatelessWidget {
  const CustomerLocationButton({
    required this.count,
    required this.onPressed,
    super.key,
  });

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = count > 0;

    return Material(
      color: active
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.place_outlined,
                size: 19,
                color: active ? theme.colorScheme.primary : null,
              ),
              if (active) ...[
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A small button that takes the customer back to the top of a long page.
///
/// The home screen is six sections and roughly forty cards deep, so somebody who scrolled to the
/// bottom had a long way back — and no gesture on Android does it for them, unlike the status-bar tap
/// on iOS.
///
/// Appears and leaves rather than sitting there permanently: on the first screen there is nothing to
/// return from, and a control that can never do anything is worse than no control.
class BackToTopButton extends StatelessWidget {
  const BackToTopButton({
    required this.visible,
    required this.onPressed,
    super.key,
  });

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IgnorePointer(
      // Not just invisible: a faded-out button still catches taps, and an invisible thing taking a
      // tap meant for a card underneath it is the worst kind of bug to report.
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: AnimatedScale(
          // Grows in rather than fading alone, which reads as the button arriving rather than the
          // page having been foggy.
          scale: visible ? 1 : 0.7,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: Material(
            color: theme.colorScheme.primary,
            shape: const CircleBorder(),
            elevation: 3,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.all(11),
                child: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: 24,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
