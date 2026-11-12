import 'package:flutter/material.dart';

/// One square in a [CategorySquareRow]: an icon, a short name and how many it holds.
class CategorySquare<T> {
  const CategorySquare({
    required this.value,
    required this.label,
    required this.count,
    this.icon,
  });

  final T value;

  /// A few letters — the square has room for "Products", "B2B", "Food", "Ads".
  final String label;

  /// Null while the count is still loading: the square shows no number rather than a wrong one.
  final int? count;
  final IconData? icon;
}

/// Main categories as equal squares, four to a row, the chosen one filled in the role's colour — the
/// filter at the top of a list.
///
/// Every square fits on a 360 dp phone, so nothing hides off-screen the way a sideways-scrolling row
/// of chips does. Nothing chosen means all; tapping the chosen square again clears it, and a line
/// under the row names the filter with a Clear while one is on. A square with nothing in it reads
/// quieter but can still be tapped.
class CategorySquareRow<T> extends StatelessWidget {
  const CategorySquareRow({
    required this.squares,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<CategorySquare<T>> squares;

  /// Squares in one row: four fit a 360 dp phone with room for a name.
  static const perRow = 4;

  /// The chosen square's value; null for all.
  final T? selected;

  /// Called with the new choice — null when the chosen square is tapped again or Clear is pressed.
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final chosen = squares.where((s) => s.value == selected).firstOrNull;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Four to a row, every square the same size: more categories add a row rather than
          // shrinking the squares or sliding some off-screen.
          for (var start = 0; start < squares.length; start += perRow)
            Padding(
              padding: EdgeInsets.only(top: start == 0 ? 0 : 8),
              child: Row(
                children: [
                  for (var i = start; i < start + perRow; i++) ...[
                    if (i > start) const SizedBox(width: 8),
                    Expanded(
                      child: i < squares.length
                          ? _Square(
                              square: squares[i],
                              isSelected: squares[i].value == selected,
                              onTap: () => onChanged(
                                squares[i].value == selected
                                    ? null
                                    : squares[i].value,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          if (chosen != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Showing: ${chosen.label}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('category-square-clear'),
                    onPressed: () => onChanged(null),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Square<T> extends StatelessWidget {
  const _Square({
    required this.square,
    required this.isSelected,
    required this.onTap,
  });

  final CategorySquare<T> square;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isEmpty = square.count == 0;
    final foreground = isSelected
        ? scheme.onPrimary
        : isEmpty
        ? scheme.onSurfaceVariant
        : scheme.onSurface;

    return Semantics(
      button: true,
      selected: isSelected,
      // One label for the whole square, read once: the icon, name and bubble are its picture.
      excludeSemantics: true,
      onTap: onTap,
      label: square.count == null
          ? square.label
          : '${square.label}, ${square.count}',
      child: AspectRatio(
        aspectRatio: 1,
        child: Material(
          key: ValueKey('category-square-${square.value}'),
          color: isSelected ? scheme.primary : scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isSelected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          square.icon ?? Icons.category_outlined,
                          size: 26,
                          color: isSelected
                              ? scheme.onPrimary
                              : isEmpty
                              ? scheme.onSurfaceVariant
                              : scheme.primary,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          square.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (square.count case final count?)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _CountBubble(count: count, isSelected: isSelected),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountBubble extends StatelessWidget {
  const _CountBubble({required this.count, required this.isSelected});

  final int count;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? scheme.onPrimary
            : count == 0
            ? scheme.surfaceContainerHighest
            : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: isSelected
              ? scheme.primary
              : count == 0
              ? scheme.onSurfaceVariant
              : scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
