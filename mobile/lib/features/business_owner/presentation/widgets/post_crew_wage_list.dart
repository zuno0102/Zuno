import 'package:flutter/material.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/business_owner/presentation/widgets/crew_member_sheet.dart';
import 'package:zuno/features/business_owner/presentation/widgets/raise_salary_dialog.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post_application.dart';
import 'package:zuno/features/work_chat/presentation/widgets/work_message_button.dart';
import 'package:zuno/shared/widgets/call_icon_button.dart';
import 'package:zuno/shared/widgets/status_with_actions.dart';

/// Everyone on one of the business's own events and what each of them is owed — the crew section
/// of its Status management card.
///
/// Shaped like the crew list on an order card. It is where the business raises a worker's wage for
/// extra work before tapping Pay all, which then charges the new total.
class PostCrewWageList extends StatelessWidget {
  const PostCrewWageList({required this.post, super.key});

  final HiringPost post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crew = post.applications.where((a) => a.isAccepted).toList();

    // No heading over nothing; the tracks above already say nobody is hired.
    if (crew.isEmpty) return const SizedBox.shrink();

    return Theme(
      // The default divider makes an ExpansionTile look like a separate card inside a card.
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Row(
          children: [
            Text('Crew', style: theme.textTheme.labelLarge),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                post.isWorkStarted
                    ? '${crew.length} worked this job'
                    : '${crew.length} of ${post.workersNeeded}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (post.outstandingAmount > 0) ...[
              const SizedBox(width: 8),
              Text(
                '${rupees(post.outstandingAmount)} owed',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        children: [
          for (final hire in crew)
            _CrewWageRow(
              hire: hire,
              canCall: post.canCallCrewMember(hire),
              crewTotal: post.outstandingAmount,
            ),
          if (crew.where((h) => h.canRaiseSalary).length case final count
              when count > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => showRaisePostCrewDialog(
                  context,
                  postId: post.id,
                  count: count,
                  crewTotal: post.outstandingAmount,
                ),
                icon: const Icon(Icons.trending_up_rounded, size: 18),
                label: const Text('Raise all'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _CrewWageRow extends StatelessWidget {
  const _CrewWageRow({
    required this.hire,
    required this.canCall,
    required this.crewTotal,
  });

  final HiringPostApplication hire;
  final bool canCall;
  final double crewTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = [
      if (hire.hasAgreedSalary)
        '${rupees(hire.agreedSalaryAmount!)} '
            '${salaryUnitWords(hire.agreedSalaryUnit ?? SalaryUnit.perEvent)}'
            '${hire.hasBeenRaised ? ' (raised)' : ''}',
      ?hire.paymentLabel,
    ].join(' · ');

    // Tapping the name: raise, message or call, whichever applies right now.
    return InkWell(
      onTap: () => CrewMemberSheet.show(
        context,
        name: hire.workerName,
        detail: detail,
        onRaise: hire.canRaiseSalary
            ? () => showRaiseSalaryDialog(
                context,
                application: hire,
                crewTotal: crewTotal,
              )
            : null,
        messageCounterpartId: hire.workerProfileId,
        phone: canCall ? hire.workerPhone : null,
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hire.workerName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            CardActions(
              actions: [
                if (hire.canRaiseSalary)
                  RaiseSalaryButton(application: hire, crewTotal: crewTotal),
                WorkMessageButton(
                  counterpartId: hire.workerProfileId,
                  counterpartName: hire.workerName,
                  tooltip: 'Message worker',
                ),
                if (canCall)
                  CallIconButton(
                    phoneNumber: hire.workerPhone!,
                    tooltip: 'Call worker',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
