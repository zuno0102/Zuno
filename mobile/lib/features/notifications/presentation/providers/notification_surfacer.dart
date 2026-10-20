import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuno/core/notifications/system_notifications.dart';
import 'package:zuno/features/notifications/domain/entities/app_notification.dart';
import 'package:zuno/features/notifications/presentation/providers/notification_providers.dart';

part 'notification_surfacer.g.dart';

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
@Riverpod(keepAlive: true)
class NotificationSurfacer extends _$NotificationSurfacer {
  /// What has already been drawn. Capped, because this only has to answer "have I shown this
  /// recently" — a notification from last month is never coming back round.
  static const _storageKey = 'surfaced_notification_ids';
  static const _remember = 200;

  Set<String> _surfaced = const {};
  bool _loaded = false;

  @override
  void build() {
    // Nothing to hold: the state is in storage and in the shade. This is a service, not a value.
  }

  Future<void> _load() async {
    if (_loaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_storageKey);

      // Null means this app has never surfaced anything — a fresh install, or the first build
      // with this feature in it. Handled in [syncNow], not here, so the distinction survives.
      _surfaced = stored?.toSet() ?? const {};
      _loaded = stored != null;
    } catch (error) {
      // Preferences can be unreadable on a locked or restoring device. Treat it as "nothing shown
      // yet", which errs towards a quiet shade rather than a duplicated one.
      debugPrint('[Notifications] Could not read surfaced ids: $error');
      _surfaced = const {};
      _loaded = true;
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_storageKey, _surfaced.toList());
    } catch (error) {
      debugPrint('[Notifications] Could not store surfaced ids: $error');
    }
  }

  /// Reads what is waiting and draws anything new.
  ///
  /// Called when the app comes back to the foreground. That is the honest limit of this half: it
  /// can only notice what has arrived while somebody opens the app. Drawing a banner for something
  /// that happened while the phone was in a pocket is delivery, not display, and needs Firebase.
  Future<void> syncNow() async {
    await _load();

    final List<AppNotification> waiting;
    try {
      final models = await ref
          .read(notificationDataSourceProvider)
          // Messages included: the tray announces a new message like anything else. The bell is
          // the one that leaves them to the Chat tab.
          .getMine(take: 30, includeChat: true);
      waiting = models.map((m) => m.toEntity()).toList();
    } catch (error) {
      // A failed read draws nothing. The bell still carries the count, and the next resume tries
      // again — there is no state to repair.
      debugPrint('[Notifications] Could not read the list to surface: $error');
      return;
    }

    final firstEverRun = !_loaded;

    // Only what is still unread. Something already opened on another device has been dealt with,
    // and a banner for it would be an interruption about nothing.
    final candidates = waiting
        .where((n) => n.isUnread && !_surfaced.contains(n.id))
        .toList();

    // On the very first run, everything already in the list is history — it accumulated before
    // this feature existed. Recorded as shown without drawing any of it, so nobody's first
    // experience of notifications is thirty banners at once.
    if (firstEverRun) {
      _surfaced = {...waiting.map((n) => n.id)};
      _loaded = true;
      await _save();
      return;
    }

    if (candidates.isEmpty) return;

    // Asked for only when there is actually something to draw, so the system dialog arrives with
    // its reason on screen rather than at launch — the same rule the camera follows here.
    final allowed = await SystemNotifications.instance.ensurePermission();

    // Refused. The ids are still recorded: the bell already carries them, and re-asking on every
    // resume for the rest of the install would be the app nagging.
    if (!allowed) {
      _remember_(candidates);
      await _save();
      return;
    }

    // Oldest first, so the newest ends up on top of the shade where the eye lands.
    for (final notification in candidates.reversed) {
      await SystemNotifications.instance.show(notification);
    }

    _remember_(candidates);
    await _save();
  }

  void _remember_(List<AppNotification> shown) {
    _surfaced = {..._surfaced, ...shown.map((n) => n.id)};

    if (_surfaced.length > _remember) {
      _surfaced = _surfaced.skip(_surfaced.length - _remember).toSet();
    }
  }

  /// Clears the shade and forgets what was shown.
  ///
  /// For sign-out: the next person to pick up the phone must not find the last one's wages and
  /// bookings sitting in their notifications.
  Future<void> forgetEverything() async {
    await SystemNotifications.instance.clearAll();
    _surfaced = const {};
    _loaded = true;
    await _save();
  }
}
