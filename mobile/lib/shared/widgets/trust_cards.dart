import 'package:zuno/core/utils/formatting.dart';
import 'package:flutter/material.dart';
import 'package:zuno/shared/domain/business_trust.dart';
import 'package:zuno/core/theme/app_colors.dart';

/// One headline figure with a caption, then a short list of supporting facts.
///
/// Shared by the business's own profile and the page a worker opens before applying, so the same
/// record reads identically wherever it appears.
class TrustCard extends StatelessWidget {
  const TrustCard({
    required this.title,
    required this.headline,
    required this.caption,
    required this.rows,
    this.accent,
    super.key,
  });

  final String title;
  final String headline;
  final String caption;
  final List<TrustRow> rows;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = accent ?? theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 0.7,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  headline,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tint,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      caption,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (rows.isNotEmpty) const SizedBox(height: 10),
            for (var i = 0; i < rows.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: i == 0
                    ? null
                    : BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: theme.dividerColor.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        rows[i].label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      rows[i].value,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: rows[i].muted
                            ? FontWeight.w500
                            : FontWeight.w700,
                        color: rows[i].muted
                            ? theme.colorScheme.onSurfaceVariant
                            : rows[i].tone,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TrustRow {
  const TrustRow(this.label, this.value, {this.tone, this.muted = false});

  final String label;
  final String value;
  final Color? tone;

  /// For "None yet" and friends — an absence, not a figure.
  final bool muted;
}

/// "How customers see you" — the delivery record.
class CustomerTrustCard extends StatelessWidget {
  const CustomerTrustCard({required this.trust, this.accent, super.key});

  final CustomerFacingTrust trust;
  final Color? accent;

  @override
  Widget build(BuildContext context) => TrustCard(
    title: 'How customers see you',
    headline: '${trust.eventsCompleted}',
    caption: 'events completed\nsuccessfully',
    accent: accent,
    rows: [
      TrustRow(
        'Reviews on your events',
        trust.hasReviews
            ? '${trust.ratingAverage!.toStringAsFixed(1)} ★  (${trust.reviewCount})'
            : 'None yet',
        muted: !trust.hasReviews,
      ),
      TrustRow('Repeat customers', '${trust.repeatCustomers}'),
    ],
  );
}

/// "How workers see you" — the pay record, led by salary because that is what brings
/// someone to the job.
class WorkerTrustCard extends StatelessWidget {
  const WorkerTrustCard({
    required this.trust,
    this.title = 'How workers see you',
    this.accent,
    super.key,
  });

  final WorkerFacingTrust trust;
  final String title;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The same success colour the status pills use. It was written out here as two hexes that
    // happened to match AppColors — a copy that would have drifted the first time either moved.
    final good = AppColors.status(StatusTone.success, theme.brightness);

    if (!trust.hasHires) {
      return TrustCard(
        title: title,
        headline: '—',
        caption: 'nobody hired yet',
        accent: accent,
        rows: const [
          TrustRow(
            'Pay record',
            'Builds after your first hire',
            muted: true,
          ),
        ],
      );
    }

    return TrustCard(
      title: title,
      headline: trust.averageSalary == null ? '—' : rupees(trust.averageSalary!),
      caption: 'average paid\n${trust.unitLabel}',
      accent: accent,
      rows: [
        if (trust.salaryRangeLabel.isNotEmpty)
          TrustRow('Range across ${trust.totalHires} hires', trust.salaryRangeLabel),
        TrustRow(
          'Paid what you posted',
          '${trust.paidPostedRateCount} of ${trust.totalHires} jobs',
          tone: trust.paidPostedRateCount == trust.totalHires ? good : null,
        ),
        if (trust.raisedPayCount > 0)
          TrustRow(
            'Raised pay above the post',
            '${trust.raisedPayCount} ${trust.raisedPayCount == 1 ? 'job' : 'jobs'}',
            tone: good,
          ),
        if (trust.payTimeLabel case final label?)
          TrustRow('Typical time to pay', label, tone: good),
        if (trust.hasRepeatCrew)
          TrustRow(
            'Repeat crew',
            '${trust.distinctWorkers} workers, ${trust.totalHires} hires',
            tone: good,
          ),
      ],
    ).withDisputeAlert(context, trust, theme);
  }
}

extension on TrustCard {
  /// Overdue wages and open disputes are noise at zero, so they only appear as an alert —
  /// never as permanent rows.
  Widget withDisputeAlert(
    BuildContext context,
    WorkerFacingTrust trust,
    ThemeData theme,
  ) {
    if (trust.openDisputes == 0 && trust.overdueWages <= 0) {
      return this;
    }

    final danger = theme.colorScheme.error;
    final parts = <String>[
      if (trust.openDisputes > 0)
        '${trust.openDisputes} ${trust.openDisputes == 1 ? 'worker reports' : 'workers report'} not being paid',
      if (trust.overdueWages > 0)
        '${rupees(trust.overdueWages)} owed on finished work',
    ];

    return Column(
      children: [
        this,
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: danger.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: danger.withValues(alpha: 0.32)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, size: 18, color: danger),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  parts.join('. ') == ''
                      ? ''
                      : '${parts.join('. ')}. Settle this — it caps your level at 1.',
                  style: theme.textTheme.bodySmall?.copyWith(color: danger),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
