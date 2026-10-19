import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/notifications/system_notifications.dart';
import 'package:zuno/features/notifications/domain/entities/app_notification.dart';
import 'package:zuno/features/notifications/presentation/providers/notification_providers.dart';
import 'package:zuno/features/notifications/presentation/providers/notification_surfacer.dart';
import 'package:zuno/features/notifications/presentation/screens/notifications_screen.dart';

/// The bell, with the count of what has not been read.
///
/// Lives in each role's header, above all the tabs, because what it points at is rarely on the tab
/// somebody is looking at — a worker reading their jobs is exactly who needs telling that a wage
/// landed.
///
/// **Refreshed when the app comes back to the foreground, never on a timer.** This app has one
/// clock in it — the six-second poll in booking chat, which stops when that screen closes — and a
/// second one ticking behind every screen would be a background cost paid by somebody on a phone
/// plan. Coming back to the app is also the moment the number is actually looked at.
class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({required this.onOpen, this.color, super.key});

  /// Where each notification leads. Supplied by the role's shell — see [NotificationsScreen].
  final void Function(AppNotification notification) onOpen;

  /// The bell's own colour. White on a role header's gradient; left null elsewhere.
  final Color? color;

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell>
    with WidgetsBindingObserver {
  StreamSubscription<AppNotification>? _shadeTaps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // A notification tapped in the Android shade lands here and is routed exactly like a row in
    // the list — same destination, same mark-as-read. Handled by the bell rather than the shell
    // because the bell already knows where each notification leads, and it sits in every role.
    _shadeTaps = SystemNotifications.instance.taps.listen(_openFromShade);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // A tap that arrived before anything was listening — from a cold start, the tap *is* what
      // launched the app. Consumed once the first shell is built and able to navigate.
      final pending = SystemNotifications.instance.takePendingTap();
      if (pending != null) _openFromShade(pending);

      // The number, as well as the banners.
      //
      // Resume was the only thing that refreshed it, and for a customer the bell is mounted
      // inside the Home tab rather than above all of them — so selecting any other tab unmounts
      // this widget and the observer that listens for resume, and the badge could sit stale for
      // as long as somebody stayed off Home. Refreshing as the bell mounts covers every return
      // to it; on the worker and business shells, where the bell sits above the tabs, this is
      // simply one more correct moment to ask.
      ref.read(unreadNotificationCountProvider.notifier).refresh();

      // Catches up on anything that arrived before this screen existed, and on a first install
      // records what is already there without drawing a wall of banners.
      ref.read(notificationSurfacerProvider.notifier).syncNow();
    });
  }

  @override
  void dispose() {
    _shadeTaps?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only on the way back in. The other states are the app going away, when nobody is reading
    // the badge and a request would be spent on a screen about to be hidden.
    if (state == AppLifecycleState.resumed) {
      ref.read(unreadNotificationCountProvider.notifier).refresh();

      // Draws anything that has arrived since. Coming back to the app is the only moment this
      // half can notice — delivery while the phone is in a pocket is Firebase's job.
      ref.read(notificationSurfacerProvider.notifier).syncNow();
    }
  }

  /// A tap from the Android shade: mark it read, then open the thing it is about.
  void _openFromShade(AppNotification notification) {
    if (!mounted) return;

    ref.read(notificationListProvider.notifier).markRead(notification.id);
    ref.read(unreadNotificationCountProvider.notifier).refresh();

    if (notification.canOpen) widget.onOpen(notification);
  }

  @override
  Widget build(BuildContext context) {
    // A failed or still-loading count shows as no badge rather than a zero or a spinner: the bell
    // is reachable either way, and a wrong number is worse than none.
    final unread = ref.watch(unreadNotificationCountProvider).value ?? 0;
    final colors = Theme.of(context).colorScheme;

    // Material's default badge is red, which in this app means an error — the colour the message
    // bar uses when something has gone wrong. Unread work is not a fault, and the app settled on
    // one colour per role rather than a palette of signals.
    //
    // Which way round depends on what the bell is sitting on. On the worker's and business's
    // gradient headers the bell is drawn white, and a role-coloured badge would sink into the
    // gradient behind it — so there the badge is white with the role's colour on it, and on the
    // customer's light header it is the role's colour with white on it.
    final onColouredHeader = widget.color != null;
    final badgeBackground = onColouredHeader ? Colors.white : colors.primary;
    final badgeText = onColouredHeader ? colors.primary : colors.onPrimary;

    return IconButton(
      tooltip: unread == 0
          ? 'Notifications'
          : '$unread unread notification${unread == 1 ? '' : 's'}',
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: badgeBackground,
        textColor: badgeText,
        // Capped, because the badge has to stay a badge. Anything past this is "a lot", and the
        // list is where the real number lives.
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: Icon(Icons.notifications_outlined, color: widget.color),
      ),
      onPressed: () {
        // Opened fresh every time: the list is the one place somebody goes looking for what they
        // might have missed, so it must not be a cached copy from an hour ago.
        ref.invalidate(notificationListProvider);

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NotificationsScreen(onOpen: widget.onOpen),
          ),
        );
      },
    );
  }
}
