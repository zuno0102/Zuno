import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/router/push_screen.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/rental/domain/entities/rental_item.dart';
import 'package:zuno/features/rental/presentation/providers/rental_providers.dart';
import 'package:zuno/features/rental/presentation/screens/business_rentals_tab.dart';
import 'package:zuno/features/rental/presentation/screens/rental_stock_screen.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/stat_tile.dart';

/// The Rent section of the business home screen: items listed, available now, switched off, and
/// Stock — the pieces that can be rented. Each tile opens the items behind its number.
///
/// Counted by the Rent server, so the numbers stay right however many items a business lists.
class RentDashboardTiles extends ConsumerWidget {
  const RentDashboardTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(rentalSummaryProvider);

    // Rent is its own server: if it cannot be reached, this section says so and the rest of the
    // home screen carries on.
    if (summaryAsync.hasError && !summaryAsync.hasValue) {
      return ErrorBanner(message: summaryAsync.error.toString());
    }

    final s = summaryAsync.value;
    // A dash while loading rather than a spinner, so the section keeps its shape.
    String count(int Function(RentalSummary) of) =>
        s == null ? '–' : '${of(s)}';
    void open(String title, {bool? isAvailable}) => pushScreen(
      context,
      RentalItemListScreen(title: title, isAvailable: isAvailable),
    );

    return StatTileGrid(
      tiles: [
        StatTile(
          label: 'Rent items',
          value: count((s) => s.totalItems),
          icon: Icons.inventory_2_outlined,
          tone: (s?.totalItems ?? 0) > 0
              ? StatusTone.success
              : StatusTone.waiting,
          onTap: () => open('Rent items'),
        ),
        StatTile(
          label: 'Available now',
          value: count((s) => s.availableItems),
          icon: Icons.event_available_outlined,
          tone: (s?.availableItems ?? 0) > 0
              ? StatusTone.success
              : StatusTone.waiting,
          onTap: () => open('Available now', isAvailable: true),
        ),
        StatTile(
          label: 'Unavailable',
          value: count((s) => s.unavailableItems),
          icon: Icons.do_not_disturb_on_outlined,
          // Asks for a look: something the business owns cannot be rented.
          tone: (s?.unavailableItems ?? 0) > 0
              ? StatusTone.danger
              : StatusTone.waiting,
          onTap: () => open('Unavailable', isAvailable: false),
        ),
        // One tile for all stock, whatever the business rents, and no number on it: the Stock page
        // it opens has a tile per item with in, out and total.
        StatTile(
          label: 'Stock',
          value: '',
          icon: Icons.inventory_outlined,
          tone: StatusTone.progress,
          onTap: () => pushScreen(context, const RentalStockScreen()),
        ),
      ],
    );
  }
}

/// The rent items behind a home-screen tile, on a page of their own.
class RentalItemListScreen extends StatelessWidget {
  const RentalItemListScreen({
    required this.title,
    this.isAvailable,
    super.key,
  });

  final String title;

  /// Null for every item.
  final bool? isAvailable;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: BusinessRentalsTab(isAvailable: isAvailable),
  );
}
