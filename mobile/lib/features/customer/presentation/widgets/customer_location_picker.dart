import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/location/location_service.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zuno/features/customer/data/datasources/customer_location_api.dart';
import 'package:zuno/features/customer/presentation/providers/customer_location_sync.dart';
import 'package:zuno/features/customer/presentation/providers/customer_search_filter_provider.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/multi_select_sheet.dart';

enum _LocationChoice { current, pick, everywhere }

/// Where the customer is looking: their phone's location, districts they pick, or everywhere — kept
/// in [customerSearchFilterProvider]. One location for the whole customer app: the Service home and
/// the Rent home both search where this says.
Future<void> pickCustomerLocation(BuildContext context, WidgetRef ref) async {
  final hasLocation = ref.read(customerSearchFilterProvider).hasLocation;
  final choice = await showModalBottomSheet<_LocationChoice>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('Where are you?')),
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
      await useCurrentCustomerLocation(context, ref);
    case _LocationChoice.pick:
      await _pickDistricts(context, ref);
    case _LocationChoice.everywhere:
      ref.read(customerSearchFilterProvider.notifier).clearLocation();
  }
}

/// Reads the phone's location now — asking for the permission if need be — and sets its district,
/// saying in a line what happened.
Future<void> useCurrentCustomerLocation(
  BuildContext context,
  WidgetRef ref,
) async {
  final messenger = AppMessenger.of(context);
  try {
    final outcome = await locateCustomerFromPhone(
      locationService: ref.read(locationServiceProvider),
      api: ref.read(customerLocationApiProvider),
      filter: ref.read(customerSearchFilterProvider.notifier),
      askPermission: true,
    );
    if (outcome.district case final district?) {
      messenger.showSuccess('Showing listings near ${district.name}.');
    } else if (outcome.isOutsideArea) {
      messenger.showInfo(
        'Zuno does not serve where you are yet. Choose a district instead.',
      );
    } else {
      messenger.showInfo(switch (outcome.problem) {
        LocationProblem.deniedForever =>
          'Location is blocked for Zuno. Allow it in your phone settings, or choose a district.',
        LocationProblem.serviceDisabled =>
          'Location is off on your phone. Turn it on, or choose a district.',
        LocationProblem.denied =>
          'Zuno needs your location for this. You can choose a district instead.',
        _ => 'Could not read your location. Try again, or choose a district.',
      });
    }
  } on Object {
    messenger.showFailure(
      'Could not find your district. Check your connection and try again.',
    );
  }
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
