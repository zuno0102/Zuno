import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'worker_job_filter_provider.g.dart';

/// What the worker has asked the job feed to show: where they are, and how far they will travel.
///
/// Deliberately a provider of its own rather than fields on the feed notifier. Pull-to-refresh calls
/// `ref.refresh` on the feed, which rebuilds that notifier from scratch — so a radius stored there
/// would silently snap back to its default every time the worker pulled the list down. Held apart, it
/// survives refresh, hot reload and moving between tabs, and it is the single place to add
/// persistence later.
class WorkerJobFilter {
  const WorkerJobFilter({
    this.latitude,
    this.longitude,
    this.placeLabel,
    this.radiusKm,
    this.isApproximate = false,
  });

  final double? latitude;
  final double? longitude;

  /// What to call the place on screen — "Your current location", or a searched place name.
  final String? placeLabel;

  /// Null means measure and sort but drop nothing, which is the state after sharing a position
  /// without yet choosing how far to travel.
  final int? radiusKm;

  /// The position is a last-known or coarse fix, so the screen should not imply precision.
  final bool isApproximate;

  bool get hasPosition => latitude != null && longitude != null;
  bool get isFiltering => hasPosition && radiusKm != null;

  /// Coordinates trimmed to three decimal places, which is about 110 metres.
  ///
  /// Sent instead of the raw fix because request URLs are logged on both sides — by the Dio logger
  /// here and by the server log there — and a worker's exact position does not belong in either.
  /// At the radii this feature offers the difference is immaterial.
  double? get coarseLatitude =>
      latitude == null ? null : double.parse(latitude!.toStringAsFixed(3));

  double? get coarseLongitude =>
      longitude == null ? null : double.parse(longitude!.toStringAsFixed(3));

  WorkerJobFilter copyWith({
    double? latitude,
    double? longitude,
    String? placeLabel,
    int? radiusKm,
    bool? isApproximate,
    bool clearRadius = false,
  }) => WorkerJobFilter(
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    placeLabel: placeLabel ?? this.placeLabel,
    radiusKm: clearRadius ? null : (radiusKm ?? this.radiusKm),
    isApproximate: isApproximate ?? this.isApproximate,
  );
}

@Riverpod(keepAlive: true)
class WorkerJobFilterNotifier extends _$WorkerJobFilterNotifier {
  /// The steps a worker chooses between.
  ///
  /// Close-spaced up to 30km, then wider. That is where the decision actually happens: whether a job
  /// is 10km or 15km away decides whether a worker takes it, while nobody weighs 150km against 175km.
  ///
  /// Discrete rather than a slider, because these are straight-line kilometres and road distance runs
  /// 15% to 80% further — offering a single-kilometre choice would imply a precision the number does
  /// not have. It also matches how somebody actually thinks about travel: the next town, or the next
  /// district.
  static const radiusSteps = <int>[2, 5, 10, 15, 20, 25, 30, 50, 100, 200];

  static const _keyLatitude = 'worker_filter_latitude';
  static const _keyLongitude = 'worker_filter_longitude';
  static const _keyLabel = 'worker_filter_label';
  static const _keyRadius = 'worker_filter_radius';

  @override
  WorkerJobFilter build() {
    // Loaded in the background rather than awaited, because the feed must not sit on a spinner
    // waiting for disk. The screen opens at its prompt and fills in a frame later if a saved
    // location exists.
    unawaited(_restore());
    return const WorkerJobFilter();
  }

  /// Brings back the location and distance the worker last chose.
  ///
  /// Kept on the device so setting a location is a once-ever act rather than a toll on every launch.
  /// A worker whose position was forgotten every time the app restarted would reasonably stop using
  /// the feature.
  ///
  /// A restored position is always treated as approximate: it may be days old, and presenting a
  /// stale fix as a live one is how somebody ends up searching around a town they have left.
  Future<void> _restore() async {
    try {
      final store = await SharedPreferences.getInstance();

      final latitude = store.getDouble(_keyLatitude);
      final longitude = store.getDouble(_keyLongitude);

      if (latitude == null || longitude == null) return;

      // Only if nothing has been chosen since: a worker who set a location while this was loading
      // must not have it overwritten by what they had yesterday.
      if (state.hasPosition) return;

      state = WorkerJobFilter(
        latitude: latitude,
        longitude: longitude,
        placeLabel: store.getString(_keyLabel),
        radiusKm: store.getInt(_keyRadius),
        isApproximate: true,
      );
    } on Exception {
      // A filter that cannot be read is not worth an error on screen; the prompt still works.
    }
  }

  Future<void> _save() async {
    try {
      final store = await SharedPreferences.getInstance();
      final filter = state;

      if (!filter.hasPosition) {
        await store.remove(_keyLatitude);
        await store.remove(_keyLongitude);
        await store.remove(_keyLabel);
        await store.remove(_keyRadius);
        return;
      }

      // The coarse coordinates, matching what is sent to the server. There is no reason to keep a
      // worker's exact position on disk when 110 metres is plenty at these distances.
      await store.setDouble(_keyLatitude, filter.coarseLatitude!);
      await store.setDouble(_keyLongitude, filter.coarseLongitude!);

      if (filter.placeLabel case final label?) {
        await store.setString(_keyLabel, label);
      }

      if (filter.radiusKm case final radius?) {
        await store.setInt(_keyRadius, radius);
      } else {
        await store.remove(_keyRadius);
      }
    } on Exception {
      // Failing to remember is a small loss; failing loudly would be a larger one.
    }
  }

  /// Records where the worker is, keeping whatever radius they had already chosen.
  void setPosition({
    required double latitude,
    required double longitude,
    required String placeLabel,
    bool isApproximate = false,
  }) {
    state = state.copyWith(
      latitude: latitude,
      longitude: longitude,
      placeLabel: placeLabel,
      isApproximate: isApproximate,
      // Starts at the tightest step: a worker asking for jobs near them means near, and widening is
      // one tap away.
      radiusKm: state.radiusKm ?? 2,
    );
    _save();
  }

  void setRadius(int radiusKm) {
    state = state.copyWith(radiusKm: radiusKm);
    _save();
  }

  /// Drops the distance limit but keeps where the worker is.
  ///
  /// "Anywhere" means no limit on distance, not "forget where I am" — and it used to mean the
  /// second, which threw the position away and bounced the worker back to the location prompt. The
  /// feed still needs a position to measure and sort by, so clearing it made the option unusable.
  void showAnywhere() {
    state = state.copyWith(clearRadius: true);
    _save();
  }

  /// A full reset, back to having no location at all.
  void clear() {
    state = const WorkerJobFilter();
    _save();
  }
}
