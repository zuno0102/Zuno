import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/theme/app_theme.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/auth/presentation/providers/auth_state.dart';
import 'package:zuno/features/customer/presentation/providers/customer_location_sync.dart';
import 'package:zuno/features/customer/presentation/screens/customer_dashboard_shell.dart';
import 'package:zuno/features/customer/presentation/widgets/customer_location_picker.dart';
import 'package:zuno/features/customer/presentation/screens/customer_profile_tab.dart';
import 'package:zuno/features/marketplace/presentation/screens/customer_marketplace_shell.dart';
import 'package:zuno/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/features/rental/presentation/providers/rental_customer_providers.dart';
import 'package:zuno/features/rental/presentation/providers/rental_order_providers.dart';
import 'package:zuno/features/rental/presentation/screens/business_rent_orders_tab.dart';
import 'package:zuno/features/rental/presentation/screens/rental_home_tab.dart';
import 'package:zuno/shared/widgets/role_theme.dart';

/// The customer app: a **Service | Rent | Marketplace** switch on top, then the side chosen.
///
/// Service is the customer app exactly as it was ([CustomerDashboardShell]). Rent and Marketplace
/// are panels of their own — Home, their orders, Profile — sharing the login, the location, the bell
/// and the profile.
class CustomerAppShell extends ConsumerWidget {
  const CustomerAppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panel = ref.watch(customerPanelChoiceProvider);
    // Once per app open: where the customer is — from their account, then the phone — narrows the
    // listings on every side (Service, Rent). Watched only to start it; it never blocks the screen.
    ref.watch(customerLocationSyncProvider);
    // Location setup is required: a customer without one gets a setup sheet that stays until they
    // set it — a tap on "Use my current location" makes the browser show its permission popup.
    ref.listen(customerLocationSyncProvider, (_, next) {
      if (shouldAskCustomerLocation(next, ref.read(authProvider).value) &&
          context.mounted) {
        unawaited(requireCustomerLocation(context, ref));
      }
    });

    return RoleTheme(
      role: ZunoRole.customer,
      child: Builder(
        builder: (context) => ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              // The switch sits on the customer's deep teal, running up under the status bar; the
              // home header below carries the same colour on, so the two read as one header.
              ColoredBox(
                key: const ValueKey('customer-panel-band'),
                color: AppColors.gradientFor(ZunoRole.customer).$1,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    child: CustomerPanelSwitch(
                      value: panel,
                      onChanged: (p) => ref
                          .read(customerPanelChoiceProvider.notifier)
                          .choose(p),
                    ),
                  ),
                ),
              ),
              // Each side is a full screen of its own; the switch already sits under the status bar.
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: switch (panel) {
                    CustomerPanel.service => const CustomerDashboardShell(),
                    CustomerPanel.rent => const CustomerRentShell(),
                    CustomerPanel.marketplace =>
                      const CustomerMarketplaceShell(),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Whether the app should show the location setup sheet: only once the open-time check has
/// finished and says so, for a customer still signed in. While the check re-runs — on logout — it
/// still carries its last answer, and acting on that put the setup sheet over the login screen.
bool shouldAskCustomerLocation(
  AsyncValue<CustomerLocationOpen> check,
  AuthState? auth,
) =>
    !check.isLoading &&
    check.value == CustomerLocationOpen.needsChoice &&
    auth is AuthAuthenticated;

/// The three business lines as one segmented control on the teal band: the chosen side a white
/// segment with teal writing, the others white writing on the band. Plain upright type and the
/// same shape for all three, so the switch reads as one control, not three buttons.
class CustomerPanelSwitch extends StatelessWidget {
  const CustomerPanelSwitch({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final CustomerPanel value;
  final ValueChanged<CustomerPanel> onChanged;

  /// Each side with its share of the width: a longer name gets more, so all three read at one size.
  static const _panels = [
    (CustomerPanel.service, Icons.handyman_rounded, 'Service', 5),
    (CustomerPanel.rent, Icons.chair_alt_rounded, 'Rent', 4),
    (CustomerPanel.marketplace, Icons.storefront_rounded, 'Marketplace', 6),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('customer-panel-switch'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.onMedia.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          for (final (panel, icon, label, share) in _panels)
            Expanded(
              flex: share,
              child: _PanelSegment(
                key: ValueKey('customer-panel-${panel.name}'),
                icon: icon,
                label: label,
                selected: panel == value,
                onTap: () => onChanged(panel),
              ),
            ),
        ],
      ),
    );
  }
}

class _PanelSegment extends StatelessWidget {
  const _PanelSegment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final deep = AppColors.gradientFor(ZunoRole.customer).$1;
    final foreground = selected ? deep : AppColors.onMedia;
    final radius = BorderRadius.circular(AppRadius.md);

    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 44,
        decoration: BoxDecoration(
          color: selected ? AppColors.onMedia : Colors.transparent,
          borderRadius: radius,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: selected ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ExcludeSemantics(
                    child: Icon(icon, size: 18, color: foreground),
                  ),
                  const SizedBox(width: 6),
                  // Three sides share a narrow phone: a long name shrinks to fit, never wraps.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: foreground,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Rent side of the customer app: **Home** (rent items), **My rents** (bookings and messages),
/// and **Profile** — the same profile screen as the Service side.
class CustomerRentShell extends ConsumerStatefulWidget {
  const CustomerRentShell({super.key});

  @override
  ConsumerState<CustomerRentShell> createState() => _CustomerRentShellState();
}

class _CustomerRentShellState extends ConsumerState<CustomerRentShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(
      rentalUnreadMessageCountProvider(RentalAudience.customer),
    );

    final tabs = <Widget>[
      RentalHomeTab(
        // The app's one bell. Its notifications lead into the Service side, where they belong.
        notificationBell: NotificationBell(
          color: AppColors.onMedia,
          onOpen: (_) => ref
              .read(customerPanelChoiceProvider.notifier)
              .choose(CustomerPanel.service),
        ),
      ),
      const RentOrdersTabs(audience: RentalAudience.customer),
      const CustomerProfileTab(),
    ];

    return Scaffold(
      body: SafeArea(bottom: false, child: tabs[_index]),
      bottomNavigationBar: NavigationBar(
        key: const ValueKey('rent-nav'),
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 99 ? '99+' : '$unread'),
              child: const Icon(Icons.inventory_2_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 99 ? '99+' : '$unread'),
              child: const Icon(Icons.inventory_2),
            ),
            label: 'My rents',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
