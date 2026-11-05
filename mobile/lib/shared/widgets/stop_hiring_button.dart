import 'package:flutter/material.dart';

/// "Stop hiring" on a hire post and on a full-time job — one look for both: a bordered button in
/// the theme's primary colour. Not the error red: stopping is a normal step, asked about in a
/// dialog before anything happens. As bare text it read as a label rather than a button.
class StopHiringButton extends StatelessWidget {
  const StopHiringButton({
    required this.onPressed,
    this.isStopping = false,
    super.key,
  });

  /// Null switches the button off.
  final VoidCallback? onPressed;

  /// Shows a spinner and "Stopping…" while the stop is sent.
  final bool isStopping;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return OutlinedButton.icon(
      onPressed: isStopping ? null : onPressed,
      icon: isStopping
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.front_hand_outlined, size: 18),
      label: Text(isStopping ? 'Stopping…' : 'Stop hiring'),
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: BorderSide(color: primary),
      ),
    );
  }
}
