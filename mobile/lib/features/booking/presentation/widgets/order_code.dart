import 'package:flutter/material.dart';

/// The short order code for a booking — "#7A3F91C2".
///
/// Deliberately loud. It is the handle a business uses to tie an order to the crew it hired for
/// it: quoted on the hiring post, read out over the phone, written on a job sheet. A full GUID
/// cannot do any of that.
class OrderCode extends StatelessWidget {
  const OrderCode({required this.code, this.compact = false, super.key});

  final String code;

  /// Tighter padding, for a dense list row.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        code,
        style: theme.textTheme.labelMedium?.copyWith(
          fontSize: compact ? 11 : 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: theme.colorScheme.primary,
          // Tabular figures so codes line up down a list and are easier to compare.
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
