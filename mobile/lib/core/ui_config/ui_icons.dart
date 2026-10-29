import 'package:flutter/material.dart';

/// The icons a label in the UI config may name, by their Material name.
///
/// The one place an icon name becomes an icon. Icons are compiled into the app (the font is trimmed
/// to the ones referenced), so the table can only choose among those listed here; a name the app
/// does not know shows no icon rather than a wrong one. Add the icon here before naming it in a
/// label file.
abstract final class UiIcons {
  static const Map<String, IconData> _byName = {
    'add_shopping_cart_outlined': Icons.add_shopping_cart_outlined,
    'assignment_ind_outlined': Icons.assignment_ind_outlined,
    'badge_outlined': Icons.badge_outlined,
    'block': Icons.block,
    'campaign_outlined': Icons.campaign_outlined,
    'cancel_outlined': Icons.cancel_outlined,
    'chat_bubble_outline': Icons.chat_bubble_outline,
    'check_circle': Icons.check_circle,
    'check_circle_outline': Icons.check_circle_outline,
    'do_not_disturb_on_outlined': Icons.do_not_disturb_on_outlined,
    'error_outline': Icons.error_outline,
    'event_available_outlined': Icons.event_available_outlined,
    'event_busy_outlined': Icons.event_busy_outlined,
    'event_outlined': Icons.event_outlined,
    'grade_outlined': Icons.grade_outlined,
    'groups_outlined': Icons.groups_outlined,
    'handshake_outlined': Icons.handshake_outlined,
    'handyman_outlined': Icons.handyman_outlined,
    'hourglass_empty': Icons.hourglass_empty,
    'hourglass_top': Icons.hourglass_top,
    'hourglass_top_outlined': Icons.hourglass_top_outlined,
    'how_to_reg_outlined': Icons.how_to_reg_outlined,
    'mark_email_read_outlined': Icons.mark_email_read_outlined,
    'mark_email_unread_outlined': Icons.mark_email_unread_outlined,
    'notifications_active_outlined': Icons.notifications_active_outlined,
    'notifications_outlined': Icons.notifications_outlined,
    'pause_circle_outline': Icons.pause_circle_outline,
    'payments_outlined': Icons.payments_outlined,
    'person_add_alt_1_outlined': Icons.person_add_alt_1_outlined,
    'play_circle_fill': Icons.play_circle_fill,
    'play_circle_outline': Icons.play_circle_outline,
    'report_gmailerrorred_outlined': Icons.report_gmailerrorred_outlined,
    'schedule': Icons.schedule,
    'send_outlined': Icons.send_outlined,
    'star_outline': Icons.star_outline,
    'task_alt_outlined': Icons.task_alt_outlined,
    'trending_up': Icons.trending_up,
    'verified_outlined': Icons.verified_outlined,
    'visibility_outlined': Icons.visibility_outlined,
  };

  static IconData? byName(String? name) => name == null ? null : _byName[name];

  /// Every name the registry knows — for a test that every label names one of them.
  static Iterable<String> get names => _byName.keys;
}
