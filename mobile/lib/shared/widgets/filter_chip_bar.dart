import 'package:flutter/material.dart';

/// The row every list filter in the app sits in — "All 12 · Active 3 · Confirmed 4 · …".
///
/// Bookings, Status management and Messages all filter a list one tab apart, so they have to look
/// the same doing it. They did not: Messages grew a SegmentedButton while the other two used
/// chips, and the three tabs read as three different screens. Owning the spacing and padding here
/// is what stops them drifting again — a bar supplies its own chrome, and a caller only says which
/// chips go in it. The worker's My jobs uses the same bar, so both panels filter alike.
///
/// Scrolls sideways, since the chips rarely fit a phone.
class FilterChipBar extends StatelessWidget {
  const FilterChipBar({required this.chips, super.key});

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

/// One chip on a [FilterChipBar]: a name and how many it holds — "Active 3".
class CountChip extends StatelessWidget {
  const CountChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;

  /// Null while the count is still loading: the name shows alone rather than a wrong number.
  final int? count;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(count == null ? label : '$label $count'),
      selected: selected,
      showCheckmark: false,
      // A group with nothing in it stays on the bar, so the row never jumps about, but reads
      // quieter than one that has something in it.
      labelStyle: count == 0 && !selected
          ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
          : null,
      onSelected: (_) => onSelected(),
    );
  }
}
