import 'package:zuno/features/booking/domain/entities/job_role.dart';
import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/worker/domain/entities/worker_dashboard.dart';
import 'package:zuno/shared/widgets/empty_state.dart';
import 'package:zuno/shared/widgets/status_pill.dart';

/// The jobs behind one of the dashboard's numbers.
///
/// One screen for all four tiles, because they differ only in what they are called and what they
/// contain — a screen each would be four places to fix the same thing.
///
/// The data arrives with the dashboard rather than being fetched again: the counts and the rows come
/// from the same response, so a list that refetched could disagree with the tile that opened it.
class WorkerJobListScreen extends StatelessWidget {
  const WorkerJobListScreen({
    required this.title,
    required this.jobs,
    required this.emptyMessage,
    super.key,
  });

  final String title;
  final List<WorkerJobSummary> jobs;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: jobs.isEmpty
          ? EmptyState(
              icon: Icons.work_outline,
              title: 'Nothing here',
              message: emptyMessage,
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: jobs.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  // A derived line rather than the raw count, which the tile already gave.
                  final paid = jobs.where((j) => j.myWage != null).length;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      paid == jobs.length
                          ? '${jobs.length} ${jobs.length == 1 ? 'job' : 'jobs'}'
                          : '${jobs.length} ${jobs.length == 1 ? 'job' : 'jobs'} · '
                                '$paid with a wage recorded',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }

                return _JobRow(job: jobs[index - 1]);
              },
            ),
    );
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow({required this.job});

  final WorkerJobSummary job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    // The variant where there is one — "Wedding catering" rather than "Catering" —
                    // because that is what the worker actually did on the day.
                    job.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (job.needsMyAnswer)
                  const StatusPill(
                    label: 'Answer needed',
                    tone: StatusTone.danger,
                    compact: true,
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              job.businessName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            _Line(
              icon: Icons.event_outlined,
              text: '${formatDate(job.scheduledDate)} · '
                  '${formatTime(job.scheduledDate)}',
            ),
            if (job.location case final where? when where.isNotEmpty)
              _Line(icon: Icons.place_outlined, text: where),
            // What they are on this particular job. Said on every row rather than only where a
            // role grants something, because "Supervisor" is the answer to "what am I here for"
            // just as much as "Lead" is — and knowing which job made them the Lead was, until
            // now, a matter of opening each one in turn.
            if (job.myRole case final role? when role.trim().isNotEmpty)
              _Line(
                icon: JobRole.grantsWorkControl(role)
                    ? Icons.star_outline
                    : Icons.badge_outlined,
                text: JobRole.descriptions[role] == null
                    ? role
                    : '$role · ${JobRole.descriptions[role]}',
                tint: JobRole.grantsWorkControl(role)
                    ? theme.colorScheme.primary
                    : null,
              ),
            _Line(
              icon: Icons.payments_outlined,
              // Said either way: "paid outside Zuno" and "wage not recorded" look identical if the
              // line is simply left off, and only one of them is a problem.
              text: job.wageLabel ?? 'Paid outside Zuno',
              tint: job.myWage != null ? theme.colorScheme.primary : null,
            ),
            if (job.source == 'Post')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  // Worth distinguishing: a standalone post is the business's own event rather than
                  // a customer's order, and it behaves differently if anything goes wrong.
                  'Hired through a job post',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, this.tint});

  final IconData icon;
  final String text;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: tint ?? theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: tint,
                fontWeight: tint == null ? null : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
