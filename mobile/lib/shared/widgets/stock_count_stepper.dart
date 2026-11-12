import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// "Total you have": − and + either side of a big typed count, then the jumps a stock count really
/// makes (a broken few, a new delivery). The Stock pages of Rent and Marketplace share it; the page
/// keeps the count and says what is allowed.
class StockCountStepper extends StatelessWidget {
  const StockCountStepper({
    required this.controller,
    required this.onStep,
    required this.onTyped,
    required this.canLess,
    required this.canMore,
    this.errorText,
    this.fieldKey = const ValueKey('stock-quantity'),
    this.jumps = const [-10, 10, 50],
    super.key,
  });

  final TextEditingController controller;

  /// Moves the count by the step or jump tapped; the page clamps it.
  final ValueChanged<int> onStep;
  final ValueChanged<String> onTyped;
  final bool canLess;
  final bool canMore;

  /// What is wrong with the typed count, shown under the box.
  final String? errorText;
  final Key fieldKey;
  final List<int> jumps;

  /// The − and + buttons' look. At the lowest count the − is switched off but still drawn: the
  /// default disabled colours left an empty grey circle on phones, with no − to be seen.
  static ButtonStyle stepStyle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton.styleFrom(
      disabledBackgroundColor: scheme.surfaceContainerHighest,
      disabledForegroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.6),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = stepStyle(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton.filledTonal(
              tooltip: 'One less',
              style: style,
              iconSize: 28,
              onPressed: canLess ? () => onStep(-1) : null,
              icon: const Icon(Icons.remove),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: fieldKey,
                controller: controller,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  errorText: errorText,
                  errorMaxLines: 2,
                ),
                onChanged: onTyped,
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filledTonal(
              tooltip: 'One more',
              style: style,
              iconSize: 28,
              onPressed: canMore ? () => onStep(1) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            for (final delta in jumps)
              ActionChip(
                label: Text(delta > 0 ? '+$delta' : '$delta'),
                onPressed: () => onStep(delta),
              ),
          ],
        ),
      ],
    );
  }
}
