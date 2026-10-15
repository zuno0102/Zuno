// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worker_dashboard_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The worker's home screen, and the one place their own details are changed.
///
/// Class-based rather than a plain future because saving the profile has to put the new figures back
/// on screen: the dashboard carries the profile, so an edit that did not refresh would leave a
/// worker looking at the phone number they just replaced.

@ProviderFor(WorkerDashboardNotifier)
final workerDashboardProvider = WorkerDashboardNotifierProvider._();

/// The worker's home screen, and the one place their own details are changed.
///
/// Class-based rather than a plain future because saving the profile has to put the new figures back
/// on screen: the dashboard carries the profile, so an edit that did not refresh would leave a
/// worker looking at the phone number they just replaced.
final class WorkerDashboardNotifierProvider
    extends $AsyncNotifierProvider<WorkerDashboardNotifier, WorkerDashboard> {
  /// The worker's home screen, and the one place their own details are changed.
  ///
  /// Class-based rather than a plain future because saving the profile has to put the new figures back
  /// on screen: the dashboard carries the profile, so an edit that did not refresh would leave a
  /// worker looking at the phone number they just replaced.
  WorkerDashboardNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workerDashboardProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workerDashboardNotifierHash();

  @$internal
  @override
  WorkerDashboardNotifier create() => WorkerDashboardNotifier();
}

String _$workerDashboardNotifierHash() =>
    r'0cabc088b75065793991863aded67eda73c46650';

/// The worker's home screen, and the one place their own details are changed.
///
/// Class-based rather than a plain future because saving the profile has to put the new figures back
/// on screen: the dashboard carries the profile, so an edit that did not refresh would leave a
/// worker looking at the phone number they just replaced.

abstract class _$WorkerDashboardNotifier
    extends $AsyncNotifier<WorkerDashboard> {
  FutureOr<WorkerDashboard> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<WorkerDashboard>, WorkerDashboard>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<WorkerDashboard>, WorkerDashboard>,
              AsyncValue<WorkerDashboard>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
