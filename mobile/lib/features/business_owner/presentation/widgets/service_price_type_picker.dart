import 'package:flutter/material.dart';
import 'package:zuno/core/ui_config/ui_config.dart';

/// How the business charges for this service.
///
/// A 2×2 grid of labelled tiles rather than chips or a segmented button. Four options is one
/// too many for a segmented row on a phone — the labels squeeze to nothing — and plain chips
/// gave almost no contrast between chosen and not, with nothing on screen saying what the row
/// was even for. Each tile carries a line explaining what it means, because "per person" is
/// not self-evident until you have used it once.
///
/// The options, their names and their explanations are the `PriceType.ServiceForm` group.
class ServicePriceTypePicker extends StatelessWidget {
  const ServicePriceTypePicker({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// The price type code currently chosen.
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const group = 'PriceType.ServiceForm';
    final ui = UiConfig.current;
    final options = [
      for (final code in ui.codes(group))
        (code, ui.label(group, code), ui.entry(group, code).detail ?? ''),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How do you charge?',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        for (var row = 0; row < 2; row++) ...[
          // IntrinsicHeight, not CrossAxisAlignment.stretch. Stretch asks the children to fill
          // the cross axis, which inside a scrolling column is unbounded — "BoxConstraints
          // forces an infinite height", and the whole page fails to render rather than just
          // this row. IntrinsicHeight measures the taller tile and matches the other to it,
          // which is the equal-height result actually wanted.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var column = 0; column < 2; column++) ...[
                  if (column == 1) const SizedBox(width: 10),
                  Expanded(
                    child: _PriceTypeTile(
                      option: options[row * 2 + column],
                      selected: value == options[row * 2 + column].$1,
                      onTap: onChanged,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (row == 0) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _PriceTypeTile extends StatelessWidget {
  const _PriceTypeTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  /// Code, name, and the line explaining it.
  final (String, String, String) option;
  final bool selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (value, label, explanation) = option;

    return InkWell(
      onTap: () => onTap(value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
        decoration: BoxDecoration(
          // Filled and outlined when chosen, so which one is picked reads at a glance rather
          // than from a shade of grey.
          color: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.35,
                ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 17,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              explanation,
              style: theme.textTheme.bodySmall?.copyWith(
                color: selected
                    ? theme.colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.8,
                      )
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stands in for the crew-size box on a service priced per person.
///
/// Priced per head, so the crew size is the thing being agreed rather than something the business
/// fixes in advance. A box would only invite a number that the order then contradicts.
class PerPersonCrewNotice extends StatelessWidget {
  const PerPersonCrewNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Workers agreed per order',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 3),
          Text(
            // No invented headcount here: an example number would read as a default, and the
            // only figure worth showing is the one the business is actually typing above.
            'You propose the number when the order comes in, and the price '
            'follows it — the rate above for each person on the job.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
