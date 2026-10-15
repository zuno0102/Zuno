import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/worker/domain/entities/worker_dashboard.dart';
import 'package:zuno/features/worker/presentation/providers/worker_providers.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';

part 'worker_dashboard_notifier.g.dart';

/// The worker's home screen, and the one place their own details are changed.
///
/// Class-based rather than a plain future because saving the profile has to put the new figures back
/// on screen: the dashboard carries the profile, so an edit that did not refresh would leave a
/// worker looking at the phone number they just replaced.
@riverpod
class WorkerDashboardNotifier extends _$WorkerDashboardNotifier {
  @override
  Future<WorkerDashboard> build() async =>
      (await ref.watch(workerRemoteDataSourceProvider).getDashboard()).toEntity();

  /// Saves whichever fields were given and reloads the screen.
  ///
  /// Nulls mean "leave alone" all the way down to the request body, so a form that only touched the
  /// hourly rate cannot blank out a UPI address.
  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? upiVpa,
    double? hourlyRate,
    int? experienceYears,
  }) async {
    await ref
        .read(workerRemoteDataSourceProvider)
        .updateMyProfile(
          firstName: firstName,
          lastName: lastName,
          phoneNumber: phoneNumber,
          upiVpa: upiVpa,
          hourlyRate: hourlyRate,
          experienceYears: experienceYears,
        );

    await _refresh();

    // The name lives on the account, not on this profile, and the header across the top of every
    // worker tab reads it from there. Without this the worker saw their new name on the profile
    // page and their old one above it.
    if (firstName != null || lastName != null) {
      await ref.read(authProvider.notifier).refreshUser();
    }
  }


  /// Uploads a new profile picture and reloads the screen.
  Future<void> setPhoto({
    required String filePath,
    required String contentType,
  }) async {
    await ref
        .read(workerRemoteDataSourceProvider)
        .setPhoto(filePath: filePath, contentType: contentType);

    await _refresh();
  }
  /// Reloads without flicking the screen back to a spinner.
  ///
  /// Deliberately not `state = AsyncLoading()`: the sheet that triggered this is still on screen
  /// awaiting the result, and tearing the page down under it unmounts the widget mid-await.
  Future<void> _refresh() async {
    final fresh = await ref
        .read(workerRemoteDataSourceProvider)
        .getDashboard();
    state = AsyncData(fresh.toEntity());
  }
}
