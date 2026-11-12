import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_colors.dart';

/// "In stock ........ 700" — a label and its count on one line, the count coloured by [tone]. The
/// Stock tiles of Rent and Marketplace are made of these.
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
