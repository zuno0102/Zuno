import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/customer/presentation/providers/customer_location_sync.dart';
import 'package:zuno/features/customer/presentation/screens/customer_dashboard_shell.dart';
import 'package:zuno/features/customer/presentation/screens/customer_profile_tab.dart';
import 'package:zuno/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/features/rental/presentation/providers/rental_customer_providers.dart';
import 'package:zuno/features/rental/presentation/providers/rental_order_providers.dart';
import 'package:zuno/features/rental/presentation/screens/business_rent_orders_tab.dart';
import 'package:zuno/features/rental/presentation/screens/rental_home_tab.dart';
import 'package:zuno/shared/widgets/role_theme.dart';

/// The customer app: a **Service | Rent** switch on top, then the side chosen.
///
/// Service is the customer app exactly as it was ([CustomerDashboardShell]). Rent is its own panel
/// — Home, My rents, Profile — sharing the login, the location, the bell and the profile.
class CustomerAppShell extends ConsumerWidget {
  const CustomerAppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panel = ref.watch(customerPanelChoiceProvider);
    // Once per app open: where the customer is — from their account, then the phone — narrows the
    // listings on every side (Service, Rent). Watched only to start it; it never blocks the screen.
    ref.watch(customerLocationSyncProvider);

    return RoleTheme(
      role: ZunoRole.customer,
      child: Builder(
        builder: (context) => ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              // The switch sits in a band of the theme's own colour that runs up under the status
              // bar, so the two doors read as the top of the app rather than floating above it.
              ColoredBox(
                key: const ValueKey('customer-panel-band'),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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

/// The two business lines as two cards side by side with a gap between — the chosen one filled in
/// the theme's colour, the other a plain card — so the switch reads as a pair of big doors.
class CustomerPanelSwitch extends StatelessWidget {
  const CustomerPanelSwitch({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final CustomerPanel value;
  final ValueChanged<CustomerPanel> onChanged;

  static const _panels = [
    (CustomerPanel.service, Icons.handyman_rounded, 'Service'),
    (CustomerPanel.rent, Icons.chair_alt_rounded, 'Rent'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('customer-panel-switch'),
      children: [
        for (final (i, (panel, icon, label)) in _panels.indexed) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: _PanelCard(
              key: ValueKey('customer-panel-${panel.name}'),
              icon: icon,
              label: label,
              selected: panel == value,
              onTap: () => onChanged(panel),
            ),
          ),
        ],
      ],
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
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
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? scheme.onPrimary : scheme.onSurface;
    final radius = BorderRadius.circular(14);

    // Flat cards on the band, the chosen one filled — no shadow, which made them look lifted
    // off the page. The colours are the theme's, so light and dark mode both read.
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 46,
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surface,
          borderRadius: radius,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: selected ? null : onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: selected
                      ? scheme.onPrimary.withValues(alpha: 0.18)
                      : scheme.primaryContainer,
                  child: Icon(
                    icon,
                    size: 14,
                    color: selected ? scheme.onPrimary : scheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    color: foreground,
                  ),
                ),
              ],
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
