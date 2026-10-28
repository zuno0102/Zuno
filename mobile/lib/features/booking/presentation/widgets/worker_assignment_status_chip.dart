import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/ui_config/ui_config.dart';
import 'package:zuno/core/utils/ui_lookup.dart';

/// Renders a worker's own response to a specific job assignment (Assigned/Accepted/
/// Rejected/Completed) — distinct from [BookingStatusChip], which renders the overall
/// order's lifecycle. Kept as a separate widget (rather than reusing BookingStatusChip for
/// both) so the two never render the same word ("Assigned") side by side meaning different
/// things — the raw status is relabelled here into wording that reads correctly standing
/// next to the order's own status chip.
class WorkerAssignmentStatusChip extends StatelessWidget {
  const WorkerAssignmentStatusChip({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    // Material's own orange, blue, red and green were used here, which are mixed for a light
    // surface and go muddy on the dark scaffold — and they said nothing about what these states
    // mean. The app's status tones say both, and they are the same ones every other badge uses.
    const group = 'BookingWorkerAssignment.Chip';
    final label = UiConfig.current.own(group, status)?.label ?? status;
    final tone = UiConfig.current.tone(group, status);

    final color = AppColors.status(tone, Theme.of(context).brightness);

    return Chip(
      label: Text(label, style: TextStyle(fontSize: 11, color: color)),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}
