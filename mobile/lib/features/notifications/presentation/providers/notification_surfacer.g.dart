// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_surfacer.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Decides which notifications are worth interrupting somebody with, and draws those.
///
/// The rule it exists to enforce: **a notification is drawn in the shade once, ever.** Everything
/// else here follows from that. The app re-reads the same list on every resume, so without a record
/// of what has already been shown, somebody who opens Zuno four times in an afternoon would get
/// four copies of the same banner — which is how an app teaches people to turn it off.
///
/// Ids are remembered rather than a high-water timestamp. Two notifications written in the same
/// second are ordinary — one assignment tells a customer and a worker at once — and a timestamp
/// comparison would silently drop one of them.

@ProviderFor(NotificationSurfacer)
final notificationSurfacerProvider = NotificationSurfacerProvider._();

/// Decides which notifications are worth interrupting somebody with, and draws those.
///
/// The rule it exists to enforce: **a notification is drawn in the shade once, ever.** Everything
/// else here follows from that. The app re-reads the same list on every resume, so without a record
/// of what has already been shown, somebody who opens Zuno four times in an afternoon would get
/// four copies of the same banner — which is how an app teaches people to turn it off.
///
/// Ids are remembered rather than a high-water timestamp. Two notifications written in the same
/// second are ordinary — one assignment tells a customer and a worker at once — and a timestamp
/// comparison would silently drop one of them.
final class NotificationSurfacerProvider
    extends $NotifierProvider<NotificationSurfacer, void> {
  /// Decides which notifications are worth interrupting somebody with, and draws those.
  ///
  /// The rule it exists to enforce: **a notification is drawn in the shade once, ever.** Everything
  /// else here follows from that. The app re-reads the same list on every resume, so without a record
  /// of what has already been shown, somebody who opens Zuno four times in an afternoon would get
  /// four copies of the same banner — which is how an app teaches people to turn it off.
  ///
  /// Ids are remembered rather than a high-water timestamp. Two notifications written in the same
  /// second are ordinary — one assignment tells a customer and a worker at once — and a timestamp
  /// comparison would silently drop one of them.
  NotificationSurfacerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationSurfacerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationSurfacerHash();

  @$internal
  @override
  NotificationSurfacer create() => NotificationSurfacer();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$notificationSurfacerHash() =>
    r'258f62b3df6bffb12bd35d27bbc204448f4d6d8a';

/// Decides which notifications are worth interrupting somebody with, and draws those.
///
/// The rule it exists to enforce: **a notification is drawn in the shade once, ever.** Everything
/// else here follows from that. The app re-reads the same list on every resume, so without a record
/// of what has already been shown, somebody who opens Zuno four times in an afternoon would get
/// four copies of the same banner — which is how an app teaches people to turn it off.
///
/// Ids are remembered rather than a high-water timestamp. Two notifications written in the same
/// second are ordinary — one assignment tells a customer and a worker at once — and a timestamp
/// comparison would silently drop one of them.

abstract class _$NotificationSurfacer extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
