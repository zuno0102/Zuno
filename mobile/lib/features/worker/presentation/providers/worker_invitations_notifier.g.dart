// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worker_invitations_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WorkerInvitationsNotifier)
final workerInvitationsProvider = WorkerInvitationsNotifierProvider._();

final class WorkerInvitationsNotifierProvider
    extends
        $AsyncNotifierProvider<
          WorkerInvitationsNotifier,
          List<WorkerInvitation>
        > {
  WorkerInvitationsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workerInvitationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workerInvitationsNotifierHash();

  @$internal
  @override
  WorkerInvitationsNotifier create() => WorkerInvitationsNotifier();
}

String _$workerInvitationsNotifierHash() =>
    r'f8c1fe79389fffb6fd05d2cc90ffa52e0ee1336e';

abstract class _$WorkerInvitationsNotifier
    extends $AsyncNotifier<List<WorkerInvitation>> {
  FutureOr<List<WorkerInvitation>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<WorkerInvitation>>, List<WorkerInvitation>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<WorkerInvitation>>,
                List<WorkerInvitation>
              >,
              AsyncValue<List<WorkerInvitation>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
