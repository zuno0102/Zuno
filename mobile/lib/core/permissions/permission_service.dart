import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'permission_service.g.dart';

/// What the app may use on this phone, and asking for it.
///
/// An interface rather than calls to the plugin scattered through widgets, for the same reason
/// [LocationService] is one: the plugin cannot run in a widget test, so without this seam the
/// permission flow would be untestable.
///
/// Location is deliberately absent. It is asked for at the moment somebody picks a place, by the
/// location service, and putting it here would be the first step towards asking for it at launch —
/// which is exactly what a worker who has not opened Find work should not be asked.
abstract class PermissionService {
  /// Whether the camera has already been granted.
  Future<bool> hasCamera();

  /// What the phone currently allows, without asking it for anything.
  ///
  /// The distinction matters more than it looks. Reading a status never puts a dialog on screen;
  /// requesting one does. The App permissions page used to find out where it stood by *asking* for
  /// a location — so opening a settings page to read a row triggered the very prompt the app
  /// promises to save for the moment somebody picks a place.
  Future<PermissionSnapshot> snapshot();

  /// Asks for everything the app needs before somebody runs into it mid-task.
  ///
  /// Returns what was granted, never throws.
  Future<PermissionOutcome> requestEssentials();

  /// Opens the app's own settings page, for a permission refused for good.
  Future<void> openAppSettings();
}

/// Where a single permission stands.
enum PermissionState {
  /// Allowed. On iOS photos this also covers "selected photos only", which is enough.
  granted,

  /// Refused, but can be asked again.
  denied,

  /// Refused for good, or blocked by the device. Only the settings screen can undo it.
  blocked,

  /// Nothing has been asked yet.
  notAsked,
}

/// What the phone allows right now, read without prompting for anything.
class PermissionSnapshot {
  const PermissionSnapshot({required this.camera, required this.location});

  final PermissionState camera;

  /// Read, never requested. Asking for it belongs on the control that needs a place.
  final PermissionState location;
}

/// What came back from asking.
class PermissionOutcome {
  const PermissionOutcome({
    required this.cameraGranted,
    required this.photosGranted,
    this.cameraPermanentlyDenied = false,
  });

  final bool cameraGranted;

  /// Android needs no permission for the gallery — `image_picker` goes through the system photo
  /// picker, which hands back one chosen image and nothing else. This is always true there, and is
  /// a real answer only on iOS.
  final bool photosGranted;

  /// Refused with "don't ask again". Only the settings screen can undo it, so the words on screen
  /// have to change.
  final bool cameraPermanentlyDenied;

  bool get allGranted => cameraGranted && photosGranted;
}

class PermissionHandlerService implements PermissionService {
  const PermissionHandlerService();

  @override
  Future<bool> hasCamera() async {
    try {
      return await ph.Permission.camera.isGranted;
    } catch (_) {
      // A phone that cannot answer is treated as not granted: the worst outcome is asking once
      // more, where guessing "granted" would be a camera screen that silently shows nothing.
      return false;
    }
  }

  @override
  Future<PermissionSnapshot> snapshot() async => PermissionSnapshot(
    camera: await _status(ph.Permission.camera),
    // `status`, not `request`. This is the whole point of the method.
    //
    // A browser knows only `location`. Asked about `locationWhenInUse`, the web plugin throws an
    // UnimplementedError — an Error, which `on Exception` let through — and the App permissions
    // page sat on "Checking…" for good.
    location: await _status(
      kIsWeb ? ph.Permission.location : ph.Permission.locationWhenInUse,
    ),
  );

  /// One permission's state. Read on its own so a failure in one leaves the other readable, and
  /// caught whole — Error as well as Exception — so a platform that cannot answer reads as "not
  /// asked" instead of leaving the page waiting.
  static Future<PermissionState> _status(ph.Permission permission) async {
    try {
      return _read(await permission.status);
    } catch (_) {
      return PermissionState.notAsked;
    }
  }

  static PermissionState _read(ph.PermissionStatus status) => switch (status) {
    ph.PermissionStatus.granted || ph.PermissionStatus.limited =>
      PermissionState.granted,
    ph.PermissionStatus.permanentlyDenied ||
    ph.PermissionStatus.restricted => PermissionState.blocked,
    ph.PermissionStatus.denied => PermissionState.notAsked,
    _ => PermissionState.denied,
  };

  @override
  Future<PermissionOutcome> requestEssentials() async {
    // A browser does not work this way. It asks for the camera itself, at the moment a page
    // actually uses it, and choosing a picture there is an ordinary file input that needs no
    // permission at all — so there is nothing to ask for ahead of time, and asking would mean
    // prompting for something this app cannot grant.
    if (kIsWeb) {
      return const PermissionOutcome(cameraGranted: true, photosGranted: true);
    }

    try {
      final camera = await ph.Permission.camera.request();

      // Asked only on iOS, where the gallery genuinely needs it. On Android the request would
      // resolve against READ_MEDIA_IMAGES, which this app does not declare and does not need —
      // and an undeclared permission comes back permanently denied, which would put a dialog on
      // screen telling somebody to fix something that was never broken.
      //
      // Read from defaultTargetPlatform rather than dart:io's Platform, which throws on the web
      // with an UnsupportedError — an Error, not an Exception, so the catch below would not have
      // held it and the whole call failed.
      final photos = defaultTargetPlatform == TargetPlatform.iOS
          ? await ph.Permission.photos.request()
          : ph.PermissionStatus.granted;

      return PermissionOutcome(
        cameraGranted: camera.isGranted || camera.isLimited,
        photosGranted: photos.isGranted || photos.isLimited,
        cameraPermanentlyDenied: camera.isPermanentlyDenied,
      );
    } catch (_) {
      return const PermissionOutcome(cameraGranted: false, photosGranted: false);
    }
  }

  @override
  Future<void> openAppSettings() async {
    try {
      await ph.openAppSettings();
    } catch (_) {
      // Nothing more to offer if the settings screen will not open.
    }
  }
}

@Riverpod(keepAlive: true)
PermissionService permissionService(Ref ref) => const PermissionHandlerService();
