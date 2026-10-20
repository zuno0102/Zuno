import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/auth/presentation/providers/auth_providers.dart';
import 'package:zuno/features/auth/presentation/providers/auth_state.dart';
import 'package:zuno/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:zuno/features/notifications/domain/entities/app_notification.dart';

part 'notification_providers.g.dart';

@Riverpod(keepAlive: true)
NotificationRemoteDataSource notificationDataSource(Ref ref) =>
    NotificationRemoteDataSource(ref.watch(dioClientProvider));

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
@Riverpod(keepAlive: true)
class UnreadNotificationTargets extends _$UnreadNotificationTargets {
  @override
  Future<Set<String>> build() async {
    final auth = await ref.watch(authProvider.future);
    if (auth is! AuthAuthenticated) return const {};

    final notifications = await ref
        .read(notificationDataSourceProvider)
        .getMine();

    return {
      for (final n in notifications)
        if (n.isUnread && n.targetId != null) keyFor(n.target, n.targetId!),
    };
  }

  /// The targets that all mean "this order".
  ///
  /// An order is pointed at by two of them — the order itself, and the invitation to rate the
  /// finished job — and both carry the same booking id. Opening the order is seeing either, so
  /// they are cleared together. The chat on that order is deliberately not here: its messages
  /// belong to the Chat tab, and opening the order is not reading them.
  static const bookingTargets = ['booking', 'bookingRating'];

  /// Records that the customer has opened an order, clearing what they were told about it.
  Future<void> markBookingSeen(String bookingId) async {
    for (final target in bookingTargets) {
      await markSeen(target, bookingId);
    }
  }

  /// Records that the person has opened the thing itself, and clears what they were told about it.
  ///
  /// The badge was counting a booking somebody had already read, because read state only ever
  /// changed by tapping the notification. Reading the booking is better evidence than tapping a
  /// sentence about it.
  Future<void> markSeen(String target, String targetId) async {
    final current = state.value;
    final key = keyFor(target, targetId);

    // Nothing was waiting on this one: no request, and nothing to take off either badge.
    if (current != null && !current.contains(key)) return;

    if (current != null) {
      state = AsyncData({...current}..remove(key));
    }

    try {
      await ref
          .read(notificationDataSourceProvider)
          .markTargetRead(target, targetId);
    } catch (_) {
      // Left as seen on screen. They have read the booking; insisting otherwise because one
      // request failed would be the app arguing with what they just did.
    }

    // The bell is counting the same notifications, so it moves with this.
    await ref.read(unreadNotificationCountProvider.notifier).refresh();
  }

  /// Drops one, without telling the server — for when something else already has.
  ///
  /// Opening a notification from the bell marks it read by id, which covers the server side; this
  /// keeps the set in step so the Bookings tab loses its mark at the same moment, rather than at
  /// the next fetch.
  void forget(String target, String targetId) {
    final current = state.value;
    if (current == null) return;

    state = AsyncData({...current}..remove(keyFor(target, targetId)));
  }

  /// Drops all of them, for when the whole list has been marked read.
  void forgetAll() {
    if (state.value == null) return;
    state = const AsyncData({});
  }

  /// Re-reads without blanking, for the moments the app checks on itself.
  Future<void> refresh() async {
    final next = await AsyncValue.guard(() => build());
    if (!ref.mounted || next.hasError) return;
    state = next;
  }

  /// One spelling for a key, wherever it is built.
  ///
  /// The server names a target in its own case and the app's enum in another, so both are folded
  /// down here. Two spellings of the same key would never match, and the badge would simply never
  /// clear — silently, with nothing to see in the code.
  static String keyFor(String target, String targetId) =>
      '${target.toLowerCase()}:$targetId';
}

/// Whether anything unread points at this exact thing.
@riverpod
bool hasUnreadNotificationFor(Ref ref, String target, String targetId) =>
    (ref.watch(unreadNotificationTargetsProvider).value ?? const <String>{})
        .contains(UnreadNotificationTargets.keyFor(target, targetId));

/// The number on the bell.
///
/// Kept alive, because the bell sits above every tab in all three shells: rebuilding it per tab
/// would mean a fetch each time somebody switches, and a badge that flickers from empty to a number
/// on every move. It is also what the app refreshes when it comes back to the foreground.
///
/// Watches auth so signing out does not leave the next person looking at somebody else's count.
@Riverpod(keepAlive: true)
class UnreadNotificationCount extends _$UnreadNotificationCount {
  @override
  Future<int> build() async {
    final auth = await ref.watch(authProvider.future);

    // Nothing to count while signed out, and asking would be a 401 on every app start.
    if (auth is! AuthAuthenticated) return 0;

    return ref.read(notificationDataSourceProvider).getUnreadCount();
  }

  /// Re-reads the count without blanking the badge first.
  ///
  /// Used on resume and after the list changes. A plain invalidate would put the provider back into
  /// loading and drop the badge to nothing for the length of a request, which reads as "all caught
  /// up" at exactly the moment it is not.
  Future<void> refresh() async {
    if (!ref.mounted) return;

    final next = await AsyncValue.guard(
      () => ref.read(notificationDataSourceProvider).getUnreadCount(),
    );

    // A failed refresh keeps the number that is showing. Losing the badge because one request
    // timed out would hide the very thing it exists to point at.
    if (!ref.mounted || next.hasError) return;
    state = next;
  }

  /// Drops the badge by one, without a round trip.
  ///
  /// Called when a row is opened, so the bell agrees with the list immediately. The server is the
  /// authority and the next refresh settles it; this is only about the half-second in between.
  void decrement() {
    final current = state.value;
    if (current == null || current == 0) return;
    state = AsyncData(current - 1);
  }

  void clear() => state = const AsyncData(0);
}

/// The list itself, newest first.
///
/// Not kept alive: it is a screenful of history that is only worth holding while somebody is
/// reading it, and it should be fresh the next time the screen opens.
@riverpod
class NotificationList extends _$NotificationList {
  @override
  Future<List<AppNotification>> build() async {
    final models = await ref.read(notificationDataSourceProvider).getMine();
    return models.map((m) => m.toEntity()).toList();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }

  /// Marks one read, then lets the badge catch up.
  ///
  /// The row is updated here before the request goes out, because this runs as the app navigates
  /// away — waiting for the server would mean coming back to a row still showing as unread.
  Future<void> markRead(String id) async {
    final current = state.value;
    if (current == null) return;

    // Not on this page. The fallback here used to hand back an unrelated row — the first one — and
    // if that happened to be unread the badge was decremented for a notification nobody had read,
    // while the rewrite below changed nothing.
    //
    // Still told to the server, with nothing taken off the badge. A message tapped in the phone's
    // tray arrives here and is deliberately not in this list, so returning outright would leave it
    // unread for ever; and the badge never counted it, so there is nothing to subtract.
    final target = current.where((n) => n.id == id).firstOrNull;
    if (target == null) {
      try {
        await ref.read(notificationDataSourceProvider).markRead(id);
      } catch (_) {
        // Nothing on screen depends on it. The next tap tries again.
      }
      return;
    }

    // Already read: nothing to say to the server, and nothing to take off the badge.
    if (!target.isUnread) return;

    state = AsyncData([
      for (final n in current) n.id == id ? n.copyWith(isUnread: false) : n,
    ]);

    ref.read(unreadNotificationCountProvider.notifier).decrement();

    // The Bookings tab marks the same orders, so it loses its mark with the bell rather than a
    // fetch later.
    if (target.targetId != null) {
      ref
          .read(unreadNotificationTargetsProvider.notifier)
          .forget(target.target.name, target.targetId!);
    }

    try {
      await ref.read(notificationDataSourceProvider).markRead(id);
    } catch (_) {
      // Left as read on screen. The row has been opened — insisting it is unread again because
      // one request failed would be the app arguing with what the person just did. The next
      // refresh takes the server's answer.
    }
  }

  /// Clears the badge, because the person pressed Mark all read. The rows stay, because the list
  /// is also the record of what happened.
  ///
  /// Only ever from that button. Opening the list used to do this by itself, and it took the number
  /// off the Bookings tab too — both badges count these same notifications, so a glance at this
  /// screen dismissed the offers still waiting for an answer there. Each notification now clears
  /// when its own thing is opened: a row tapped here, or the order opened on the Bookings tab.
  Future<void> markAllRead() async {
    final current = state.value;

    if (current != null) {
      state = AsyncData([for (final n in current) n.copyWith(isUnread: false)]);
    }

    ref.read(unreadNotificationCountProvider.notifier).clear();
    ref.read(unreadNotificationTargetsProvider.notifier).forgetAll();

    try {
      await ref.read(notificationDataSourceProvider).markAllRead();
    } finally {
      await ref.read(unreadNotificationCountProvider.notifier).refresh();
    }
  }
}
