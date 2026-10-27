import 'package:flutter/material.dart';

/// Says what this worker is on this job, and of no other — "You're the Lead on this job".
///
/// Shared by a customer order and a business's own event, which hold the same three roles with
/// the same one power: a Lead can start and finish the work.
///
/// Worth stating rather than leaving to be inferred from the buttons: the same person can lead
/// Saturday's job and be an ordinary pair of hands on Sunday's, and for a Supervisor or Support
/// there are no buttons at all — so without this line their role would be invisible to them.
class JobRoleBanner extends StatelessWidget {
  const JobRoleBanner({
    super.key,
    required this.role,
    required this.canMoveWork,
    required this.isOver,
  });

  final String role;

  /// Whether this role can start and finish the job right now. Only a Lead, and only while the
  /// job is still live.
  final bool canMoveWork;

  /// Whether the job is finished or called off, so the role is a record rather than a job to do.
  final bool isOver;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            // A star only where there is power behind it, so it does not promise a Supervisor
            // buttons that are not coming.
            canMoveWork ? Icons.star_rounded : Icons.badge_outlined,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              // Past tense once it is over. The role was only ever for this one order, so on a
              // finished job it is a record of what somebody did, not a job still to do — and
              // reading "you can start and finish it" under a completed order would be the app
              // offering work that no longer exists.
              isOver
                  ? 'You were the $role on this job.'
                  : canMoveWork
                  ? "You're the $role on this job — you can start and finish it."
                  : "You're the $role on this job.",
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
