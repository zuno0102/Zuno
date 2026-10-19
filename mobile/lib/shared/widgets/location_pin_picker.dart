import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';
import 'package:zuno/core/location/location_service.dart';
import 'package:zuno/core/maps/google_maps_config.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/worker/presentation/widgets/place_search_sheet.dart';
import 'package:zuno/shared/widgets/map_layers.dart';

/// What to tell somebody whose location could not be read, and what — if anything — a button can
/// do about it.
class LocationHelp {
  const LocationHelp({
    required this.title,
    required this.message,
    this.steps = const [],
    this.action,
  });

  final String title;
  final String message;

  /// Step-by-step instructions, shown in a dialog rather than a one-line message.
  final List<String> steps;

  /// A button that actually fixes it. Null where no button can — in a browser there is no app
  /// settings page to open, so offering one only produced a button that did nothing.
  final LocationHelpAction? action;

  bool get isDialog => steps.isNotEmpty;
}

enum LocationHelpAction { openAppSettings, openLocationSettings }

/// The help for [problem], worded for where the app is running.
///
/// Pure, so it can be tested without a browser or a phone. [isWeb] decides it: the installed app can
/// open the phone's settings, a web page cannot — there the permission lives behind the padlock next
/// to the address.
LocationHelp locationHelp(LocationProblem? problem, {required bool isWeb}) {
  switch (problem) {
    case LocationProblem.denied:
    case LocationProblem.deniedForever:
      if (isWeb) {
        return const LocationHelp(
          title: 'Allow location for this site',
          message: 'Your browser is blocking location for Zuno. To use where you are now:',
          steps: [
            'Tap the padlock (or ⓘ) to the left of the web address at the top.',
            'Open Permissions, then Location, and choose Allow.',
            'Come back here and tap the ◎ button again.',
          ],
        );
      }
      return problem == LocationProblem.denied
          ? const LocationHelp(
              title: 'Location not allowed',
              message: 'Location permission was not given. Search for the place instead.',
            )
          : const LocationHelp(
              title: 'Location is off for Zuno',
              message: 'Location permission is off for Zuno. Allow it in settings, or search for the place.',
              action: LocationHelpAction.openAppSettings,
            );
    case LocationProblem.serviceDisabled:
      return isWeb
          ? const LocationHelp(
              title: 'Location is off',
              message:
                  'Location is turned off on this phone. Turn it on from the quick settings, then tap ◎ again.',
            )
          : const LocationHelp(
              title: 'Location is off',
              message: 'Location is turned off on this phone. Turn it on, or search for the place.',
              action: LocationHelpAction.openLocationSettings,
            );
    case LocationProblem.timedOut:
      return const LocationHelp(
        title: 'No GPS fix',
        message: 'Could not get a GPS fix here. Search for the place, then drag the map to it.',
      );
    case LocationProblem.failed:
    case null:
      return const LocationHelp(
        title: 'Location unavailable',
        message: 'Could not read your location. Search for the place instead.',
      );
  }
}

/// A spot somebody pinned on the map, with the address the map gives for it.
class PickedLocation {
  const PickedLocation({
    required this.latitude,
    required this.longitude,
    this.label,
    this.fullAddress,
    this.street,
    this.locality,
    this.city,
    this.state,
    this.postalCode,
  });

  final double latitude;
  final double longitude;

  /// A short name for the spot — "Church Street" — when the map could name it.
  final String? label;

  /// The provider's whole address line.
  final String? fullAddress;
  final String? street;
  final String? locality;
  final String? city;
  final String? state;
  final String? postalCode;

  /// One readable line for a text field: the street and the area, then the town.
  String get summary {
    final parts = <String>[
      ?street,
      if (locality != null && locality != street) locality!,
      ?city,
    ];
    if (parts.isNotEmpty) return parts.join(', ');
    return label ?? fullAddress ?? '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
  }
}

/// Opens a full-screen map for pinning the exact place a job is at.
///
/// The pin stays in the middle and the map moves under it — easier on a phone than dragging a small
/// marker with a thumb that hides it. The map opens on [initial] when there is one, otherwise on the
/// phone's own location; a search box jumps to a named place.
Future<PickedLocation?> showLocationPinPicker(
  BuildContext context, {
  double? initialLatitude,
  double? initialLongitude,
  String title = 'Pin the job location',
}) {
  return Navigator.of(context).push<PickedLocation>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => LocationPinPickerScreen(
        title: title,
        initial: initialLatitude != null && initialLongitude != null
            ? LatLng(initialLatitude, initialLongitude)
            : null,
      ),
    ),
  );
}

class LocationPinPickerScreen extends ConsumerStatefulWidget {
  const LocationPinPickerScreen({super.key, required this.title, this.initial});

  final String title;
  final LatLng? initial;

  @override
  ConsumerState<LocationPinPickerScreen> createState() => _LocationPinPickerScreenState();
}

class _LocationPinPickerScreenState extends ConsumerState<LocationPinPickerScreen> {
  /// Where the map opens when there is nothing better: the middle of southern India, zoomed out, so
  /// the first thing on screen is a recognisable map rather than the sea off Africa.
  static const _fallbackCentre = LatLng(10.0, 77.5);

  /// Rooftop level, which is the point of pinning.
  static const _pinZoom = 18.0;

  /// Google's own map has the lanes and buildings, so it opens on that. Without Google the free
  /// street map has nothing drawn in many villages, so it opens on the satellite photo instead.
  MapStyle _style = useGoogleMaps ? MapStyle.street : MapStyle.satellite;

  /// Drawn by Google when a key is built in, otherwise the free tiles. Decided once per screen.
  final bool _google = useGoogleMaps;

  final _mapController = MapController();
  gm.GoogleMapController? _googleController;

  /// Set while the app itself is moving the Google map, so that move is not taken for a drag.
  bool _movingProgrammatically = false;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  late LatLng _centre = widget.initial ?? _fallbackCentre;

  /// The address for [_centre], or null while it is being looked up.
  SearchedPlace? _place;
  LatLng? _placeFor;
  bool _isNaming = false;
  bool _isLocating = false;
  bool _hasMoved = false;

  List<SearchedPlace>? _results;
  bool _isSearching = false;
  Timer? _searchDebounce;
  Timer? _nameDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _hasMoved = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _nameCentre());
    } else {
      // Straight to the phone's own position: most jobs are booked from the place they happen at.
      WidgetsBinding.instance.addPostFrameCallback((_) => _useMyLocation(quiet: true));
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _nameDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _mapController.dispose();
    _googleController?.dispose();
    super.dispose();
  }

  // ---- Google map events --------------------------------------------------------------------------

  void _onGoogleMapCreated(gm.GoogleMapController controller) {
    _googleController = controller;
    // A location found before the map existed (GPS answering fast) is applied now.
    if (_hasMoved) {
      _movingProgrammatically = true;
      controller.moveCamera(
        gm.CameraUpdate.newLatLngZoom(gm.LatLng(_centre.latitude, _centre.longitude), _pinZoom),
      );
    }
  }

  void _onGoogleMoveStarted() {
    if (_movingProgrammatically) return;
    _hasMoved = true;
    if (_results != null) setState(() => _results = null);
    _searchFocus.unfocus();
  }

  void _onGoogleMove(gm.CameraPosition position) {
    _centre = LatLng(position.target.latitude, position.target.longitude);
    if (_place != null) setState(() => _place = null);
  }

  void _onGoogleIdle() {
    _movingProgrammatically = false;
    if (!_hasMoved) return;
    _nameDebounce?.cancel();
    _nameDebounce = Timer(const Duration(milliseconds: 300), _nameCentre);
  }

  // ---- Naming the spot under the pin --------------------------------------------------------------

  void _onMapMoved(MapCamera camera, bool hasGesture) {
    _centre = camera.center;
    if (hasGesture) {
      _hasMoved = true;
      if (_results != null) setState(() => _results = null);
      _searchFocus.unfocus();
    }
    // Named once the map has settled, not on every frame of a drag.
    _nameDebounce?.cancel();
    _nameDebounce = Timer(const Duration(milliseconds: 600), _nameCentre);
    if (_place != null) setState(() => _place = null);
  }

  Future<void> _nameCentre() async {
    final at = _centre;
    setState(() => _isNaming = true);
    final place = await ref
        .read(placeSearchClientProvider)
        .reverse(latitude: at.latitude, longitude: at.longitude, precise: true);
    // The map may have moved again while this was in flight; only the latest answer counts.
    if (!mounted || at != _centre) return;
    setState(() {
      _place = place;
      _placeFor = at;
      _isNaming = false;
    });
  }

  // ---- Current location ---------------------------------------------------------------------------

  Future<void> _useMyLocation({bool quiet = false}) async {
    setState(() => _isLocating = true);
    final result = await ref.read(locationServiceProvider).current(precise: true);
    if (!mounted) return;
    setState(() => _isLocating = false);

    if (result.hasPosition) {
      // Whatever went wrong before has been put right; a warning left on screen now is wrong.
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _hasMoved = true;
      _moveTo(LatLng(result.latitude!, result.longitude!));
      if (result.isApproximate) {
        _say('Showing your last known location. Drag the map to the exact place.');
      }
      return;
    }

    // Opening on the phone's position is a convenience; failing it quietly leaves search and
    // dragging, which work without any permission.
    // In a browser a blocked permission is the browser's setting, so opening the map should not
    // greet anyone with instructions they did not ask for; they appear when ◎ is tapped.
    if (quiet &&
        (result.problem == LocationProblem.denied ||
            (kIsWeb && result.problem == LocationProblem.deniedForever))) {
      return;
    }
    _explain(result.problem);
  }

  void _explain(LocationProblem? problem) {
    final help = locationHelp(problem, isWeb: kIsWeb);

    if (help.isDialog) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.location_off_outlined),
          title: Text(help.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(help.message),
              const SizedBox(height: 12),
              for (final (i, step) in help.steps.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${i + 1}.  '),
                      Expanded(child: Text(step)),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _searchFocus.requestFocus();
              },
              child: const Text('Search instead'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final service = ref.read(locationServiceProvider);
    switch (help.action) {
      case LocationHelpAction.openAppSettings:
        _say(help.message, actionLabel: 'Settings', action: service.openSettings);
      case LocationHelpAction.openLocationSettings:
        _say(help.message, actionLabel: 'Turn on', action: service.openLocationSettings);
      case null:
        _say(help.message);
    }
  }

  /// A short message that goes away on its own, and can be closed by hand.
  ///
  /// Not persistent even with a button: a SnackBar with an action otherwise stays until tapped, which
  /// left "location is off" on screen long after location had been turned on.
  void _say(String message, {String? actionLabel, VoidCallback? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 6),
          persist: false,
          showCloseIcon: true,
          action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: action!),
        ),
      );
  }

  void _moveTo(LatLng point) {
    _centre = point;
    if (_google) {
      _movingProgrammatically = true;
      _googleController?.animateCamera(
        gm.CameraUpdate.newLatLngZoom(gm.LatLng(point.latitude, point.longitude), _pinZoom),
      );
    } else {
      _mapController.move(point, _pinZoom);
    }
    _nameDebounce?.cancel();
    _nameCentre();
  }

  // ---- Search -------------------------------------------------------------------------------------

  void _onSearchChanged(String text) {
    _searchDebounce?.cancel();
    if (text.trim().length < 3) {
      setState(() => _results = null);
      return;
    }
    // A pause, not a request per keystroke: the map provider asks clients not to autocomplete.
    _searchDebounce = Timer(const Duration(milliseconds: 650), () => _search(text));
  }

  Future<void> _search(String text) async {
    setState(() => _isSearching = true);
    List<SearchedPlace> results;
    try {
      results = await ref.read(placeSearchClientProvider).search(text.trim());
    } on Exception {
      results = const [];
    }
    if (!mounted || _searchController.text != text) return;
    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  void _pickResult(SearchedPlace place) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _searchFocus.unfocus();
    setState(() => _results = null);
    _hasMoved = true;
    _moveTo(LatLng(place.latitude, place.longitude));
  }

  // ---- Confirm ------------------------------------------------------------------------------------

  Future<void> _confirm() async {
    if (!_hasMoved) {
      _say('Move the map so the pin sits on the job location first.');
      return;
    }
    var place = _place;
    if (place == null || _placeFor != _centre) {
      // Confirmed before the name came back: ask once more rather than lose the address.
      place = await ref
          .read(placeSearchClientProvider)
          .reverse(latitude: _centre.latitude, longitude: _centre.longitude, precise: true);
      if (!mounted) return;
    }

    Navigator.of(context).pop(
      PickedLocation(
        latitude: _centre.latitude,
        longitude: _centre.longitude,
        label: place?.name,
        fullAddress: place?.fullName,
        street: place?.street,
        locality: place?.locality,
        city: place?.city,
        state: place?.state,
        postalCode: place?.postalCode,
      ),
    );
  }

  // ---- UI -----------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                if (_google)
                  gm.GoogleMap(
                    key: const Key('pinPickerGoogleMap'),
                    initialCameraPosition: gm.CameraPosition(
                      target: gm.LatLng(_centre.latitude, _centre.longitude),
                      zoom: widget.initial != null ? _pinZoom : 5,
                    ),
                    // Hybrid: the photograph with Google's road and place names on it.
                    mapType: _style == MapStyle.satellite ? gm.MapType.hybrid : gm.MapType.normal,
                    onMapCreated: _onGoogleMapCreated,
                    onCameraMoveStarted: _onGoogleMoveStarted,
                    onCameraMove: _onGoogleMove,
                    onCameraIdle: _onGoogleIdle,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                  )
                else
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _centre,
                      initialZoom: widget.initial != null ? _pinZoom : 6,
                      maxZoom: kMapMaxZoom,
                      onPositionChanged: _onMapMoved,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.pinchZoom |
                            InteractiveFlag.drag |
                            InteractiveFlag.doubleTapZoom |
                            InteractiveFlag.scrollWheelZoom,
                      ),
                    ),
                    children: [
                      ...baseMapLayers(_style),
                      mapAttribution(_style),
                    ],
                  ),

                // The pin itself, fixed in the middle; its point is the map's centre.
                IgnorePointer(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 44),
                      child: Icon(
                        Icons.location_on,
                        size: 48,
                        color: theme.colorScheme.error,
                        shadows: const [Shadow(blurRadius: 6, color: AppColors.shadowStrong)],
                      ),
                    ),
                  ),
                ),

                // Search.
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Material(
                        elevation: 3,
                        borderRadius: BorderRadius.circular(14),
                        child: TextField(
                          key: const Key('pinPickerSearch'),
                          controller: _searchController,
                          focusNode: _searchFocus,
                          onChanged: _onSearchChanged,
                          onSubmitted: (text) {
                            _searchDebounce?.cancel();
                            if (text.trim().length >= 3) _search(text);
                          },
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'Search area, street or landmark',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _isSearching
                                ? const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      if (_results case final results?)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Material(
                            elevation: 3,
                            borderRadius: BorderRadius.circular(14),
                            clipBehavior: Clip.antiAlias,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 260),
                              child: results.isEmpty
                                  ? const ListTile(
                                      leading: Icon(Icons.search_off),
                                      title: Text('No place found. Try a nearby town or landmark.'),
                                    )
                                  : ListView(
                                      shrinkWrap: true,
                                      padding: EdgeInsets.zero,
                                      children: [
                                        for (final place in results)
                                          ListTile(
                                            dense: true,
                                            leading: const Icon(Icons.place_outlined),
                                            title: Text(place.name),
                                            subtitle: Text(
                                              place.fullName,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            onTap: () => _pickResult(place),
                                          ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Satellite or street map.
                Positioned(
                  left: 12,
                  bottom: 16,
                  child: Material(
                    elevation: 3,
                    borderRadius: BorderRadius.circular(20),
                    color: theme.colorScheme.surface,
                    child: SegmentedButton<MapStyle>(
                      key: const Key('pinPickerMapStyle'),
                      showSelectedIcon: false,
                      style: const ButtonStyle(visualDensity: VisualDensity.compact),
                      segments: const [
                        ButtonSegment(
                          value: MapStyle.satellite,
                          icon: Icon(Icons.satellite_alt_outlined, size: 18),
                          label: Text('Satellite'),
                        ),
                        ButtonSegment(
                          value: MapStyle.street,
                          icon: Icon(Icons.map_outlined, size: 18),
                          label: Text('Map'),
                        ),
                      ],
                      selected: {_style},
                      onSelectionChanged: (s) => setState(() => _style = s.first),
                    ),
                  ),
                ),

                // Current location. Raised clear of the map-credit button in the corner.
                Positioned(
                  right: 12,
                  bottom: 64,
                  child: FloatingActionButton.small(
                    heroTag: 'pinPickerMyLocation',
                    tooltip: 'Use my current location',
                    onPressed: _isLocating ? null : () => _useMyLocation(),
                    child: _isLocating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),

          // What the pin is on, and the button that accepts it.
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: theme.colorScheme.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: !_hasMoved
                            ? Text(
                                _isLocating
                                    ? 'Finding your location…'
                                    : 'Search the place, or tap ◎ to jump to where you are.',
                                style: theme.textTheme.bodyMedium,
                              )
                            : _isNaming && _place == null
                            ? Text('Finding the address…', style: theme.textTheme.bodyMedium)
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _place?.street ?? _place?.name ?? 'Pinned location',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  Text(
                                    _place?.fullName ??
                                        '${_centre.latitude.toStringAsFixed(5)}, '
                                            '${_centre.longitude.toStringAsFixed(5)}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Zoom in and drag the map so the pin sits on the house roof or gate.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const Key('pinPickerConfirm'),
                    onPressed: _confirm,
                    child: const Text('Confirm location'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
