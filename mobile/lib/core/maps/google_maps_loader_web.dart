import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;
import 'package:zuno/core/maps/google_maps_config.dart';

/// Adds the Maps JavaScript API to the page and waits for it, when a key was built in.
///
/// Never throws and never waits forever: a page that cannot reach Google still has to open, and the
/// maps then fall back to the free tiles for this session.
Future<void> loadGoogleMapsScript() async {
  if (!useGoogleMaps || _loaded) return;

  final script = web.HTMLScriptElement()
    ..src = 'https://maps.googleapis.com/maps/api/js'
        '?key=${Uri.encodeQueryComponent(kGoogleMapsKey)}'
        '&language=en&region=IN'
    ..async = true;

  final done = Completer<void>();
  script.addEventListener('load', ((web.Event _) => done.complete()).toJS);
  script.addEventListener(
    'error',
    ((web.Event _) {
      googleMapsUnavailable = true;
      if (!done.isCompleted) done.complete();
    }).toJS,
  );
  web.document.head!.append(script);

  await done.future.timeout(
    const Duration(seconds: 10),
    onTimeout: () => googleMapsUnavailable = true,
  );
  _loaded = true;
}

bool _loaded = false;
