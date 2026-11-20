import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/customer/presentation/screens/customer_profile_tab.dart';
import 'package:zuno/features/marketplace/presentation/screens/customer_marketplace_home_tab.dart';
import 'package:zuno/features/marketplace/presentation/screens/customer_marketplace_orders_tab.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_account_tiles.dart';
import 'package:zuno/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:zuno/features/rental/presentation/providers/rental_customer_providers.dart';

/// The Marketplace side of the customer app: **Home** (adverts, food near you, products, B2B lots),
/// **Orders** (what they bought, with where it is, and their B2B requests) and **Account** — the
/// same profile as the other sides, with the Orders · Wishlist · Coupons · Help Center tiles on top.
class CustomerMarketplaceShell extends ConsumerStatefulWidget {
  const CustomerMarketplaceShell({super.key});

  @override
  ConsumerState<CustomerMarketplaceShell> createState() =>
      _CustomerMarketplaceShellState();
}

class _CustomerMarketplaceShellState
    extends ConsumerState<CustomerMarketplaceShell> {
  int _index = 0;

  static const _ordersTab = 1;

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      CustomerMarketplaceHomeTab(
        // The app's one bell. Its notifications lead into the Service side, where they belong.
        notificationBell: NotificationBell(
          color: AppColors.onMedia,
          onOpen: (_) => ref
              .read(customerPanelChoiceProvider.notifier)
              .choose(CustomerPanel.service),
        ),
      ),
      const CustomerMarketplaceOrdersTab(),
      CustomerProfileTab(
        shortcuts: MarketplaceAccountTiles(
          onOrders: () => setState(() => _index = _ordersTab),
        ),
      ),
    ];

    return Scaffold(
      body: SafeArea(bottom: false, child: tabs[_index]),
      bottomNavigationBar: NavigationBar(
        key: const ValueKey('marketplace-nav'),
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
