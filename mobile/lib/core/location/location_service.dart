import 'package:geolocator/geolocator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'location_service.g.dart';

/// Where the phone is, and why it could not say.
///
/// An interface rather than calls to geolocator scattered through widgets, because the plugin cannot
/// run in a widget test — without this seam the whole nearby-jobs UI would be untestable.
abstract class LocationService {
  /// The phone's position, or a reason it is unavailable. Never throws.
  Future<LocationResult> current();

  /// Opens the system settings page, for a worker who denied the permission permanently.
  Future<void> openSettings();

  /// Opens the phone's location settings, for when location is off device-wide.
  ///
  /// Distinct from [openSettings]: the app's own permission page cannot turn the radio on, so
  /// sending somebody there when the problem is the system switch wastes the trip.
  Future<void> openLocationSettings();
}

/// Why a position could not be read. Each one needs different words on screen.
enum LocationProblem {
  /// The worker said no, but can be asked again.
  denied,

  /// The worker said never. Only the system settings screen can undo it.
  deniedForever,

  /// Location is switched off for the whole phone, so no app can read it.
  serviceDisabled,

  /// Asked and never answered — indoors, or a cold GPS start.
  timedOut,

  /// The plugin failed for some other reason.
  failed,
}

/// Either a position or a reason there is none.
class LocationResult {
  const LocationResult.found(this.latitude, this.longitude)
    : problem = null,
      isApproximate = false;

  const LocationResult.approximate(this.latitude, this.longitude)
    : problem = null,
      isApproximate = true;

  const LocationResult.unavailable(this.problem)
    : latitude = null,
      longitude = null,
      isApproximate = false;

  final double? latitude;
  final double? longitude;
  final LocationProblem? problem;

  /// A last-known fix rather than a fresh one, so it may be stale or coarse.
  final bool isApproximate;

  bool get hasPosition => latitude != null && longitude != null;
}

class GeolocatorLocationService implements LocationService {
  @override
  Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.unavailable(LocationProblem.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.unavailable(LocationProblem.deniedForever);
      }

      if (permission == LocationPermission.denied) {
        return const LocationResult.unavailable(LocationProblem.denied);
      }

      try {
        // Low accuracy on purpose. The tightest radius offered is a kilometre, so a coarse fix is
        // ample, and asking for less precision is faster, kinder to the battery, and satisfied by
        // the "Approximate" choice Android 12 and later offer.
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 10),
          ),
        );
        return LocationResult.found(position.latitude, position.longitude);
      } on Exception {
        // A fix indoors can simply never arrive. Yesterday's position is far better than refusing
        // to show any jobs at all — a worker has not usually moved districts overnight.
        final last = await Geolocator.getLastKnownPosition();
        return last == null
            ? const LocationResult.unavailable(LocationProblem.timedOut)
            : LocationResult.approximate(last.latitude, last.longitude);
      }
    } on Exception {
      return const LocationResult.unavailable(LocationProblem.failed);
    }
  }

  @override
  Future<void> openSettings() => Geolocator.openAppSettings();

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}

@Riverpod(keepAlive: true)
LocationService locationService(Ref ref) => GeolocatorLocationService();
