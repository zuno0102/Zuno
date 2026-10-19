import 'package:flutter/foundation.dart';

/// The Google Maps key, supplied at build time: `--dart-define=GOOGLE_MAPS_KEY=...`.
///
/// One key does both jobs on a build — the web build loads the Maps JavaScript API with it, and the
/// Android build writes it into the manifest (see `android/app/build.gradle.kts`). Restrict it in the
/// Google Cloud console to this app's web address and Android package; it is visible to anyone who
/// opens the app, as every browser-side maps key is.
const String kGoogleMapsKey = String.fromEnvironment('GOOGLE_MAPS_KEY');

/// Whether maps are drawn by Google rather than the free OpenStreetMap/Esri tiles.
///
/// Google has the small lanes, buildings and shops that OpenStreetMap is missing in villages —
/// around Verkilambi it has seven roads where Google has dozens. Without a key everything falls back
/// to the free maps, so a build made without one still works. iOS is left on the free maps until its
/// key is wired into the Xcode project.
bool get useGoogleMaps =>
    kGoogleMapsKey.isNotEmpty &&
    !googleMapsUnavailable &&
    (kIsWeb || defaultTargetPlatform == TargetPlatform.android);

/// Set on the web when the Maps script could not be loaded (no network to Google, key refused), so
/// this session falls back to the free maps instead of showing grey boxes.
bool googleMapsUnavailable = false;
