import 'package:flutter/material.dart';
import 'package:zuno/core/ui_config/ui_config.dart';

/// The icon on a notification row, chosen from what the notification is about.
///
/// Keyed off the server's `kind` name through the `NotificationKind` labels, which is why the
/// fallback matters: a server that grows a new kind must show up as a notification with a generic
/// icon, never as a missing row or a crash.
///
/// Grouped by what the person has to do about it rather than by which role it reaches. Somebody
/// scanning a list wants to tell "money arrived" from "answer needed" at a glance, and both of those
/// happen to several roles.
IconData notificationIcon(String kind) =>
    UiConfig.current.icon('NotificationKind', kind) ??
    Icons.notifications_outlined;
