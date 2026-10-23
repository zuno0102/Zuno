import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/presentation/providers/booking_providers.dart';
import 'package:zuno/features/booking/presentation/providers/customer_bookings_notifier.dart';
import 'package:zuno/features/booking/presentation/providers/booking_message_providers.dart';
import 'package:zuno/features/booking/presentation/screens/booking_chat_screen.dart';
import 'package:zuno/features/customer/presentation/screens/customer_booking_detail_screen.dart';
import 'package:zuno/features/customer/presentation/screens/customer_bookings_hub.dart';
import 'package:zuno/features/customer/presentation/screens/customer_profile_tab.dart';
import 'package:zuno/features/customer/presentation/screens/customer_search_tab.dart';
import 'package:zuno/features/notifications/domain/entities/app_notification.dart';
import 'package:zuno/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:zuno/shared/widgets/async_detail_screen.dart';
import 'package:zuno/shared/widgets/role_theme.dart';
import 'package:zuno/core/permissions/startup_permission_primer.dart';
import 'package:zuno/core/router/push_screen.dart';

/// The customer's home, in the customer's blue.
///
/// No gradient banner here, unlike the other two roles: this is a shopping surface, and a
/// heavy coloured header would compete with the service pictures it sits above. The identity
/// comes through in the accent colour instead.
class CustomerDashboardShell extends ConsumerStatefulWidget {
  const CustomerDashboardShell({super.key});

  @override
  ConsumerState<CustomerDashboardShell> createState() =>
      _CustomerDashboardShellState();
}

class _CustomerDashboardShellState
    extends ConsumerState<CustomerDashboardShell> {
  int _index = 0;

  /// Re-checks the orders every so often, so the Bookings count changes when the business answers —
  /// not only when the customer happens to open the tab. Runs only while this screen is up.
  Timer? _bookingsCheck;
  static const _bookingsCheckEvery = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _bookingsCheck = Timer.periodic(
      _bookingsCheckEvery,
      (_) => ref.read(customerBookingsProvider.notifier).refreshQuietly(),
    );
  }

  @override
  void dispose() {
    _bookingsCheck?.cancel();
    super.dispose();
  }

  static const _homeTab = 0;
  static const _bookingsTab = 1;
  static const _profileTab = 2;

  /// Which top tab of Bookings to show — its orders, or its messages.
  int _bookingsSection = CustomerBookingsHub.bookingsTab;

  /// Takes the customer to the thing a notification is about.
  ///
  /// Here rather than in the notifications screen because only this shell knows the customer's
  /// screens and tabs. The same notification target means a different destination to a worker, and
  /// a single shared mapping would have to know all three roles' navigation at once.
  ///
  /// Anything unrecognised — a target from a newer server — lands on Home. A notification that
  /// cannot say where it leads has already been read by the time it gets here, so the fallback is
  /// about not stranding somebody, not about delivering the news.
  void _openNotification(AppNotification notification) {
    switch (notification.target) {
      case NotificationTarget.booking:
      case NotificationTarget.bookingRating:
        _openBooking(
          notification.targetId!,
          openRating: notification.target == NotificationTarget.bookingRating,
        );

      case NotificationTarget.bookingChat:
        _openChat(notification.targetId!);

      case NotificationTarget.profile:
        setState(() => _index = _profileTab);

      // Everything else a customer can be sent: their own orders are the nearest thing to a
      // worker's or a business's screens, and Home is the fallback.
      case NotificationTarget.myJobs:
        setState(() {
          _index = _bookingsTab;
          _bookingsSection = CustomerBookingsHub.bookingsTab;
        });

      default:
        setState(() => _index = _homeTab);
    }
  }

  /// Fetches the one order, then shows it.
  ///
  /// A notification carries an id while the detail screen takes a whole booking, and fetching the
  /// one order is fresher than finding it in a list loaded minutes ago — which matters when the
  /// notification exists to say that order just changed.
  void _openBooking(String bookingId, {bool openRating = false}) {
    pushScreen(context, AsyncDetailScreen<Booking>(
          title: 'Booking',
          fetch: () => ref
              .read(bookingRepositoryProvider)
              .getBookingByIdAsCustomer(bookingId),
          builder: (_, booking) => CustomerBookingDetailScreen(
            booking: booking,
            openRating: openRating,
          ),
        ));
  }

  /// Fetches the order, then opens its conversation.
  ///
  /// The chat screen needs the order's title and who the other side is, and a notification carries
  /// neither — only the id. Composing them here rather than widening the notification keeps the
  /// stored words a record of the moment rather than a payload the client depends on.
  void _openChat(String bookingId) {
    pushScreen(context, AsyncDetailScreen<Booking>(
          title: 'Chat',
          fetch: () => ref
              .read(bookingRepositoryProvider)
              .getBookingByIdAsCustomer(bookingId),
          builder: (_, booking) => BookingChatScreen(
            bookingId: booking.id,
            title: booking.variantName ?? booking.serviceName,
            counterpartName: booking.businessName,
          ),
        ));
  }

  @override
  Widget build(BuildContext context) {
    // One number on Bookings for both halves inside it: orders waiting on the customer, and
    // messages they have not read. Each top tab inside shows its own share.
    final int waitingOnMe =
        (ref.watch(customerBookingsNeedingMeCountProvider) +
                ref.watch(unreadChatCountProvider))
            .toInt();

    final tabs = <Widget>[
      CustomerSearchTab(
        notificationBell: NotificationBell(onOpen: _openNotification),
      ),
      CustomerBookingsHub(initialTab: _bookingsSection),
      const CustomerProfileTab(),
    ];

    return StartupPermissionPrimer(
      child: RoleTheme(
        role: ZunoRole.customer,
        child: Scaffold(
          body: SafeArea(bottom: false, child: tabs[_index]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              // Orders and their messages together: an offer to answer, a job to rate, a reply to
              // read. Visible from any tab, so nothing waits unnoticed.
              NavigationDestination(
                icon: _UnreadBadge(
                  count: waitingOnMe,
                  child: const Icon(Icons.event_note_outlined),
                ),
                selectedIcon: _UnreadBadge(
                  count: waitingOnMe,
                  child: const Icon(Icons.event_note),
                ),
                label: 'Bookings',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tab icon with a count on it (unread messages, orders waiting on you); just the icon at zero.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) => Badge(
    isLabelVisible: count > 0,
    label: Text(count > 99 ? '99+' : '$count'),
    child: child,
  );
}
