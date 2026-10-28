import 'package:zuno/core/utils/formatting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/work_chat/presentation/screens/work_chat_screen.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/auth/presentation/providers/auth_state.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/presentation/providers/booking_providers.dart';
import 'package:zuno/features/booking/presentation/screens/booking_chat_screen.dart';
import 'package:zuno/features/notifications/domain/entities/app_notification.dart';
import 'package:zuno/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:zuno/features/worker/presentation/providers/worker_dashboard_notifier.dart';
import 'package:zuno/features/worker/presentation/screens/worker_booking_detail_screen.dart';
import 'package:zuno/features/worker/presentation/screens/worker_payments_screen.dart';
import 'package:zuno/shared/widgets/async_detail_screen.dart';
import 'package:zuno/features/worker/presentation/screens/scan_booking_qr_screen.dart';
import 'package:zuno/features/worker/presentation/screens/worker_dashboard_tab.dart';
import 'package:zuno/features/worker/presentation/screens/worker_find_work_tab.dart';
import 'package:zuno/features/worker/presentation/screens/worker_jobs_tab.dart';
import 'package:zuno/features/worker/presentation/screens/worker_my_jobs_tab.dart';
import 'package:zuno/shared/widgets/role_header.dart';
import 'package:zuno/shared/widgets/role_theme.dart';
import 'package:zuno/core/permissions/startup_permission_primer.dart';
import 'package:zuno/core/router/push_screen.dart';

/// The worker's home, in the worker's green.
///
/// Three tabs, home first: the figures a worker opens the app for used to live on a Profile tab at
/// the far end of the bar, which put what they care about most furthest from where they landed.
class WorkerDashboardShell extends ConsumerStatefulWidget {
  const WorkerDashboardShell({super.key});

  @override
  ConsumerState<WorkerDashboardShell> createState() =>
      _WorkerDashboardShellState();
}

class _WorkerDashboardShellState extends ConsumerState<WorkerDashboardShell> {
  int _index = 0;

  static const _homeTab = 0;
  static const _myJobsTab = 1;
  static const _findWorkTab = 2;

  /// Which of My jobs' own tabs to open on. Invitations live inside My jobs, so a notification about
  /// one opens My jobs on that tab rather than on Current.
  int _myJobsStartTab = WorkerJobsTab.currentTab;

  /// Which half of My jobs opens: service jobs, or full-time applications.
  int _myJobsSection = WorkerMyJobsTab.serviceSection;

  /// Bumped to rebuild My jobs on [_myJobsStartTab] even when it is already the tab on screen.
  int _myJobsOpenCount = 0;

  void _openMyJobs(int tab, {int section = WorkerMyJobsTab.serviceSection}) =>
      setState(() {
        _index = _myJobsTab;
        _myJobsStartTab = tab;
        _myJobsSection = section;
        _myJobsOpenCount++;
      });

  Widget _tab(int index) => switch (index) {
    _myJobsTab => WorkerMyJobsTab(
      key: ValueKey(_myJobsOpenCount),
      initialSection: _myJobsSection,
      serviceStartTab: _myJobsStartTab,
    ),
    _findWorkTab => const WorkerFindWorkTab(),
    _ => const WorkerDashboardTab(),
  };

  /// Takes the worker to the thing a notification is about.
  ///
  /// The worker's half of the catalogue is the one with the most at stake — work being offered and
  /// money arriving — so most of these land on a specific job rather than a tab.
  void _openNotification(AppNotification notification) {
    switch (notification.target) {
      // A booking they were put on. Opens their own view of it, which is where the accept and
      // decline buttons are.
      case NotificationTarget.booking:
        _openJob(notification.targetId!);

      case NotificationTarget.bookingChat:
        _openChat(notification.targetId!);

      // A message from a business this worker works for. The title is the sender's name.
      case NotificationTarget.workChat:
        pushScreen(
          context,
          WorkChatScreen(
            counterpartId: notification.targetId!,
            counterpartName: notification.title,
          ),
        );

      // An offer or an invitation on a hiring post. The post's own details and its answer buttons
      // live on My jobs › Invitations, which is where a worker answers one.
      case NotificationTarget.hiringPost:
      case NotificationTarget.invitations:
        _openMyJobs(WorkerJobsTab.invitationsTab);

      case NotificationTarget.myJobs:
        _openMyJobs(WorkerJobsTab.currentTab);

      // After losing a post, the useful thing is the next job rather than the one they did not get.
      case NotificationTarget.findWork:
        setState(() => _index = _findWorkTab);

      // A full-time application was moved along: show it under My jobs › My applications.
      case NotificationTarget.myVacancyApplications:
        _openMyJobs(
          WorkerJobsTab.currentTab,
          section: WorkerMyJobsTab.applicationsSection,
        );

      case NotificationTarget.payments:
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const WorkerPaymentsScreen()));

      default:
        setState(() => _index = _homeTab);
    }
  }

  void _openJob(String bookingId) {
    pushScreen(
      context,
      AsyncDetailScreen<Booking>(
        title: 'Job',
        fetch: () =>
            ref.read(bookingRepositoryProvider).getJobByIdAsWorker(bookingId),
        builder: (_, booking) => WorkerBookingDetailScreen(booking: booking),
      ),
    );
  }

  /// The order's conversation, for a worker who is party to it.
  ///
  /// Reached through the worker's own job route, which is the one that decides whether this worker
  /// is on that booking at all.
  void _openChat(String bookingId) {
    pushScreen(
      context,
      AsyncDetailScreen<Booking>(
        title: 'Chat',
        fetch: () =>
            ref.read(bookingRepositoryProvider).getJobByIdAsWorker(bookingId),
        builder: (_, booking) => BookingChatScreen(
          bookingId: booking.id,
          title: booking.variantName ?? booking.serviceName,
          counterpartName: booking.businessName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authValue = ref.watch(authProvider).value;
    final user = authValue is AuthAuthenticated ? authValue.user : null;

    // Owed comes from the dashboard, which is the one thing that reads both routes onto paid work.
    // It used to be recomputed here from the hiring-post feed, so the header and the work record
    // could — and did — disagree about the same figure on adjacent screens.
    final dashboard = ref.watch(workerDashboardProvider);
    final owed = dashboard.maybeWhen(
      data: (d) => d.pendingPaymentTotal,
      orElse: () => 0.0,
    );

    // From the dashboard, not the job feed. The feed is now filtered by distance and needs a
    // location before it returns anything, so deriving this from it would read zero on a header that
    // sits above every tab.
    final openJobs = dashboard.maybeWhen(
      data: (d) => d.openHiringPostCount,
      orElse: () => 0,
    );

    return StartupPermissionPrimer(
      child: RoleTheme(
        role: ZunoRole.worker,
        child: Scaffold(
          body: Column(
            children: [
              RoleHeader(
                role: ZunoRole.worker,
                greeting: 'Find work nearby',
                name: user == null
                    ? 'Worker'
                    : '${user.firstName} ${user.lastName}'.trim(),
                stats: [
                  HeaderStat(
                    label: 'Jobs to apply for',
                    value: '$openJobs',
                    icon: Icons.work_outline,
                  ),
                  HeaderStat(
                    label: 'Owed to you',
                    value: rupees(owed),
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ],
                actions: [
                  NotificationBell(
                    onOpen: _openNotification,
                    color: AppColors.onMedia,
                  ),
                  IconButton(
                    icon: Icon(Icons.qr_code_scanner, color: AppColors.onMedia),
                    tooltip: 'Scan booking QR',
                    onPressed: () =>
                        pushScreen(context, const ScanBookingQrScreen()),
                  ),
                  IconButton(
                    icon: Icon(Icons.logout, color: AppColors.onMedia),
                    tooltip: 'Log out',
                    onPressed: () => ref.read(authProvider.notifier).logout(),
                  ),
                ],
              ),
              Expanded(child: _tab(_index)),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) =>
                i == _myJobsTab && _index != _myJobsTab
                ? _openMyJobs(WorkerJobsTab.currentTab)
                : setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.work_outline),
                selectedIcon: Icon(Icons.work),
                label: 'My jobs',
              ),
              NavigationDestination(
                icon: Icon(Icons.campaign_outlined),
                selectedIcon: Icon(Icons.campaign),
                label: 'Find work',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
