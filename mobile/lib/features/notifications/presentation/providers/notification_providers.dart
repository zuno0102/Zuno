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

    // Nothing to do for a notification this page does not hold. The fallback here used to hand
    // back an unrelated row — the first one — and if that happened to be unread the badge was
    // decremented for a notification nobody had read, while the rewrite below changed nothing.
    final target = current.where((n) => n.id == id).firstOrNull;
    if (target == null) return;

    // Already read: nothing to say to the server, and nothing to take off the badge.
    if (!target.isUnread) return;

    state = AsyncData([
      for (final n in current) n.id == id ? n.copyWith(isUnread: false) : n,
    ]);

    ref.read(unreadNotificationCountProvider.notifier).decrement();

    try {
      await ref.read(notificationDataSourceProvider).markRead(id);
    } catch (_) {
      // Left as read on screen. The row has been opened — insisting it is unread again because
      // one request failed would be the app arguing with what the person just did. The next
      // refresh takes the server's answer.
    }
  }

  /// Clears the badge because the list has been opened, without unbolding what is on screen.
  ///
  /// Opening the list is what the badge is counting down to: it means "there is something here you
  /// have not looked at", and once somebody is looking at it, it has done its job. Reading the
  /// booking itself does not count — marking notifications read because a person walked past the
  /// right tab would quietly dismiss ones about something they never opened.
  ///
  /// The rows are deliberately left alone. [markAllRead] flips every one to read at once, which
  /// here would wipe the highlighting out from under the person the instant they arrived: they
  /// open the list to see what is new and find nothing marked. The server is told, the badge goes
  /// to zero, and this visit keeps its bold rows; the next load reads them back as read.
  Future<void> markAllReadOnOpen() async {
    final current = state.value;
    if (current == null || current.every((n) => !n.isUnread)) return;

    ref.read(unreadNotificationCountProvider.notifier).clear();

    try {
      await ref.read(notificationDataSourceProvider).markAllRead();
    } catch (_) {
      // Left cleared on screen. The person is looking at the list; insisting the badge is still
      // owed because one request failed would be the app arguing with what they just did. The
      // next refresh takes the server's answer.
    }
  }

  /// Clears the badge. The rows stay, because the list is also the record of what happened.
  Future<void> markAllRead() async {
    final current = state.value;

    if (current != null) {
      state = AsyncData([for (final n in current) n.copyWith(isUnread: false)]);
    }

    ref.read(unreadNotificationCountProvider.notifier).clear();

    try {
      await ref.read(notificationDataSourceProvider).markAllRead();
    } finally {
      await ref.read(unreadNotificationCountProvider.notifier).refresh();
    }
  }
}
