import 'package:flutter/material.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_services_tab.dart';
import 'package:zuno/features/rental/presentation/screens/business_rentals_tab.dart';

/// The business's catalogue, split in two: the services it does, and the items it rents out.
///
/// The Service tab is the existing services screen, unchanged; Rent is its own module with its
/// own server, signed in with the same account.
class BusinessCatalogTab extends StatelessWidget {
  const BusinessCatalogTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: const TabBar(
              tabs: [
                Tab(text: 'Service'),
                Tab(text: 'Rent'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [BusinessServicesTab(), BusinessRentalsTab()],
            ),
          ),
        ],
      ),
    );
  }
}
