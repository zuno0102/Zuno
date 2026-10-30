import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/router/push_screen.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/rental/domain/entities/rental_stock.dart';
import 'package:zuno/features/rental/presentation/providers/rental_providers.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_collect_sheet.dart';
import 'package:zuno/features/rental/presentation/screens/rental_stock_item_screen.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_item_form_sheet.dart';
import 'package:zuno/shared/widgets/error_banner.dart';

/// Stock: a tile per thing this business rents out, each with how many are in, out with
/// customers, and in total. Opened from the single Stock tile on the home screen.
class RentalStockScreen extends ConsumerWidget {
  const RentalStockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockAsync = ref.watch(rentalStockProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        actions: [
          // Where order QRs are paid to.
          IconButton(
            key: const ValueKey('rent-upi-settings'),
            tooltip: 'UPI ID for payments',
            onPressed: () => showRentalUpiSheet(context),
            icon: const Icon(Icons.qr_code_2_rounded),
          ),
        ],
      ),
      body: stockAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ErrorBanner(message: error.toString()),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => reloadRentals(ref),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (lines) {
          if (lines.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Nothing to rent yet. Add an item and its stock shows here.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => showRentalItemFormSheet(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add rent item'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              reloadRentals(ref);
              await ref.read(rentalStockProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // Two to a row: each tile carries three numbers and a name that can be long.
                for (var start = 0; start < lines.length; start += 2) ...[
                  if (start > 0) const SizedBox(height: 10),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: RentalStockTile(line: lines[start])),
                        const SizedBox(width: 10),
                        Expanded(
                          child: start + 1 < lines.length
                              ? RentalStockTile(line: lines[start + 1])
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One item's stock: its name, then in stock, out and total. Opens the item's Stock and Orders.
class RentalStockTile extends StatelessWidget {
  const RentalStockTile({required this.line, super.key});

  final RentalStockLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      key: ValueKey('stock-${line.rentalItemId}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => pushScreen(context, RentalStockItemScreen(line: line)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      line.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (!line.isAvailable)
                Text(
                  'Switched off',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 8),
              StockFigureRow(
                label: 'In stock',
                value: line.quantityIn,
                tone: StatusTone.success,
              ),
              StockFigureRow(
                label: 'Booked',
                value: line.quantityBooked,
                tone: line.quantityBooked > 0
                    ? StatusTone.progress
                    : StatusTone.waiting,
              ),
              StockFigureRow(
                label: 'Out',
                value: line.quantityOut,
                tone: line.quantityOut > 0
                    ? StatusTone.danger
                    : StatusTone.waiting,
              ),
              const Divider(height: 10),
              StockFigureRow(label: 'Total', value: line.quantityTotal),
            ],
          ),
        ),
      ),
    );
  }
}

/// "In stock ........ 700" — a label and its count on one line, the count coloured by [tone].
class StockFigureRow extends StatelessWidget {
  const StockFigureRow({
    required this.label,
    required this.value,
    this.tone,
    super.key,
  });

  final String label;
  final int value;

  /// Null for a plain figure, like the total.
  final StatusTone? tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = tone == null
        ? theme.colorScheme.onSurface
        : AppColors.status(tone!, theme.brightness);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            '$value',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colour,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
