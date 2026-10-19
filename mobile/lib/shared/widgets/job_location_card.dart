import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:zuno/core/maps/google_maps_config.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/shared/widgets/map_layers.dart';

/// Where a job is: a small map with its pin, the address, and a way to get there.
///
/// Directions open Google Maps (the app where installed, otherwise the browser) at the exact pin,
/// rather than at the typed address — the pin is what the customer placed on their own door. A job
/// booked before pinning existed has no pin, so it shows the address and searches for it instead.
class JobLocationCard extends StatelessWidget {
  const JobLocationCard({
    super.key,
    required this.addressLines,
    this.latitude,
    this.longitude,
    this.caption,
    this.showActions = true,
  });

  /// The typed address, most specific first. Blank entries are skipped.
  final List<String?> addressLines;
  final double? latitude;
  final double? longitude;

  /// A short line over the address, such as "Exact location from the customer".
  final String? caption;

  /// Off for read-only previews, such as a hiring post form.
  final bool showActions;

  bool get _hasPin => latitude != null && longitude != null;

  String get _address => addressLines
      .whereType<String>()
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .join(', ');

  /// Navigation to the pin, or a search for the address when there is no pin.
  Uri get _mapsUri => _hasPin
      ? Uri.https('www.google.com', '/maps/dir/', {
          'api': '1',
          'destination': '$latitude,$longitude',
        })
      : Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': _address});

  Future<void> _openMaps(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await launchUrl(_mapsUri, mode: LaunchMode.externalApplication);
    if (!opened) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not open Maps on this device.')));
    }
  }

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: _address));
    messenger.showSnackBar(const SnackBar(content: Text('Address copied')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = AppColors.status(StatusTone.success, theme.brightness);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_hasPin && useGoogleMaps)
            SizedBox(
              height: 160,
              // Google's map with the lanes and buildings, as a still picture: gestures off so the
              // page scrolls past it. Lite mode on Android draws it as a static image, cheaply.
              child: IgnorePointer(
                child: gm.GoogleMap(
                  initialCameraPosition: gm.CameraPosition(
                    target: gm.LatLng(latitude!, longitude!),
                    zoom: 17,
                  ),
                  liteModeEnabled: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
                  markers: {
                    gm.Marker(
                      markerId: const gm.MarkerId('job'),
                      position: gm.LatLng(latitude!, longitude!),
                    ),
                  },
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  myLocationButtonEnabled: false,
                  scrollGesturesEnabled: false,
                  zoomGesturesEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                ),
              ),
            )
          else if (_hasPin)
            SizedBox(
              height: 140,
              child: Stack(
                children: [
                  // A picture of the spot, not a map to explore: every gesture is off so the page
                  // around it still scrolls when a thumb lands on it.
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(latitude!, longitude!),
                      // Close enough to recognise the house in the photograph.
                      initialZoom: 18,
                      maxZoom: kMapMaxZoom,
                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                    ),
                    children: [
                      // The photograph rather than the street map: it is what lets somebody
                      // recognise the house on arrival, and many villages have no streets drawn.
                      ...baseMapLayers(MapStyle.satellite),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(latitude!, longitude!),
                            width: 40,
                            height: 40,
                            alignment: Alignment.topCenter,
                            child: Icon(
                              Icons.location_on,
                              size: 40,
                              color: theme.colorScheme.error,
                              shadows: const [Shadow(blurRadius: 4, color: AppColors.shadowStrong)],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    right: 6,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      color: theme.colorScheme.surface.withValues(alpha: 0.7),
                      child: Text(
                        mapCreditText(MapStyle.satellite),
                        style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _hasPin ? Icons.verified_outlined : Icons.info_outline,
                      size: 16,
                      color: _hasPin ? ok : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _hasPin
                            ? (caption ?? 'Exact location pinned on the map')
                            : 'No map pin for this order — address only',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: _hasPin ? ok : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SelectableText(
                  _address.isEmpty ? 'No address given' : _address,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (showActions)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('jobLocationDirections'),
                      onPressed: () => _openMaps(context),
                      icon: Icon(_hasPin ? Icons.directions : Icons.map_outlined, size: 18),
                      label: Text(_hasPin ? 'Directions' : 'Search in Maps'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _address.isEmpty ? null : () => _copy(context),
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy address'),
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
