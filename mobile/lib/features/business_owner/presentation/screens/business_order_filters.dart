import 'package:flutter/material.dart';
import 'package:zuno/features/catalog/domain/entities/order_stage.dart';
import 'package:zuno/shared/widgets/filter_chip_bar.dart';

/// All 12 · Active 3 · Confirmed 4 · … — scrolls sideways, since the chips rarely fit a phone.
class OrderStatusFilterBar extends StatelessWidget {
  const OrderStatusFilterBar({
    required this.filters,
    required this.total,
    required this.counts,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// The chips after All, in the server's order, with the server's names. Each tab passes the
  /// stages the server marks for it.
  final List<OrderStage> filters;
  final int total;

  /// Per stage code.
  final Map<String, int> counts;

  /// The selected stage code, or null for All.
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, int count, String? code) => CountChip(
      label: label,
      count: count,
      selected: selected == code,
      onSelected: () => onSelected(code),
    );

    return FilterChipBar(
      chips: [
        chip('All', total, null),
        for (final stage in filters)
          chip(stage.label, counts[stage.code] ?? 0, stage.code),
      ],
    );
  }
}
