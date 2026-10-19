// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(notificationDataSource)
final notificationDataSourceProvider = NotificationDataSourceProvider._();

final class NotificationDataSourceProvider
    extends
        $FunctionalProvider<
          NotificationRemoteDataSource,
          NotificationRemoteDataSource,
          NotificationRemoteDataSource
        >
    with $Provider<NotificationRemoteDataSource> {
  NotificationDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationDataSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationDataSourceHash();

  @$internal
  @override
  $ProviderElement<NotificationRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationRemoteDataSource create(Ref ref) {
    return notificationDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationRemoteDataSource>(value),
    );
  }
}

String _$notificationDataSourceHash() =>
    r'623c08d8f19454c54371b1410008535b4a65397a';

/// The number on the bell.
///
/// Kept alive, because the bell sits above every tab in all three shells: rebuilding it per tab
/// would mean a fetch each time somebody switches, and a badge that flickers from empty to a number
/// on every move. It is also what the app refreshes when it comes back to the foreground.
///
/// Watches auth so signing out does not leave the next person looking at somebody else's count.

@ProviderFor(UnreadNotificationCount)
final unreadNotificationCountProvider = UnreadNotificationCountProvider._();

/// The number on the bell.
///
/// Kept alive, because the bell sits above every tab in all three shells: rebuilding it per tab
/// would mean a fetch each time somebody switches, and a badge that flickers from empty to a number
/// on every move. It is also what the app refreshes when it comes back to the foreground.
///
/// Watches auth so signing out does not leave the next person looking at somebody else's count.
final class UnreadNotificationCountProvider
    extends $AsyncNotifierProvider<UnreadNotificationCount, int> {
  /// The number on the bell.
  ///
  /// Kept alive, because the bell sits above every tab in all three shells: rebuilding it per tab
  /// would mean a fetch each time somebody switches, and a badge that flickers from empty to a number
  /// on every move. It is also what the app refreshes when it comes back to the foreground.
  ///
  /// Watches auth so signing out does not leave the next person looking at somebody else's count.
  UnreadNotificationCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unreadNotificationCountProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unreadNotificationCountHash();

  @$internal
  @override
  UnreadNotificationCount create() => UnreadNotificationCount();
}

String _$unreadNotificationCountHash() =>
    r'62728e7dc58f6ee1f4653cc37cd2e9119de483f1';

/// The number on the bell.
///
/// Kept alive, because the bell sits above every tab in all three shells: rebuilding it per tab
/// would mean a fetch each time somebody switches, and a badge that flickers from empty to a number
/// on every move. It is also what the app refreshes when it comes back to the foreground.
///
/// Watches auth so signing out does not leave the next person looking at somebody else's count.

abstract class _$UnreadNotificationCount extends $AsyncNotifier<int> {
  FutureOr<int> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<int>, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<int>, int>,
              AsyncValue<int>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The list itself, newest first.
///
/// Not kept alive: it is a screenful of history that is only worth holding while somebody is
/// reading it, and it should be fresh the next time the screen opens.

@ProviderFor(NotificationList)
final notificationListProvider = NotificationListProvider._();

/// The list itself, newest first.
///
/// Not kept alive: it is a screenful of history that is only worth holding while somebody is
/// reading it, and it should be fresh the next time the screen opens.
final class NotificationListProvider
    extends $AsyncNotifierProvider<NotificationList, List<AppNotification>> {
  /// The list itself, newest first.
  ///
  /// Not kept alive: it is a screenful of history that is only worth holding while somebody is
  /// reading it, and it should be fresh the next time the screen opens.
  NotificationListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationListHash();

  @$internal
  @override
  NotificationList create() => NotificationList();
}

String _$notificationListHash() => r'8eaa4596f5b76330690f1250e039e69981cb47a7';

/// The list itself, newest first.
///
/// Not kept alive: it is a screenful of history that is only worth holding while somebody is
/// reading it, and it should be fresh the next time the screen opens.

abstract class _$NotificationList
    extends $AsyncNotifier<List<AppNotification>> {
  FutureOr<List<AppNotification>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<AppNotification>>, List<AppNotification>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<AppNotification>>,
                List<AppNotification>
              >,
              AsyncValue<List<AppNotification>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
