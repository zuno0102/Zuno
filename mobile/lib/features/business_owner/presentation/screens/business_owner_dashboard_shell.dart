import 'package:zuno/core/utils/formatting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_profile_notifier.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_orders_tab.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_dashboard_tab.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_services_tab.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_workers_tab.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/presentation/providers/booking_providers.dart';
import 'package:zuno/features/booking/presentation/screens/booking_chat_screen.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_booking_detail_screen.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_profile_tab.dart';
import 'package:zuno/features/hiring_post/presentation/providers/business_hiring_posts_notifier.dart';
import 'package:zuno/features/notifications/domain/entities/app_notification.dart';
import 'package:zuno/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:zuno/shared/widgets/async_detail_screen.dart';
import 'package:zuno/shared/widgets/role_header.dart';
import 'package:zuno/shared/widgets/role_theme.dart';
import 'package:zuno/core/permissions/startup_permission_primer.dart';

/// The business owner's home.
///
/// A gradient header carrying the figures that matter, over a bottom bar rather than tabs —
/// four destinations someone moves between all day belong within thumb reach, not stacked
/// under an app bar.
class BusinessOwnerDashboardShell extends ConsumerStatefulWidget {
  const BusinessOwnerDashboardShell({super.key});

  @override
  ConsumerState<BusinessOwnerDashboardShell> createState() =>
      _BusinessOwnerDashboardShellState();
}

class _BusinessOwnerDashboardShellState
    extends ConsumerState<BusinessOwnerDashboardShell> {
  int _index = 0;

  /// Which sub-tab the Workers destination opens on.
  ///
  /// Held here rather than inside that tab so a notification about a hiring post can land on the
  /// hire post list instead of the crew list.
  int _workersSubTab = _crewSubTab;

  static const _homeTab = 0;
  static const _ordersTab = 1;
  static const _workersTab = 3;

  static const _crewSubTab = 0;
  static const _hirePostSubTab = 1;

  /// Takes the owner to whatever is waiting on them.
  ///
  /// The business side of the catalogue is all "somebody is waiting on you", so these land on the
  /// order or the post that needs answering rather than on a dashboard.
  void _openNotification(AppNotification notification) {
    switch (notification.target) {
      case NotificationTarget.booking:
        _openOrder(notification.targetId!);

      case NotificationTarget.bookingChat:
        _openChat(notification.targetId!);

      // Hiring: applicants to go through, offers answered, wages to settle. All three live on the
      // hire post list under Workers.
      case NotificationTarget.hiringPost:
      case NotificationTarget.hiringPostApplicants:
      case NotificationTarget.payouts:
        setState(() {
          _index = _workersTab;
          _workersSubTab = _hirePostSubTab;
        });

      // A rating changed the stars a customer sees before choosing, which is on the profile.
      case NotificationTarget.profile:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BusinessProfileScreen()),
        );

      case NotificationTarget.myJobs:
        setState(() => _index = _ordersTab);

      default:
        setState(() => _index = _homeTab);
    }
  }

  void _openOrder(String bookingId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AsyncDetailScreen<Booking>(
          title: 'Order',
          fetch: () => ref
              .read(bookingRepositoryProvider)
              .getBookingByIdAsBusiness(bookingId),
          builder: (_, booking) =>
              BusinessBookingDetailScreen(booking: booking),
        ),
      ),
    );
  }

  void _openChat(String bookingId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AsyncDetailScreen<Booking>(
          title: 'Chat',
          fetch: () => ref
              .read(bookingRepositoryProvider)
              .getBookingByIdAsBusiness(bookingId),
          builder: (_, booking) => BookingChatScreen(
            bookingId: booking.id,
            title: booking.variantName ?? booking.serviceName,
            // The customer, since this is the business reading it.
            counterpartName: booking.customerName,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    /// Four destinations, not five: the profile is reached from a card on the home tab, since it
    /// is set up once and rarely returned to — unlike these, which are worked in all day.
    final tabs = <Widget>[
      const BusinessDashboardTab(),
      const BusinessOrdersTab(),
      const BusinessServicesTab(),
      BusinessWorkersTab(initialIndex: _workersSubTab),
    ];

    final profile = ref.watch(businessProfileProvider);
    final posts = ref.watch(businessHiringPostsProvider);

    final businessName = profile.maybeWhen(
      data: (p) => p.businessName,
      orElse: () => 'Your business',
    );

    // The level is already shown to customers on every search result; the owner was the one
    // person who could not see their own.
    final levelLabel = profile.maybeWhen(
      data: (p) => '${p.levelName} · Level ${p.level}',
      orElse: () => null,
    );

    // Live counts rather than placeholders: a header showing zeros while the data loads reads
    // as a business with no work on.
    final openJobs = posts.maybeWhen(
      data: (list) => list.where((p) => p.isOpenToWorkers()).length,
      orElse: () => 0,
    );
    final owed = posts.maybeWhen(
      data: (list) =>
          list.fold<double>(0, (sum, p) => sum + p.outstandingAmount),
      orElse: () => 0.0,
    );

    return StartupPermissionPrimer(
      child: RoleTheme(
        role: ZunoRole.business,
        child: Scaffold(
          body: Column(
            children: [
              RoleHeader(
                role: ZunoRole.business,
                greeting: 'Business partner',
                name: businessName,
                subtitle: levelLabel,
                stats: [
                  HeaderStat(
                    label: 'Open hire posts',
                    value: '$openJobs',
                    icon: Icons.campaign_outlined,
                  ),
                  HeaderStat(
                    label: 'Wages owed',
                    value: rupees(owed),
                    icon: Icons.payments_outlined,
                  ),
                ],
                actions: [
                  NotificationBell(
                    onOpen: _openNotification,
                    color: Colors.white,
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    tooltip: 'Log out',
                    onPressed: () => ref.read(authProvider.notifier).logout(),
                  ),
                ],
              ),
              Expanded(child: tabs[_index]),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.event_note_outlined),
                selectedIcon: Icon(Icons.event_note),
                label: 'Orders',
              ),
              NavigationDestination(
                icon: Icon(Icons.design_services_outlined),
                selectedIcon: Icon(Icons.design_services),
                label: 'Services',
              ),
              NavigationDestination(
                icon: Icon(Icons.groups_outlined),
                selectedIcon: Icon(Icons.groups),
                label: 'Workers',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
