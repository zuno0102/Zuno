/// Loads the Google Maps JavaScript API on the web before the first map is drawn.
///
/// Injected at start-up rather than written into `web/index.html`, so the key comes from the build
/// (`--dart-define`) instead of a file in git, and a build without a key loads nothing at all.
/// On Android and iOS the native SDK is configured by the platform project instead, so this is a
/// no-op there.
library;

export 'google_maps_loader_stub.dart'
    if (dart.library.js_interop) 'google_maps_loader_web.dart';
