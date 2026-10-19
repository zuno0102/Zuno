import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:zuno/core/location/location_service.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/worker/presentation/widgets/place_search_sheet.dart';

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

  /// Close enough to see individual buildings, which is the point of pinning.
  static const _pinZoom = 17.0;

  final _mapController = MapController();
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
    super.dispose();
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
      _hasMoved = true;
      _moveTo(LatLng(result.latitude!, result.longitude!));
      if (result.isApproximate) {
        _say('Showing your last known location. Drag the map to the exact place.');
      }
      return;
    }

    // Opening on the phone's position is a convenience; failing it quietly leaves search and
    // dragging, which work without any permission.
    if (quiet && result.problem == LocationProblem.denied) return;
    _explain(result.problem);
  }

  void _explain(LocationProblem? problem) {
    final service = ref.read(locationServiceProvider);
    switch (problem) {
      case LocationProblem.deniedForever:
        _say(
          'Location permission is off for Zuno. Search for the place instead, or allow it in settings.',
          actionLabel: 'Settings',
          action: service.openSettings,
        );
      case LocationProblem.serviceDisabled:
        _say(
          'Location is turned off on this phone. Turn it on, or search for the place.',
          actionLabel: 'Turn on',
          action: service.openLocationSettings,
        );
      case LocationProblem.timedOut:
        _say('Could not get a GPS fix here. Search for the place, then drag the map to it.');
      case LocationProblem.denied:
        _say('Location permission was not given. Search for the place instead.');
      case LocationProblem.failed:
      case null:
        _say('Could not read your location. Search for the place instead.');
    }
  }

  void _say(String message, {String? actionLabel, VoidCallback? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: action!),
        ),
      );
  }

  void _moveTo(LatLng point) {
    _centre = point;
    _mapController.move(point, _pinZoom);
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
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _centre,
                    initialZoom: widget.initial != null ? _pinZoom : 6,
                    onPositionChanged: _onMapMoved,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.pinchZoom |
                          InteractiveFlag.drag |
                          InteractiveFlag.doubleTapZoom |
                          InteractiveFlag.scrollWheelZoom,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.zuno.zuno',
                    ),
                    const RichAttributionWidget(
                      attributions: [TextSourceAttribution('OpenStreetMap contributors')],
                    ),
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

                // Current location.
                Positioned(
                  right: 12,
                  bottom: 16,
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
                                    : 'Search, use your location, or drag the map to the job.',
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
                    'Drag the map so the pin sits on the exact house or gate.',
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
