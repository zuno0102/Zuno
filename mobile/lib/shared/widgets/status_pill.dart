import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/ui_config/ui_config.dart';

/// What colour an identity check deserves.
///
/// One function because the two screens that show it had drifted: the profile tab used the amber
/// "in progress" tone while the profile screen used the grey "waiting" one, so the same unverified
/// worker read as two different things on two pages. Grey was also the wrong call — ID Pending means
/// somebody is checking right now, which is a state in motion, not an idle one.
///
/// Amber, never green: green is reserved for a check that has actually passed, and on a worker's
/// green pages a greenish pending badge reads as approval at a glance. Rejected is red, because a
/// rejected check is the one state a worker has to act on. From the `VerificationStatus` labels.
StatusTone verificationTone(String status) =>
    UiConfig.current.tone('VerificationStatus', status);

/// A compact labelled badge: icon, a short state word, and an optional detail.
///
/// Promoted out of the hiring-post card, where five near-identical versions of this shape had
/// grown across the app. The fill and border alphas are the convention every one of them used.
class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    required this.tone,
    this.icon,
    this.detail,
    this.compact = false,
    super.key,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;

  /// A quieter phrase after the label, saying what the state rests on.
  final String? detail;

  /// Drops the detail and tightens the padding, for use inside a dense row.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppColors.status(tone, theme.brightness);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      // Both texts yield rather than overflow. The pill keeps its natural width wherever there
      // is room -- mainAxisSize.min still governs that -- but inside a Flexible on a narrow
      // phone it can now give way instead of pushing content off the right edge.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 13 : 15, color: color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  (compact
                          ? theme.textTheme.labelSmall
                          : theme.textTheme.labelMedium)
                      ?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ),
          if (detail != null && !compact) ...[
            const SizedBox(width: 6),
            // The detail goes first when space runs short: it says what the state rests on,
            // where the label says what the state is.
            Flexible(
              child: Text(
                detail!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Status pills stacked one above the other — for example "Accepted" over "Payment failed" on a
/// crew row — right-aligned, with the same gap wherever pills are stacked.
///
/// At 4px apart two pills read as one block, so the gap lives here rather than in each screen.
/// Null entries are skipped, so a pill that only sometimes applies is passed inline.
class StatusPillStack extends StatelessWidget {
  const StatusPillStack({required this.pills, super.key});

  final List<StatusPill?> pills;

  /// Between two stacked pills.
  static const gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final shown = pills.nonNulls.toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, pill) in shown.indexed) ...[
          if (i > 0) const SizedBox(height: gap),
          pill,
        ],
      ],
    );
  }
}
