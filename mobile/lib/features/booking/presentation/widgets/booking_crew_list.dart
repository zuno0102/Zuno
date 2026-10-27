import 'package:flutter/material.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/domain/entities/booking_worker_assignment.dart';
import 'package:zuno/features/booking/domain/entities/job_role.dart';
import 'package:zuno/features/booking/presentation/widgets/set_crew_role_sheet.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post_application.dart';
import 'package:zuno/features/work_chat/presentation/widgets/work_message_button.dart';
import 'package:zuno/shared/widgets/call_icon_button.dart';
import 'package:zuno/shared/widgets/status_with_actions.dart';

/// Who is on this job, and where each of them stands.
///
/// Until this existed a business could add three workers and the screen looked exactly as it had
/// before — the only way to confirm it had worked was to reopen the picker and see them greyed
/// out. Their wage was invisible too, because there was nowhere to record one.
///
/// Shaped like the crew list on the hiring-post tab so the two read the same way: a heading with
/// the count, opening to a row per person.
class BookingCrewList extends StatelessWidget {
  const BookingCrewList({
    required this.booking,
    this.canSetRoles = false,
    this.initiallyExpanded = false,
    this.postHires = const {},
    this.raiseSalaryAction,
    this.raiseAssignmentAction,
    this.onWorkerTap,
    this.onRaiseAll,
    super.key,
  });

  /// Builds the raise-salary action for a worker added to the order directly, whose wage sits on
  /// the order. Null where raising is not the viewer's to do.
  final Widget Function(BookingWorkerAssignment worker)? raiseAssignmentAction;

  /// Tapping a name: opens what the viewer can do with that worker. Null where there is nothing.
  final void Function(
    BookingWorkerAssignment worker,
    HiringPostApplication? hire,
  )?
  onWorkerTap;

  /// Gives everyone still to be paid the same extra pay. Null hides the button.
  final VoidCallback? onRaiseAll;

  /// Workers hired through this order's hiring post, by worker profile id.
  ///
  /// Their wage is agreed on the post, not on the order, so without this they would read as
  /// paid outside Zuno and be left out of the amount owed.
  final Map<String, HiringPostApplication> postHires;

  /// Builds the raise-salary action for a post hire whose salary can still be raised. Null where
  /// raising is not the viewer's to do.
  final Widget Function(HiringPostApplication hire)? raiseSalaryAction;

  /// Whether the crew is already unfurled when the card appears.
  ///
  /// Shut by default. In a list of orders each card unfurling its crew turns a scannable column of
  /// jobs into a wall, and the count in the heading already answers the question most of them are
  /// opened for. A screen dedicated to one order is the exception and passes true.
  final bool initiallyExpanded;

  final Booking booking;

  /// Whether holding a name opens the role sheet.
  ///
  /// Only the owner, and only on their own order. A role carries the power to declare the work
  /// started, so the gesture is not offered where it would be refused by the server anyway.
  final bool canSetRoles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crew = booking.assignedWorkers;

    // No heading over nothing. The Add worker button already says what to do next.
    if (crew.isEmpty) return const SizedBox.shrink();

    final owed = crew
        .where((w) => !w.isRejected)
        .fold<double>(0, (sum, w) => sum + _owedTo(w));

    return Theme(
      // The default divider makes an ExpansionTile look like a separate card inside a card.
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Row(
          children: [
            Text('Crew', style: theme.textTheme.labelLarge),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _countLabel(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (owed > 0) ...[
              const SizedBox(width: 8),
              Text(
                '${rupees(owed)} owed',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        children: [
          for (final worker in crew)
            _CrewRow(
              worker: worker,
              hire: postHires[worker.workerProfileId],
              raiseSalaryAction: raiseSalaryAction,
              raiseAssignmentAction: raiseAssignmentAction,
              onTap: switch (onWorkerTap) {
                final tap? => () => tap(
                  worker,
                  postHires[worker.workerProfileId],
                ),
                null => null,
              },
              canCall: booking.canCallCrewMember(worker),
              // Message the worker once they have taken the job on, while the order is live. The
              // business is the go-between: workers and customers never contact each other.
              canMessage:
                  !booking.isCancelled &&
                  (worker.isAccepted || worker.isCompleted),
              // Only once they have said yes. A role is what lets somebody declare this job
              // started, so offering it to a worker who has not answered would be handing that
              // power to somebody who might still decline — and the server refuses it anyway.
              // Completed is in: a lead who finished their own part is still the lead.
              // Three conditions, and all three are the server's: the order is live, this is the
              // owner, and the worker has said yes. Offering the gesture where the server would
              // refuse it is how a feature comes to look broken.
              onSetRole:
                  canSetRoles &&
                      booking.canHoldCrewRoles &&
                      (worker.isAccepted || worker.isCompleted)
                  ? () => SetCrewRoleSheet.show(
                      context,
                      bookingId: booking.id,
                      worker: worker,
                    )
                  : null,
            ),
          if (onRaiseAll case final raiseAll?)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: raiseAll,
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

  /// What this worker is still owed through Zuno: their wage on the order, or else their wage on
  /// the hiring post that brought them in.
  double _owedTo(BookingWorkerAssignment worker) {
    if (worker.isPayee) {
      return worker.isPaid ? 0 : worker.agreedSalaryAmount!;
    }
    final hire = postHires[worker.workerProfileId];
    if (hire == null || !hire.hasAgreedSalary || hire.isPaid) return 0;
    return hire.agreedSalaryAmount!;
  }

  /// "2 of 18", "2 assigned", or "2 worked this job".
  String _countLabel() {
    final onJob = booking.assignedWorkers.where((w) => !w.isRejected).length;

    // Once the job has run, the target is history and the count is simply who worked it —
    // otherwise a finished job reads as though somebody never turned up.
    if (booking.isWorkStarted || booking.isCompleted) {
      return '$onJob worked this job';
    }

    // A crew size of 0 means it is agreed per order, not that nobody is needed. "2 of 0" is
    // nonsense, so the target is left off until there is one.
    return booking.requiredWorkerCount > 0
        ? '$onJob of ${booking.requiredWorkerCount}'
        : '$onJob assigned';
  }
}

class _CrewRow extends StatelessWidget {
  const _CrewRow({
    required this.worker,
    required this.canCall,
    this.canMessage = false,
    this.onSetRole,
    this.hire,
    this.raiseSalaryAction,
    this.raiseAssignmentAction,
    this.onTap,
  });

  final Widget Function(BookingWorkerAssignment worker)? raiseAssignmentAction;

  /// Tapping the row: the worker menu. Null where there is nothing to offer.
  final VoidCallback? onTap;

  final BookingWorkerAssignment worker;

  /// Their hiring-post record, when the hiring post is how they came onto this order.
  final HiringPostApplication? hire;

  final Widget Function(HiringPostApplication hire)? raiseSalaryAction;

  /// Their wage on the order, or else on the hiring post. Null when they are paid outside Zuno.
  String? get _wageLabel {
    if (worker.wageLabel case final label?) return label;
    final hire = this.hire;
    if (hire == null || !hire.hasAgreedSalary) return null;
    return '${rupees(hire.agreedSalaryAmount!)} '
        '${salaryUnitWords(hire.agreedSalaryUnit ?? SalaryUnit.perEvent)}'
        '${hire.hasBeenRaised ? ' (raised)' : ''}';
  }

  bool get _isPaid => worker.isPaid || (hire?.isPaid ?? false);

  /// Worked out by the order, which is the only thing that knows whether the job is over.
  final bool canCall;

  /// Whether the business can message this worker from here.
  final bool canMessage;

  /// Sets or removes this person's role, from the role icon on the row (or holding the row).
  /// Null where that is not the viewer's to do.
  final VoidCallback? onSetRole;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final declined = worker.isRejected;
    // Extra work on the day: raise this worker's wage before the crew is paid.
    final raiseAction = switch ((hire, raiseSalaryAction)) {
      (final hire?, final build?) when hire.canRaiseSalary && !declined =>
        build(hire),
      // Added to the order directly: the wage sits on the order itself.
      (null, _) when worker.canRaiseSalary => raiseAssignmentAction?.call(
        worker,
      ),
      _ => null,
    };

    final roleAction = switch (onSetRole) {
      final setRole? => CrewRoleButton(role: worker.role, onPressed: setRole),
      null => null,
    };

    final (icon, colour) = switch (worker.displayStatus) {
      'Completed' => (Icons.check_circle, theme.colorScheme.primary),
      'InProgress' => (Icons.play_circle_fill, theme.colorScheme.tertiary),
      'Active' => (Icons.check_circle_outline, theme.colorScheme.primary),
      'Declined' => (Icons.cancel_outlined, theme.colorScheme.error),
      _ => (Icons.schedule, theme.colorScheme.outline),
    };

    return InkWell(
      onTap: onTap,
      onLongPress: onSetRole,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The Lead is marked on the row itself, not only in the line of text beneath: on a job
            // with six people, who is in charge is the one thing worth seeing without reading.
            // Only the Lead — a star on a Supervisor would claim a power they do not have.
            JobRole.grantsWorkControl(worker.role) && !declined
                ? Icon(
                    Icons.star_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  )
                : Icon(icon, size: 18, color: colour),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    worker.workerName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      // A refusal is still listed, muted. A business that cannot see it believes
                      // the job is staffed.
                      color: declined
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onSurface,
                      decoration: declined ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    [
                      if (worker.role case final role? when role.isNotEmpty)
                        role,
                      worker.displayStatusLabel,
                      // Said plainly rather than left blank: "no wage" and "wage not yet entered"
                      // look identical otherwise, and only one of them is a mistake.
                      _wageLabel ?? 'Paid outside Zuno',
                      if (_isPaid) 'Paid',
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (worker.cannotBePaidYet) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 13,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'No payout details on file',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (canMessage ||
                canCall ||
                raiseAction != null ||
                roleAction != null)
              CardActions(
                actions: [
                  ?roleAction,
                  ?raiseAction,
                  if (canMessage)
                    WorkMessageButton(
                      counterpartId: worker.workerProfileId,
                      counterpartName: worker.workerName,
                      tooltip: 'Message worker',
                    ),
                  if (canCall)
                    CallIconButton(
                      phoneNumber: worker.workerPhone!,
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
