import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Which picture of the ground a map shows.
enum MapStyle {
  /// Photographs from above, with road and place names on top. The view where a customer can see
  /// their own roof — OpenStreetMap has almost nothing drawn in many villages, so the street map
  /// there is empty land.
  satellite,

  /// The OpenStreetMap street map.
  street,
}

/// Deepest zoom offered. Past each source's own deepest level its tiles are enlarged rather than
/// going blank.
const double kMapMaxZoom = 20;

/// The street map has real tiles down to 19.
const int _maxNativeZoom = 19;

/// The photographs stop at 18 outside big cities: at 19 rural Kanniyakumari returns a grey "Map
/// data not yet available" tile. Enlarging 18 keeps the rooftops on screen instead.
const int _satelliteMaxNativeZoom = 18;

const _userAgent = 'com.zuno.zuno';

/// The tile layers for [style], bottom first. Goes in a `FlutterMap`'s children before markers.
List<Widget> baseMapLayers(MapStyle style) => switch (style) {
  MapStyle.satellite => [
    TileLayer(
      urlTemplate:
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      userAgentPackageName: _userAgent,
      maxNativeZoom: _satelliteMaxNativeZoom,
    ),
    // Names over the photograph: without them a satellite view is a picture with no way to tell
    // which lane is which.
    TileLayer(
      urlTemplate:
          'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}',
      userAgentPackageName: _userAgent,
      maxNativeZoom: _satelliteMaxNativeZoom,
    ),
    TileLayer(
      urlTemplate:
          'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
      userAgentPackageName: _userAgent,
      maxNativeZoom: _satelliteMaxNativeZoom,
    ),
  ],
  MapStyle.street => [
    TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: _userAgent,
      maxNativeZoom: _maxNativeZoom,
    ),
  ],
};

/// The credit line each map provider requires. Goes last in a `FlutterMap`'s children.
Widget mapAttribution(MapStyle style) => RichAttributionWidget(
  attributions: [
    switch (style) {
      MapStyle.satellite => const TextSourceAttribution(
        'Imagery © Esri, Maxar, Earthstar Geographics',
      ),
      MapStyle.street => const TextSourceAttribution('OpenStreetMap contributors'),
    },
  ],
);

/// The short credit for small, non-interactive previews where the full widget does not fit.
String mapCreditText(MapStyle style) => switch (style) {
  MapStyle.satellite => '© Esri, Maxar',
  MapStyle.street => '© OpenStreetMap',
};
