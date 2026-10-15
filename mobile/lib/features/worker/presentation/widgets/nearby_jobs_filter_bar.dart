import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/worker/presentation/providers/worker_job_filter_provider.dart';
import 'package:zuno/features/worker/presentation/widgets/worker_location_picker.dart';

/// Where the worker is and how far they will travel, in one line above the jobs.
///
/// Deliberately one row. An earlier version laid every distance out as a grid of buttons, which ate
/// two rows of a phone screen before a single job appeared and read as clutter rather than a control.
/// The distance now sits behind a tap — the pattern the customer search already uses for its own
/// filters: one compact summary that opens a sheet.
///
/// Never a wall: with no location shared this is a single invitation, and the feed below keeps
/// listing every job exactly as it did before this existed.
class NearbyJobsFilterBar extends ConsumerStatefulWidget {
  const NearbyJobsFilterBar({
    required this.showingMap,
    required this.onToggleMap,
    super.key,
  });

  final bool showingMap;
  final VoidCallback onToggleMap;

  @override
  ConsumerState<NearbyJobsFilterBar> createState() =>
      _NearbyJobsFilterBarState();
}

class _NearbyJobsFilterBarState extends ConsumerState<NearbyJobsFilterBar> {
  bool _isLocating = false;

  /// Both delegate to the shared picker, which is also what the job map uses.
  ///
  /// The hard part was never reading a coordinate — it is the four ways that fails, each needing
  /// different words and a different way out. One implementation, so the map cannot drift into
  /// explaining a blocked permission differently from this bar.
  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    await useCurrentWorkerLocation(context, ref);
    if (mounted) setState(() => _isLocating = false);
  }

  Future<void> _setLocation() async {
    await chooseWorkerLocation(context, ref);
  }

  Future<void> _pickDistance() async {
    final filter = ref.read(workerJobFilterProvider);
    final chosen = await showDistanceSheet(context, selectedKm: filter.radiusKm);

    if (chosen == null || !mounted) return;

    final notifier = ref.read(workerJobFilterProvider.notifier);
    if (chosen == anywhereSentinel) {
      notifier.showAnywhere();
    } else {
      notifier.setRadius(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = ref.watch(workerJobFilterProvider);

    if (!filter.hasPosition) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(
              // GPS leads, because it is one tap and usually right.
              child: FilledButton.icon(
                onPressed: _isLocating ? null : _useCurrentLocation,
                icon: _isLocating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.near_me, size: 18),
                label: Text(_isLocating ? 'Finding you…' : 'Jobs near me'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // The way in for somebody who declined the permission, or who is planning travel from
            // somewhere they are not standing. Without it, a refused permission is a dead end.
            OutlinedButton.icon(
              onPressed: _setLocation,
              icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
              label: const Text('Enter'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(72, 46),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // The distance leads, because it is the thing a worker adjusts.
          _FilterPill(
            icon: Icons.social_distance,
            label: filter.radiusKm == null
                ? 'Anywhere'
                : 'Within ${filter.radiusKm} km',
            isActive: filter.radiusKm != null,
            onTap: _pickDistance,
          ),
          const SizedBox(width: 8),
          Expanded(
            // Tapping the place opens the search, so changing where you are searching from is one
            // tap on the thing that names it — not a hunt for a separate control.
            child: InkWell(
              onTap: _setLocation,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    if (_isLocating)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        Icons.place,
                        size: 15,
                        color: theme.colorScheme.primary,
                      ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        // Said plainly when the fix is stale, rather than implying it is live.
                        filter.isApproximate
                            ? '${filter.placeLabel} (approximate)'
                            : filter.placeLabel ?? 'Your location',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.edit,
                      size: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              widget.showingMap ? Icons.view_list : Icons.map_outlined,
              size: 21,
            ),
            tooltip: widget.showingMap ? 'Show as a list' : 'Show on a map',
            onPressed: widget.onToggleMap,
          ),
        ],
      ),
    );
  }
}

/// Returned for "no radius", so the sheet can answer with a single int.
const int anywhereSentinel = -1;

/// Lets the worker pick how far they will travel.
///
/// A sheet rather than a row of buttons: it holds as many steps as the feature wants without costing
/// the feed any space, every option is a full-width row that is easy to read and to hit, and the
/// current choice is unmistakable.
Future<int?> showDistanceSheet(
  BuildContext context, {
  required int? selectedKm,
}) {
  return showModalBottomSheet<int>(
    context: context,
    useSafeArea: true,
    // Ten options are taller than the default sheet allows, which silently cut off the longest
    // distances — the sheet must be free to size itself and then scroll.
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 2),
              child: Text(
                'How far will you travel?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                // Said once, here, instead of repeated on every card.
                'Measured in a straight line, so the road is usually a little further.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final km in WorkerJobFilterNotifier.radiusSteps)
                    _DistanceRow(
                      label: 'Within $km km',
                      isSelected: selectedKm == km,
                      onTap: () => Navigator.of(context).pop(km),
                    ),
                  _DistanceRow(
                    label: 'Anywhere',
                    detail: 'Every job, however far',
                    isSelected: selectedKm == null,
                    onTap: () => Navigator.of(context).pop(anywhereSentinel),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _DistanceRow extends StatelessWidget {
  const _DistanceRow({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.detail,
  });

  final String label;
  final String? detail;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.08),
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? theme.colorScheme.primary : null,
        ),
      ),
      subtitle: detail == null ? null : Text(detail!),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
          : null,
    );
  }
}

/// A compact summary that opens a picker.
///
/// Styled explicitly rather than as a [Chip], because the app's global `chipTheme` drops the border
/// for its dense status pills — which left an earlier version of this control with no visible edge
/// at all.
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: isActive ? scheme.primary : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isActive ? scheme.primary : scheme.outline,
              width: 1.4,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: isActive ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isActive ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down,
                size: 20,
                color: isActive ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
