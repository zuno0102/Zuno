import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/rental/domain/entities/rental_stock.dart';
import 'package:zuno/features/rental/presentation/providers/rental_providers.dart';
import 'package:zuno/features/rental/presentation/screens/rental_stock_manage_screen.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_order_card.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/stock_figure_row.dart';

/// One item from the Stock page, in two tabs: **Stock** — in, out and total, with the quick
/// quantity change — and **Orders** — where its pieces went.
class RentalStockItemScreen extends StatelessWidget {
  const RentalStockItemScreen({required this.line, super.key});

  final RentalStockLine line;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(line.name),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Stock'),
              Tab(text: 'Orders'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _StockTab(line: line),
            _OrdersTab(rentalItemId: line.rentalItemId),
          ],
        ),
      ),
    );
  }
}

/// The current numbers, then the panel that changes how many the business has.
class _StockTab extends ConsumerWidget {
  const _StockTab({required this.line});

  final RentalStockLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The latest figures once anything is saved; the tile's own until then.
    final current =
        ref
            .watch(rentalStockProvider)
            .value
            ?.firstWhereOrNull((l) => l.rentalItemId == line.rentalItemId) ??
        line;
    final item = ref
        .watch(businessRentalsProvider)
        .value
        ?.firstWhereOrNull((i) => i.id == line.rentalItemId);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                StockFigureRow(
                  label: 'In stock',
                  value: current.quantityIn,
                  tone: StatusTone.success,
                ),
                StockFigureRow(
                  label: 'Booked',
                  value: current.quantityBooked,
                  tone: current.quantityBooked > 0
                      ? StatusTone.progress
                      : StatusTone.waiting,
                ),
                StockFigureRow(
                  label: 'Out with customers',
                  value: current.quantityOut,
                  tone: current.quantityOut > 0
                      ? StatusTone.danger
                      : StatusTone.waiting,
                ),
                const Divider(height: 14),
                StockFigureRow(label: 'Total', value: current.quantityTotal),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (item == null)
          const Center(child: CircularProgressIndicator())
        else
          RentalStockManagePanel(item: item, quantityOut: current.quantityOut),
      ],
    );
  }
}

/// Where the pieces went: each order with the customer, how many, the dates and the place.
class _OrdersTab extends ConsumerWidget {
  const _OrdersTab({required this.rentalItemId});

  final String rentalItemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(rentalItemOrdersProvider(rentalItemId));

    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorBanner(message: error.toString()),
        ),
      ),
      data: (orders) {
        if (orders.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No orders yet. When customers rent this item, each order shows here: '
                'who has how many, for which dates, and where they went.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () =>
              ref.refresh(rentalItemOrdersProvider(rentalItemId).future),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                RentalOrderCard(order: orders[index], showItem: false),
          ),
        );
      },
    );
  }
}
