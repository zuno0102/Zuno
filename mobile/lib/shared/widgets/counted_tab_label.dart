import 'package:flutter/material.dart';

/// The bar of sub-tabs under Orders — Bookings · Status management · Messages — the same on the
/// Service and Rent sides, so the two read as one screen.
///
/// Fixed thirds, not a scrolling bar. A scrolling bar sized itself to the labels and pushed
/// Messages off the right edge of a phone. Tight side padding and room for two lines, so a long
/// name with its count after it wraps ("Status / management 2") rather than being cut off.
class ListTabBar extends StatelessWidget {
  const ListTabBar({required this.labels, super.key});

  /// One per tab, usually a [CountedTabLabel].
  final List<Widget> labels;

  /// Tall enough for a name on two lines.
  static const tabHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: TabBar(
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        tabs: [
          for (final label in labels) Tab(height: tabHeight, child: label),
        ],
      ),
    );
  }
}

/// A tab's name with its count written after it — "Messages 1" — never on top of it.
///
/// It was a corner badge, and on a phone the badge sat over the last letters of the name. The
/// count now follows the name as a small pill in the same line of text, so a long name wraps
/// with its count rather than either one being hidden.
class CountedTabLabel extends StatelessWidget {
  const CountedTabLabel({required this.label, required this.count, super.key});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    // The last word and the pill travel as one piece. Left as separate pieces, a name that filled
    // the tab let the pill drop onto a line of its own; held together, the name wraps before its
    // last word and the count stays after it: "From / customers 1".
    final cut = label.lastIndexOf(' ');
    final head = cut < 0 ? '' : label.substring(0, cut + 1);
    final lastWord = cut < 0 ? label : label.substring(cut + 1);

    return Semantics(
      // Read as one thing by a screen reader: "Messages, 1 new".
      label: '$label, $count new',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          text: head,
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Inherits the tab's own text style, so it reads as part of the name. Allowed to
                  // shorten only on a screen too narrow for the word itself — the count is the
                  // part that must stay readable.
                  Flexible(
                    child: Text(
                      lastWord,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  CountPill(key: ValueKey('tabCount:$label'), count: count),
                ],
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// The small red number after a tab's name.
class CountPill extends StatelessWidget {
  const CountPill({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The app's badge colours (the role's own colour, set in AppTheme), so this pill matches every
    // other count in the app rather than borrowing the red kept for errors.
    final background =
        theme.badgeTheme.backgroundColor ?? theme.colorScheme.primary;
    final foreground =
        theme.badgeTheme.textColor ?? theme.colorScheme.onPrimary;
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        // Capped, so the pill stays a pill. Past this is "a lot", and the list is where the real
        // number lives.
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        // The theme's small label style, the same one Material's own badges use.
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
