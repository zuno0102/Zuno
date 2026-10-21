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

/// Which things the person has been told about and not yet looked at, by the id of the thing.
///
/// One source for two badges. The bell counts unread notifications; the Bookings tab marks the
/// orders among them that still need the customer. Deriving both from the same set is what keeps
/// them agreeing: opening a booking takes it out of here, and both numbers fall together. Two
/// independent counts drift, and a person who clears one only to find the other still lit stops
/// trusting either.
///
/// Kept alive for the same reason as the count: the tabs it feeds are rebuilt constantly, and a
/// fetch per rebuild would make the badges flicker.

@ProviderFor(UnreadNotificationTargets)
final unreadNotificationTargetsProvider = UnreadNotificationTargetsProvider._();

/// Which things the person has been told about and not yet looked at, by the id of the thing.
///
/// One source for two badges. The bell counts unread notifications; the Bookings tab marks the
/// orders among them that still need the customer. Deriving both from the same set is what keeps
/// them agreeing: opening a booking takes it out of here, and both numbers fall together. Two
/// independent counts drift, and a person who clears one only to find the other still lit stops
/// trusting either.
///
/// Kept alive for the same reason as the count: the tabs it feeds are rebuilt constantly, and a
/// fetch per rebuild would make the badges flicker.
final class UnreadNotificationTargetsProvider
    extends $AsyncNotifierProvider<UnreadNotificationTargets, Set<String>> {
  /// Which things the person has been told about and not yet looked at, by the id of the thing.
  ///
  /// One source for two badges. The bell counts unread notifications; the Bookings tab marks the
  /// orders among them that still need the customer. Deriving both from the same set is what keeps
  /// them agreeing: opening a booking takes it out of here, and both numbers fall together. Two
  /// independent counts drift, and a person who clears one only to find the other still lit stops
  /// trusting either.
  ///
  /// Kept alive for the same reason as the count: the tabs it feeds are rebuilt constantly, and a
  /// fetch per rebuild would make the badges flicker.
  UnreadNotificationTargetsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unreadNotificationTargetsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unreadNotificationTargetsHash();

  @$internal
  @override
  UnreadNotificationTargets create() => UnreadNotificationTargets();
}

String _$unreadNotificationTargetsHash() =>
    r'dc50dd3924cc5669e2ec6ddbdba04908c4c155c2';

/// Which things the person has been told about and not yet looked at, by the id of the thing.
///
/// One source for two badges. The bell counts unread notifications; the Bookings tab marks the
/// orders among them that still need the customer. Deriving both from the same set is what keeps
/// them agreeing: opening a booking takes it out of here, and both numbers fall together. Two
/// independent counts drift, and a person who clears one only to find the other still lit stops
/// trusting either.
///
/// Kept alive for the same reason as the count: the tabs it feeds are rebuilt constantly, and a
/// fetch per rebuild would make the badges flicker.

abstract class _$UnreadNotificationTargets extends $AsyncNotifier<Set<String>> {
  FutureOr<Set<String>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Set<String>>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Set<String>>, Set<String>>,
              AsyncValue<Set<String>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Whether anything unread points at this exact thing.

@ProviderFor(hasUnreadNotificationFor)
final hasUnreadNotificationForProvider = HasUnreadNotificationForFamily._();

/// Whether anything unread points at this exact thing.

final class HasUnreadNotificationForProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether anything unread points at this exact thing.
  HasUnreadNotificationForProvider._({
    required HasUnreadNotificationForFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'hasUnreadNotificationForProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$hasUnreadNotificationForHash();

  @override
  String toString() {
    return r'hasUnreadNotificationForProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    final argument = this.argument as (String, String);
    return hasUnreadNotificationFor(ref, argument.$1, argument.$2);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HasUnreadNotificationForProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$hasUnreadNotificationForHash() =>
    r'395d5987f16462f87931f208263e9170effb15b1';

/// Whether anything unread points at this exact thing.

final class HasUnreadNotificationForFamily extends $Family
    with $FunctionalFamilyOverride<bool, (String, String)> {
  HasUnreadNotificationForFamily._()
    : super(
        retry: null,
        name: r'hasUnreadNotificationForProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Whether anything unread points at this exact thing.

  HasUnreadNotificationForProvider call(String target, String targetId) =>
      HasUnreadNotificationForProvider._(
        argument: (target, targetId),
        from: this,
      );

  @override
  String toString() => r'hasUnreadNotificationForProvider';
}

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

String _$notificationListHash() => r'349ddb1c5de61cf24ae2199d58c9159d042c0a75';

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
