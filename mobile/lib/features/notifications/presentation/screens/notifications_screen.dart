import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/utils/relative_time.dart';
import 'package:zuno/features/notifications/domain/entities/app_notification.dart';
import 'package:zuno/features/notifications/presentation/providers/notification_providers.dart';
import 'package:zuno/features/notifications/presentation/widgets/notification_icon.dart';

/// Everything the signed-in person has been told, newest first.
///
/// The list exists because a push banner dismissed on a lock screen is gone for ever. Without it a
/// missed notification is unrecoverable and the person is back to hunting through tabs — and on
/// Android 13+ a refused notification permission is a live possibility on every install, which
/// would leave the bell as the only delivery there is.
///
/// Where a row leads is [onOpen]'s business, not this screen's. The same notification means a
/// different screen to a customer and to a worker, and the role's own shell is the only place that
/// knows its screens — so this screen takes the destination as a callback and keeps no role
/// knowledge at all.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({required this.onOpen, super.key});

  /// Given a notification that can be opened, takes the person to it.
  ///
  /// Called after the row is marked read and this screen is popped, so the destination lands on
  /// the shell rather than on top of a list the person has finished with.
  final void Function(AppNotification notification) onOpen;

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  /// Opening the list deliberately does **not** clear the badge.
  ///
  /// It did for a while, and it cost too much. Both badges count the same unread notifications, so
  /// clearing everything the instant this screen appeared took the number off the Bookings tab as
  /// well — for orders the person had not opened and still had to answer. Three offers waiting
  /// became none because they glanced at a list.
  ///
  /// Each one now clears when its own thing is opened, from either side: tapping a row here, or
  /// opening the order on the Bookings tab. Both move both numbers by one, which is what makes the
  /// two agree without either lying. [_markAllRead] is for the person who wants the lot gone.
  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationListProvider);
    final anyUnread = notifications.value?.any((n) => n.isUnread) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (anyUnread)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(notificationListProvider.notifier).refresh(),
        child: switch (notifications) {
          AsyncData(:final value) when value.isEmpty => const _Empty(),
          AsyncData(:final value) => ListView.separated(
            // Always scrollable, so pull-to-refresh works even on a short list.
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: value.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => _NotificationRow(
              notification: value[index],
              onTap: () => _open(context, ref, value[index]),
            ),
          ),
          AsyncError(:final error) => _Failed(
            message: error.toString(),
            onRetry: () =>
                ref.read(notificationListProvider.notifier).refresh(),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  /// Marks the row read, closes this screen, then opens the thing.
  ///
  /// In that order deliberately. Marking read first is what the person just did and must survive a
  /// failed request; popping before opening means Back from the destination returns to where they
  /// were working, not to a notification list they have already dealt with.
  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) async {
    await ref.read(notificationListProvider.notifier).markRead(notification.id);

    if (!context.mounted) return;

    // A row that leads nowhere specific — an unknown target from a newer server, or a target
    // missing its id — stays put rather than popping the person out to their dashboard for
    // nothing. They have read it; that was the whole content.
    if (!notification.canOpen) return;

    Navigator.of(context).pop();
    widget.onOpen(notification);
  }

  /// Clears the lot, because the person asked for it.
  ///
  /// The deliberate act the badge needs. Opening the list cannot do this on the person's behalf —
  /// the Bookings tab counts the same notifications, and a glance at this screen would wipe the
  /// offers still waiting on them there.
  void _markAllRead() =>
      ref.read(notificationListProvider.notifier).markAllRead();
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final unread = notification.isUnread;

    return ListTile(
      onTap: onTap,
      // The unread tint is the role's own colour at a whisper, so the list still reads as part of
      // whichever app this is without shouting over the text.
      tileColor: unread
          ? colors.primary.withValues(alpha: 0.06)
          : Colors.transparent,
      leading: CircleAvatar(
        backgroundColor: unread
            ? colors.primary
            : colors.surfaceContainerHighest,
        foregroundColor: unread ? colors.onPrimary : colors.onSurfaceVariant,
        child: Icon(notificationIcon(notification.kind), size: 20),
      ),
      title: Text(
        notification.title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notification.body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(notification.body, style: theme.textTheme.bodySmall),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              timeAgo(notification.createdAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      // Only on rows that lead somewhere, so the chevron never promises a screen that is not
      // coming.
      trailing: notification.canOpen
          ? Icon(Icons.chevron_right, color: colors.onSurfaceVariant)
          : null,
      isThreeLine: notification.body.isNotEmpty,
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 96),
        Icon(
          Icons.notifications_none,
          size: 56,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Center(child: Text('Nothing yet', style: theme.textTheme.titleMedium)),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            'When a booking, a job or a payment needs you, it will show up here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 96),
        Icon(
          Icons.cloud_off_outlined,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}
