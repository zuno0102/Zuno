import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/booking/domain/entities/booking_worker_assignment.dart';
import 'package:zuno/shared/domain/job_role.dart';
import 'package:zuno/features/booking/presentation/providers/business_bookings_notifier.dart';
import 'package:zuno/shared/widgets/app_messages.dart';

/// The role icon on a crew row: outlined to assign a role, filled once one is set, so who has a
/// role shows across a crew at a glance. The one way into [SetCrewRoleSheet] that people find —
/// holding the row was the only way before, and nobody did.
///
/// Used on an order's crew and on the crew of a hiring post raised for an order.
class CrewRoleButton extends StatelessWidget {
  const CrewRoleButton({
    required this.role,
    required this.onPressed,
    this.iconSize,
    super.key,
  });

  /// The role already set, or null.
  final String? role;
  final VoidCallback onPressed;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final role = this.role;
    final hasRole = role != null && role.isNotEmpty;

    return IconButton(
      onPressed: onPressed,
      tooltip: hasRole ? 'Change role ($role)' : 'Assign role',
      iconSize: iconSize,
      icon: Icon(hasRole ? Icons.badge : Icons.badge_outlined),
      color: hasRole ? Theme.of(context).colorScheme.primary : null,
    );
  }
}

/// What one person is on one job — opened from the role icon on the crew list, or by holding
/// their name.
///
/// Three roles, picked from a list rather than typed. Free text only ever produced trades —
/// "Painter", "Chef" — which say what somebody does for a living, not what they are doing on this
/// order. It also quietly granted nothing, because only one specific value carries any power, so a
/// typed "Leed" looked set and did nothing.
///
/// **Only Lead can move the job's status.** Supervisor watches, Support fixes what the work needs.
/// Said on each row rather than left to be discovered, because the owner choosing here is deciding
/// who can declare the job started while they are not there.
///
/// The role ends with the job. Nothing follows the person to their next one.
///
/// Used for a customer order's crew ([show]) and a business's own event ([open], with the save
/// that event needs), which hold the same three roles.
class SetCrewRoleSheet extends ConsumerStatefulWidget {
  const SetCrewRoleSheet({
    required this.workerName,
    required this.currentRole,
    required this.onSave,
    super.key,
  });

  final String workerName;

  /// The role already set, or null.
  final String? currentRole;

  /// Saves the chosen role; null takes it away.
  final Future<void> Function(WidgetRef ref, String? role) onSave;

  /// For a worker on a customer order's crew.
  static Future<bool?> show(
    BuildContext context, {
    required String bookingId,
    required BookingWorkerAssignment worker,
  }) => open(
    context,
    workerName: worker.workerName,
    currentRole: worker.role,
    onSave: (ref, role) => ref
        .read(businessBookingsProvider.notifier)
        .setCrewRole(bookingId, worker.workerProfileId, role: role),
  );

  /// For any crew, given how to save the role.
  static Future<bool?> open(
    BuildContext context, {
    required String workerName,
    required String? currentRole,
    required Future<void> Function(WidgetRef ref, String? role) onSave,
  }) => showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SetCrewRoleSheet(
      workerName: workerName,
      currentRole: currentRole,
      onSave: onSave,
    ),
  );

  @override
  ConsumerState<SetCrewRoleSheet> createState() => _SetCrewRoleSheetState();
}

class _SetCrewRoleSheetState extends ConsumerState<SetCrewRoleSheet> {
  late String? _chosen = JobRole.isKnown(widget.currentRole)
      ? JobRole.all.firstWhere(
          (r) => r.toLowerCase() == widget.currentRole!.trim().toLowerCase(),
        )
      // A legacy free-text role starts unselected: it is not one of the three, and the owner is
      // here to replace it.
      : null;

  bool _saving = false;

  bool get _hasRole => (widget.currentRole ?? '').trim().isNotEmpty;

  Future<void> _save(String? role) async {
    setState(() => _saving = true);

    final messenger = AppMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await widget.onSave(ref, role);

      if (!mounted) return;

      messenger.showSuccess(
        role == null
            ? '${widget.workerName} is a crew member again'
            : '${widget.workerName} is now $role on this job',
      );
      navigator.pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showFailure(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.workerName, style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            'Their role on this job only',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),

          for (final role in JobRole.all)
            _RoleOption(
              role: role,
              description: JobRole.descriptions[role]!,
              selected: _chosen == role,
              // The one that carries power, marked as such.
              grantsControl: JobRole.grantsWorkControl(role),
              enabled: !_saving,
              onTap: () => setState(() => _chosen = role),
            ),

          const SizedBox(height: 8),
          Row(
            children: [
              if (_hasRole)
                TextButton.icon(
                  onPressed: _saving ? null : () => _save(null),
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Remove role'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _saving || _chosen == null
                    ? null
                    : () => _save(_chosen),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One role, with what it means and whether it carries any power.
///
/// A row rather than a chip: three choices that differ in what they *allow* need a sentence each,
/// and a row of bare words would make the owner guess which one can close the job.
class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.role,
    required this.description,
    required this.selected,
    required this.grantsControl,
    required this.enabled,
    required this.onTap,
  });

  final String role;
  final String description;
  final bool selected;
  final bool grantsControl;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colours = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? colours.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? colours.primary
                  : colours.outlineVariant.withValues(alpha: 0.8),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? colours.primary : colours.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          role,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colours.onSurface,
                          ),
                        ),
                        if (grantsControl) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.star_rounded,
                            size: 15,
                            color: colours.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colours.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
