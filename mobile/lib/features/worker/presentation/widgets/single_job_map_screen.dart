import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/worker/presentation/providers/worker_job_filter_provider.dart';
import 'package:zuno/features/worker/presentation/widgets/place_search_sheet.dart';
import 'package:zuno/features/worker/presentation/widgets/worker_location_picker.dart';
import 'package:zuno/core/theme/app_colors.dart';

/// Opens one job's location on a map, from wherever the worker is searching.
///
/// Lives beside the screen it opens rather than on any one caller. It used to sit in the Find work
/// tab, which the business page already imports — so reaching it from there would have meant two
/// files importing each other to share four lines.
///
/// Shared so every route to a job reaches the same map: a worker should not find that the map is
/// only available down one of them.
void showJobOnMap(BuildContext context, WidgetRef ref, HiringPost job) {
  final filter = ref.read(workerJobFilterProvider);

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SingleJobMapScreen(
        job: job,
        from: filter.hasPosition
            ? LatLng(filter.latitude!, filter.longitude!)
            : null,
      ),
    ),
  );
}

/// Where one job is, and the way there.
///
/// Opened from a job's details. Seeing that a venue is 18 km down the coast road, rather than reading
/// "18 km away", is the difference between guessing and knowing — so the road is drawn, with its real
/// distance and driving time, and the straight line is only the fallback when no route exists.
class SingleJobMapScreen extends ConsumerStatefulWidget {
  const SingleJobMapScreen({required this.job, this.from, super.key});

  final HiringPost job;

  /// Where the worker is. Without it there is no journey to draw, only the venue.
  final LatLng? from;

  @override
  ConsumerState<SingleJobMapScreen> createState() => _SingleJobMapScreenState();
}

class _SingleJobMapScreenState extends ConsumerState<SingleJobMapScreen> {
  final _mapController = MapController();

  TravelRoute? _route;
  bool _isLoadingRoute = false;
  bool _isLocating = false;

  /// Where the journey starts. Null until the worker has said where they are.
  ///
  /// Held in state rather than read from the widget, because it can now be answered from this
  /// screen: a worker who opened a job they were invited to has usually never been near the Find
  /// work filter, and sending them to another tab to set a starting point would be a strange thing
  /// to ask of somebody looking at a map.
  LatLng? _origin;

  LatLng get _target => LatLng(widget.job.latitude!, widget.job.longitude!);

  @override
  void initState() {
    super.initState();
    _origin = widget.from;
    if (_origin != null) {
      _loadRoute();
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadRoute() async {
    setState(() => _isLoadingRoute = true);

    final found = await ref
        .read(placeSearchClientProvider)
        .route(
          fromLatitude: _origin!.latitude,
          fromLongitude: _origin!.longitude,
          toLatitude: _target.latitude,
          toLongitude: _target.longitude,
        );

    if (!mounted) return;
    setState(() {
      _route = found;
      _isLoadingRoute = false;
    });

    // Framed even when no road route came back: the straight line between the two ends is still a
    // journey the worker needs to see both halves of.
    _frameJourney();
  }

  /// Asks where the worker is, then draws the way there.
  ///
  /// Offered on the map itself because this is where the gap shows: without a starting point the
  /// screen can only put a pin on the venue, which tells somebody deciding whether they can get
  /// there almost nothing. The answer is kept in the Find work filter, so setting it once here also
  /// narrows that feed rather than being thrown away.
  Future<void> _setOrigin() async {
    setState(() => _isLocating = true);

    final chosen = await chooseWorkerLocation(context, ref);

    if (!mounted) return;

    final filter = ref.read(workerJobFilterProvider);
    setState(() {
      _isLocating = false;
      _origin = chosen && filter.hasPosition
          ? LatLng(filter.latitude!, filter.longitude!)
          : null;
      // The old route belongs to the old starting point.
      _route = null;
    });

    if (_origin != null) {
      await _loadRoute();
    }
  }

  /// Every point the map has to hold: both ends and the road between them.
  ///
  /// The two ends are in here as well as the road, because a route can start or finish a little way
  /// off the nearest road — the walk from the door to the lane is not part of the driving line, and
  /// framing the line alone leaves the pin itself outside the picture.
  List<LatLng> get _journey => [
    ?_origin,
    _target,
    if (_route case final route?)
      ...route.points.map((p) => LatLng(p.$1, p.$2)),
  ];

  /// Zooms out to hold the whole journey.
  ///
  /// Without this the map opens tight on the venue and the route runs off every edge, which shows a
  /// worker the one part of the journey they already knew about.
  ///
  /// The padding is not a margin for looks. [CameraFit] frames the *coordinates*, and a marker is
  /// drawn around its coordinate rather than on it: the venue pin is 40 logical pixels of icon
  /// standing above its point, and the attribution sits over the bottom corner. Padding smaller
  /// than those left the fit technically correct and the pin's head cut off by the top edge, which
  /// is exactly the part that says which building it is.
  void _frameJourney() {
    final points = _journey;
    if (points.length < 2) return;

    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        // Taller at the top for the pin standing above its point, and at the bottom for the
        // attribution strip the map draws over itself.
        padding: const EdgeInsets.fromLTRB(44, 64, 44, 56),
      ),
    );
  }

  /// Re-frames once the map knows how big it is.
  ///
  /// A route that arrives before the first layout is framed against a camera with no real size, and
  /// the result is a journey sitting in the middle of a map far more zoomed out than it needs to
  /// be — most of the screen empty, the route a short stroke across the centre. The same happens
  /// when the size changes afterwards: a phone turned on its side, or a browser window resized,
  /// which is the one place this app is a web page as much as an app.
  void _onMapEvent(MapEvent event) {
    if (event is MapEventNonRotatedSizeChange) _frameJourney();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final job = widget.job;

    final filter = ref.watch(workerJobFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(job.title),
        actions: [
          // The one control that was missing. Small, in the bar, and always there — changing where
          // you are measuring from is as reasonable a thing to want as seeing the pin.
          if (_isLocating)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              onPressed: _setOrigin,
              icon: Icon(
                _origin == null
                    ? Icons.my_location_outlined
                    : Icons.edit_location_alt_outlined,
              ),
              tooltip: _origin == null
                  ? 'Show the way from where you are'
                  : 'Change where you are measuring from',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _target,
                    initialZoom: 14,
                    // The first honest size the map has. A fit done before this one ran against a
                    // camera that did not yet know the screen.
                    onMapReady: _frameJourney,
                    onMapEvent: _onMapEvent,
                    interactionOptions: const InteractionOptions(
                      flags:
                          InteractiveFlag.pinchZoom |
                          InteractiveFlag.drag |
                          InteractiveFlag.doubleTapZoom,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.zuno.zuno',
                    ),

                    if (_origin case final origin?)
                      PolylineLayer(
                        polylines: [
                          if (_route case final route?) ...[
                            // Drawn twice: a wide pale line underneath and the solid one on top, so
                            // the route stays legible over dark map features and dense towns.
                            Polyline(
                              points: route.points
                                  .map((p) => LatLng(p.$1, p.$2))
                                  .toList(),
                              strokeWidth: 9,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                            Polyline(
                              points: route.points
                                  .map((p) => LatLng(p.$1, p.$2))
                                  .toList(),
                              strokeWidth: 5,
                              color: theme.colorScheme.primary,
                            ),
                          ] else
                            // No road route, or still fetching: the straight line is honest about
                            // being a direction rather than a way to travel.
                            Polyline(
                              points: [origin, _target],
                              strokeWidth: 2,
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.5,
                              ),
                              pattern: StrokePattern.dotted(),
                            ),
                        ],
                      ),

                    MarkerLayer(
                      markers: [
                        if (_origin case final origin?)
                          Marker(
                            point: origin,
                            width: 26,
                            height: 26,
                            child: _EndPoint(
                              colour: theme.colorScheme.primary,
                              label: 'A',
                            ),
                          ),
                        Marker(
                          point: _target,
                          width: 40,
                          height: 40,
                          child: Icon(
                            Icons.location_on,
                            size: 40,
                            color: theme.colorScheme.tertiary,
                            shadows: const [
                              Shadow(
                                blurRadius: 4,
                                color: AppColors.shadowStrong,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),

                if (_isLoadingRoute)
                  Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              blurRadius: 4,
                              color: AppColors.shadowSoft,
                            ),
                          ],
                        ),
                        child: Text(
                          'Finding the way…',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ),

                // The way back to the whole journey.
                //
                // The map is draggable and pinchable, which is the point — a worker zooms in to see
                // which turning it is. But zooming in is a one-way door without this: they are left
                // holding one corner of the route with no idea how to get the rest of it back, and
                // the only way out is to leave the screen and come in again.
                if (_journey.length >= 2)
                  Positioned(
                    right: 12,
                    // Clear of the attribution, which the map draws into the bottom-right corner
                    // and which must stay readable.
                    bottom: 56,
                    child: Material(
                      color: theme.colorScheme.surface,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: IconButton(
                        onPressed: _frameJourney,
                        icon: const Icon(Icons.fit_screen_outlined),
                        tooltip: 'Show the whole route',
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // The journey in words under the map. A drawn line does not tell somebody how long to
          // allow, and the typed address is what gets them to the right gate.
          Container(
            width: double.infinity,
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Said in words as well as offered as an icon. An icon alone answers somebody who
                // already knows what is missing; this says what the map cannot show and why.
                if (_origin == null && !_isLocating)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: OutlinedButton.icon(
                      onPressed: _setOrigin,
                      icon: const Icon(Icons.my_location_outlined, size: 18),
                      label: const Text('Show the way from where you are'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ),

                // Where the journey is measured from, so a worker can tell at a glance that the
                // distance below is from the right place — a fix that landed in the wrong district
                // would otherwise be invisible.
                if (_origin != null && filter.placeLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.my_location_outlined,
                          size: 15,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'From ${filter.placeLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_route case final route?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.directions_car_outlined,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          route.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (!_isLoadingRoute && _origin != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      // Said rather than left blank, so a dotted line is not mistaken for a road.
                      'No driving route found. The line shows the direction only.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),

                Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 17,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        [
                          job.location,
                          job.districtName,
                        ].where((p) => p != null && p.isNotEmpty).join(', '),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                if (job.isLocationApproximate)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 23),
                    child: Text(
                      // Worth saying loudly on a map: a pin looks exact whether or not it is.
                      'This pin is approximate — the business did not give an exact spot.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),

                const SizedBox(height: 10),
                Text(
                  '${rupees(job.myAgreedSalaryAmount ?? job.salaryAmount)} '
                  '${salaryUnitWords(job.salaryUnit)} · ${job.businessName}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One end of the journey, drawn as a labelled dot so the two are told apart at a glance.
class _EndPoint extends StatelessWidget {
  const _EndPoint({required this.colour, required this.label});

  final Color colour;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: colour,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [BoxShadow(blurRadius: 4, color: AppColors.shadowSoft)],
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
