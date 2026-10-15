import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/booking/domain/entities/booking_worker_assignment.dart';
import 'package:zuno/features/booking/domain/entities/job_role.dart';
import 'package:zuno/features/booking/presentation/providers/business_bookings_notifier.dart';
import 'package:zuno/shared/widgets/app_messages.dart';

/// What one person is on one job — opened by holding their name on the crew list.
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
/// The role ends with the order. Nothing follows the person to their next job.
class SetCrewRoleSheet extends ConsumerStatefulWidget {
  const SetCrewRoleSheet({
    required this.bookingId,
    required this.worker,
    super.key,
  });

  final String bookingId;
  final BookingWorkerAssignment worker;

  static Future<bool?> show(
    BuildContext context, {
    required String bookingId,
    required BookingWorkerAssignment worker,
  }) => showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SetCrewRoleSheet(bookingId: bookingId, worker: worker),
  );

  @override
  ConsumerState<SetCrewRoleSheet> createState() => _SetCrewRoleSheetState();
}

class _SetCrewRoleSheetState extends ConsumerState<SetCrewRoleSheet> {
  late String? _chosen = JobRole.isKnown(widget.worker.role)
      ? JobRole.all.firstWhere(
          (r) => r.toLowerCase() == widget.worker.role!.trim().toLowerCase(),
        )
      // A legacy free-text role starts unselected: it is not one of the three, and the owner is
      // here to replace it.
      : null;

  bool _saving = false;

  bool get _hasRole => (widget.worker.role ?? '').trim().isNotEmpty;

  Future<void> _save(String? role) async {
    setState(() => _saving = true);

    final messenger = AppMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await ref
          .read(businessBookingsProvider.notifier)
          .setCrewRole(
            widget.bookingId,
            widget.worker.workerProfileId,
            role: role,
          );

      if (!mounted) return;

      messenger.showSuccess(
        role == null
            ? '${widget.worker.workerName} is a crew member again'
            : '${widget.worker.workerName} is now $role on this job',
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
          Text(widget.worker.workerName, style: theme.textTheme.titleMedium),
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
