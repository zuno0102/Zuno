import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/core/theme/app_colors.dart';

/// Jobs around the worker, drawn on a map.
///
/// OpenStreetMap tiles rather than Google Maps: no API key, no billing account, and nothing for
/// anybody to set up before it works. The trade is a plainer look and OSM's attribution requirement,
/// which is honoured bottom-right.
class NearbyJobsMap extends StatefulWidget {
  const NearbyJobsMap({
    required this.jobs,
    required this.centre,
    required this.radiusKm,
    this.onJobTapped,
    this.fillAvailableHeight = false,
    super.key,
  });

  /// Only jobs with a position; the caller filters, because a job with no location has no pin.
  final List<HiringPost> jobs;

  /// Where the worker is.
  final LatLng centre;

  /// Drawn as a ring, so the worker can see what the number actually covers.
  final int? radiusKm;

  final void Function(HiringPost job)? onJobTapped;

  /// Takes whatever height the parent gives it, for when the map is the whole screen.
  ///
  /// Off by default because inside a scrolling column there is no bounded height to take, and
  /// asking for one there resolves to infinity and fails the viewport.
  final bool fillAvailableHeight;

  @override
  State<NearbyJobsMap> createState() => _NearbyJobsMapState();
}

class _NearbyJobsMapState extends State<NearbyJobsMap> {
  /// The job whose label is showing. Tapping a pin opens it; tapping the map closes it.
  HiringPost? _selected;

  /// A zoom that frames the chosen radius, rather than a fixed one.
  ///
  /// Without this a 5km search opens zoomed out to a whole state, and a 200km search opens so close
  /// that every pin is off screen.
  double get _initialZoom => switch (widget.radiusKm) {
    null => 10,
    <= 2 => 13.5,
    <= 5 => 12,
    <= 10 => 11,
    <= 15 => 10.6,
    <= 20 => 10.3,
    <= 25 => 10,
    <= 50 => 9,
    <= 100 => 8,
    _ => 7,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        // Fixed unless the map owns the screen. Inside a scrolling column there is no bounded
        // height to inherit, and taking one there resolves to infinity and fails the viewport.
        height: widget.fillAvailableHeight ? null : 320,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: widget.centre,
                initialZoom: _initialZoom,
                // No rotation: a tilted map helps nobody find a job and makes the labels unreadable.
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom |
                      InteractiveFlag.drag |
                      InteractiveFlag.doubleTapZoom,
                ),
                onTap: (_, _) => setState(() => _selected = null),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  // OSM asks that clients identify themselves.
                  userAgentPackageName: 'com.zuno.zuno',
                ),

                // The radius as a ring. Far clearer than a number alone — it shows that "50 km"
                // reaches the next district but not the one after.
                if (widget.radiusKm case final km?)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: widget.centre,
                        radius: km * 1000,
                        useRadiusInMeter: true,
                        color: theme.colorScheme.primary.withValues(alpha: 0.08),
                        borderColor: theme.colorScheme.primary.withValues(alpha: 0.45),
                        borderStrokeWidth: 1.5,
                      ),
                    ],
                  ),

                MarkerLayer(
                  markers: [
                    // The worker, drawn differently from the jobs so it is never mistaken for one.
                    Marker(
                      point: widget.centre,
                      width: 26,
                      height: 26,
                      child: _YouAreHere(colour: theme.colorScheme.primary),
                    ),
                    for (final job in widget.jobs)
                      Marker(
                        point: LatLng(job.latitude!, job.longitude!),
                        width: 34,
                        height: 34,
                        child: GestureDetector(
                          onTap: () => setState(() => _selected = job),
                          child: _JobPin(
                            isSelected: _selected?.id == job.id,
                            isApproximate: job.isLocationApproximate,
                          ),
                        ),
                      ),
                  ],
                ),

                // Required by the tile licence, and kept small.
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),

            if (_selected case final job?)
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: _JobCallout(
                  job: job,
                  onOpen: widget.onJobTapped == null
                      ? null
                      : () => widget.onJobTapped!(job),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _YouAreHere extends StatelessWidget {
  const _YouAreHere({required this.colour});

  final Color colour;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: colour,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [BoxShadow(blurRadius: 4, color: AppColors.shadowSoft)],
    ),
    child: const SizedBox.shrink(),
  );
}

class _JobPin extends StatelessWidget {
  const _JobPin({required this.isSelected, required this.isApproximate});

  final bool isSelected;

  /// Drawn hollow, because pretending an approximate position is exact sends somebody to the
  /// wrong place.
  final bool isApproximate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = isSelected
        ? theme.colorScheme.tertiary
        : theme.colorScheme.secondary;

    return Icon(
      isApproximate ? Icons.location_searching : Icons.location_on,
      size: isSelected ? 34 : 28,
      color: colour,
      shadows: const [Shadow(blurRadius: 3, color: AppColors.shadowStrong)],
    );
  }
}

/// The tapped job, enough of it to decide whether to open it.
class _JobCallout extends StatelessWidget {
  const _JobCallout({required this.job, this.onOpen});

  final HiringPost job;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 4,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      job.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      [
                        job.distanceLabel,
                        job.location,
                      ].where((p) => p != null && p.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${rupees(job.salaryAmount)} '
                      '${salaryUnitWords(job.salaryUnit)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onOpen != null)
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
