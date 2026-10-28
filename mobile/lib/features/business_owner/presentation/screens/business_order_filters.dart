import 'package:flutter/material.dart';
import 'package:zuno/features/catalog/domain/entities/order_stage.dart';

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
    final theme = Theme.of(context);

    Widget chip(String label, int count, String? code) {
      final isSelected = selected == code;
      return ChoiceChip(
        label: Text('$label $count'),
        selected: isSelected,
        showCheckmark: false,
        // A group with nothing in it stays on the bar, so the row never jumps about, but reads
        // quieter than one that has bookings in it.
        labelStyle: count == 0 && !isSelected
            ? TextStyle(color: theme.colorScheme.onSurfaceVariant)
            : null,
        onSelected: (_) => onSelected(code),
      );
    }

    return OrderFilterChipBar(
      chips: [
        chip('All', total, null),
        for (final stage in filters)
          chip(stage.label, counts[stage.code] ?? 0, stage.code),
      ],
    );
  }
}

/// The row every filter on this screen sits in.
///
/// Bookings, Status management and Messages all filter a list one tab apart, so they have to look
/// the same doing it. They did not: Messages grew a SegmentedButton while the other two used
/// chips, and the three tabs read as three different screens. Owning the spacing and padding here
/// is what stops them drifting again — a bar supplies its own chrome, and a caller only says which
/// chips go in it.
class OrderFilterChipBar extends StatelessWidget {
  const OrderFilterChipBar({required this.chips, super.key});

  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    // A scrolling Row, not a ListView: a handful of chips is cheap, and building them all keeps
    // every one reachable by a screen reader even while it is scrolled out of view.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (final (index, chip) in chips.indexed) ...[
            if (index > 0) const SizedBox(width: 8),
            chip,
          ],
        ],
      ),
    );
  }
}
