import 'package:flutter/material.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_services_tab.dart';
import 'package:zuno/features/marketplace/presentation/screens/business_marketplace_tab.dart';
import 'package:zuno/features/rental/presentation/screens/business_rentals_tab.dart';

/// The business's catalogue, in three: the services it does, the items it rents out, and what it
/// puts up on the Marketplace.
///
/// The Service tab is the existing services screen, unchanged; Rent and Marketplace are each their
/// own module with their own server, signed in with the same account.
class BusinessCatalogTab extends StatelessWidget {
  const BusinessCatalogTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: const TabBar(
              tabs: [
                Tab(text: 'Service'),
                Tab(text: 'Rent'),
                Tab(text: 'Marketplace'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                BusinessServicesTab(),
                BusinessRentalsTab(),
                BusinessMarketplaceTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
