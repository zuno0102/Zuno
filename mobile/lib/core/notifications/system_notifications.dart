import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/notifications/domain/entities/app_notification.dart';

/// Draws a real Android notification — the one in the shade and on the lock screen.
///
/// Distinct from the bell inside the app, and deliberately so. The bell is the **record**: it
/// survives, it can be scrolled back through, and it is what somebody opens when they wonder what
/// they missed. This is the **interruption**: it arrives once, it is swiped away, and it is gone.
/// A notification that only interrupts is unrecoverable; one that only records is never noticed.
/// Zuno does both, from the same row.
///
/// **This is the display half, not the delivery half.** It can draw anything the app hands it, but
/// the app has to be running to hand it something. Delivery while the app is closed is Firebase's
/// job, and when that lands it will call straight into [show] — which is why this is built first
/// and separately: a foreground FCM message does not draw itself either, so this code is needed
/// whichever way the message arrives.
class SystemNotifications {
  SystemNotifications._();

  static final SystemNotifications instance = SystemNotifications._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Where a tapped notification wants to go, for whoever is listening.
  ///
  /// A stream rather than a callback: a tap can land before any screen is listening — from a cold
  /// start, the tap *is* what launched the app — so the latest one is replayed to whoever
  /// subscribes, rather than being dropped on the floor.
  final _taps = StreamController<AppNotification>.broadcast();

  Stream<AppNotification> get taps => _taps.stream;

  /// Held for the cold-start case: the tap that launched the app, waiting for a shell to consume it.
  AppNotification? _pendingTap;

  AppNotification? takePendingTap() {
    final tap = _pendingTap;
    _pendingTap = null;
    return tap;
  }

  bool _ready = false;

  /// One channel, named for what it is rather than what sends it.
  ///
  /// Android shows this name in the system settings, where somebody decides whether to keep
  /// hearing from this app. "Jobs and bookings" says what they would be turning off; "Zuno" or
  /// "General" would not.
  static const _channel = AndroidNotificationChannel(
    'zuno_service_updates',
    'Jobs and bookings',
    description:
        'Confirmations, crew changes, wages and messages about your work.',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (_ready) return;

    // A white silhouette, not the launcher icon: Android discards every colour in a small icon
    // and redraws it as one solid shape, so full-colour artwork arrives as a featureless blob.
    // The brand colour goes on through [AndroidNotificationDetails.color] instead, which is what
    // Android actually tints that shape with.
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_notification'),
      iOS: DarwinInitializationSettings(
        // Asked for later, with the first notification, rather than at launch. Same rule the
        // camera follows in this app: ask when the reason is on screen.
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onTap,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    // A notification tapped while the app was not running launches it, and the tap arrives here
    // rather than through the callback above. Kept so the shell can act on it once it is built.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      final payload = launch!.notificationResponse?.payload;
      if (payload != null) _pendingTap = _decode(payload);
    }

    _ready = true;
  }

  /// Asks for permission to draw notifications, if it has not been granted already.
  ///
  /// Android 13+ only; below that the permission is granted at install. Returns whether anything
  /// can be drawn, so a caller can stop trying rather than posting into the void.
  Future<bool> ensurePermission() async {
    await init();

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android == null) return false;

    // Returns the existing answer without a dialog when one has already been given, so this is
    // safe to call before every post rather than tracked separately.
    return await android.requestNotificationsPermission() ?? false;
  }

  /// Draws one notification.
  ///
  /// The id is derived from the notification's own id, so the same thing arriving twice — a retry,
  /// a resume that re-reads the same row — replaces the banner rather than stacking a duplicate on
  /// top of it.
  Future<void> show(AppNotification notification) async {
    await init();

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
        // Zuno's own colour, which is what Android tints the small icon and the app name with.
        // The brand colour rather than the signed-in role's: this is the app identifying itself
        // in a shade full of other apps, and it should look the same whoever is signed in.
        color: AppColors.primary,
        colorized: false,
        // So a long line is readable from the shade without opening the app, which for "Boss T
        // proposed ₹48,000 for 5 crew" is the whole message.
        styleInformation: BigTextStyleInformation(notification.body),
        // Groups Zuno's notifications together in the shade rather than scattering them among
        // everything else that has arrived since.
        groupKey: 'com.zuno.zuno.service_updates',
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _plugin.show(
      notification.id.hashCode,
      notification.title,
      notification.body.isEmpty ? null : notification.body,
      details,
      payload: _encode(notification),
    );
  }

  /// Clears everything this app has drawn.
  ///
  /// Used on sign-out: the next person to use the phone must not find the last one's wages and
  /// bookings sitting in the shade.
  Future<void> clearAll() async {
    await init();
    await _plugin.cancelAll();
  }

  void _onTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    final notification = _decode(payload);
    if (notification == null) return;

    if (_taps.hasListener) {
      _taps.add(notification);
    } else {
      // Nothing is listening yet — the app is still starting. Held rather than dropped.
      _pendingTap = notification;
    }
  }

  /// Only what a tap needs to find its way: where it leads, and which row to mark read.
  ///
  /// Not the whole notification. The payload travels through Android and comes back whenever the
  /// person gets round to tapping — possibly days later — so it carries ids, which stay true, and
  /// the words only so the destination can be identified in a log.
  static String _encode(AppNotification n) => jsonEncode({
    'id': n.id,
    'kind': n.kind,
    'target': n.target.name,
    'targetId': n.targetId,
  });

  static AppNotification? _decode(String payload) {
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;

      return AppNotification(
        id: map['id'] as String? ?? '',
        kind: map['kind'] as String? ?? '',
        title: '',
        body: '',
        // Matched on the enum's own name, which is what _encode wrote — not the server's spelling.
        target: NotificationTarget.values.firstWhere(
          (t) => t.name == map['target'],
          orElse: () => NotificationTarget.unknown,
        ),
        targetId: map['targetId'] as String?,
        isUnread: true,
        createdAt: DateTime.now(),
      );
    } catch (error) {
      // A payload this build cannot read — written by an older or newer version — opens the app
      // and nothing more. Better than a crash on a tap.
      debugPrint('[SystemNotifications] Unreadable payload: $error');
      return null;
    }
  }
}
