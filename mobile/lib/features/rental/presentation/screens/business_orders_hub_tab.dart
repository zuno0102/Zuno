import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_orders_tab.dart';
import 'package:zuno/features/marketplace/presentation/screens/business_marketplace_orders_tab.dart';
import 'package:zuno/features/rental/presentation/providers/rental_order_providers.dart';
import 'package:zuno/features/rental/presentation/screens/business_rent_orders_tab.dart';

/// The business's Orders, split by business line: **Service** — the orders screen exactly as it
/// was — **Rent**, the same three parts for rent orders, and **Marketplace**, the posts by status.
class BusinessOrdersHubTab extends ConsumerWidget {
  const BusinessOrdersHubTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rentUnread = ref.watch(rentalUnreadMessageCountProvider());

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          // The same bar as Services › Service | Rent, so both splits look alike.
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              tabs: [
                const Tab(text: 'Service'),
                Tab(
                  child: Badge(
                    isLabelVisible: rentUnread > 0,
                    label: Text('$rentUnread'),
                    offset: const Offset(14, -4),
                    child: const Text('Rent'),
                  ),
                ),
                const Tab(text: 'Marketplace'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                BusinessOrdersTab(),
                BusinessRentOrdersTab(),
                BusinessMarketplaceOrdersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
