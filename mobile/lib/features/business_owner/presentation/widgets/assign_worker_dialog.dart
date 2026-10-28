import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/presentation/providers/business_bookings_notifier.dart';
import 'package:zuno/features/business_owner/domain/entities/business_worker.dart';
import 'package:zuno/features/business_owner/domain/entities/worker_busy_period.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_providers.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_workers_notifier.dart';
import 'package:zuno/features/business_owner/presentation/widgets/salary_unit_dropdown.dart';
import 'package:zuno/shared/widgets/error_banner.dart';

Future<Booking?> showAssignWorkerDialog(
  BuildContext context, {
  required Booking booking,
}) {
  return showDialog<Booking>(
    context: context,
    builder: (context) => _AssignWorkerDialog(booking: booking),
  );
}

class _AssignWorkerDialog extends ConsumerStatefulWidget {
  const _AssignWorkerDialog({required this.booking});

  final Booking booking;

  @override
  ConsumerState<_AssignWorkerDialog> createState() =>
      _AssignWorkerDialogState();
}

class _AssignWorkerDialogState extends ConsumerState<_AssignWorkerDialog> {
  String? _selectedWorkerId;
  late DateTime _scheduledDate;
  final _salaryController = TextEditingController();

  /// Per event by default — the commonest way a one-off job is priced.
  String _salaryUnit = SalaryUnit.perEvent;
  bool _isSubmitting = false;
  bool _isLoadingAvailability = false;
  String? _errorMessage;
  final Map<String, List<WorkerBusyPeriod>> _busyDatesByWorker = {};

  @override
  void initState() {
    super.initState();
    _scheduledDate = widget.booking.scheduledDate;
  }

  @override
  void dispose() {
    _salaryController.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isBusyOnSelectedDate(String workerProfileId) =>
      (_busyDatesByWorker[workerProfileId] ?? const []).any(
        (period) => _isSameDay(period.startsAt, _scheduledDate),
      );

  Future<void> _loadBusyDates(List<BusinessWorker> workers) async {
    final missing = workers
        .where((w) => !_busyDatesByWorker.containsKey(w.workerProfileId))
        .toList();
    if (missing.isEmpty) {
      return;
    }

    setState(() => _isLoadingAvailability = true);
    try {
      final results = await Future.wait(
        missing.map(
          (w) => ref
              .read(businessRepositoryProvider)
              .getWorkerBusyDates(w.workerProfileId),
        ),
      );
      if (mounted) {
        setState(() {
          for (var i = 0; i < missing.length; i++) {
            _busyDatesByWorker[missing[i].workerProfileId] = results[i];
          }
        });
      }
    } catch (_) {
      // Availability is a convenience hint only — the server still enforces the real
      // conflict check on submit, so a failed lookup here just means no hint is shown.
    } finally {
      if (mounted) {
        setState(() => _isLoadingAvailability = false);
      }
    }
  }

  /// A plain [ListView] in its own bottom sheet, rather than a [DropdownButtonFormField]:
  /// that widget's popup menu positions itself relative to the whole screen, which inside an
  /// [AlertDialog] can render overlapping the dialog instead of neatly under the field.
  Future<void> _showWorkerPicker(List<BusinessWorker> activeWorkers) async {
    await _loadBusyDates(activeWorkers);
    if (!mounted) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: activeWorkers.map((worker) {
            final isBusy = _isBusyOnSelectedDate(worker.workerProfileId);
            return ListTile(
              title: Text(worker.workerName),
              subtitle: isBusy
                  ? Text(
                      'Already assigned elsewhere on this date',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    )
                  : const Text('Available'),
              trailing: worker.workerProfileId == _selectedWorkerId
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () => Navigator.of(context).pop(worker.workerProfileId),
            );
          }).toList(),
        ),
      ),
    );

    if (selected != null) {
      setState(() => _selectedWorkerId = selected);
    }
  }

  Future<void> _pickScheduledDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: ref
          .read(currentAppOptionsProvider)
          .lastPickableDate(DateTime.now()),
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledDate),
    );
    if (time == null) {
      return;
    }

    setState(() {
      _scheduledDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (_selectedWorkerId == null) {
      setState(() => _errorMessage = 'Select a worker.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final updated = await ref
          .read(businessBookingsProvider.notifier)
          .assignWorker(
            widget.booking.id,
            _selectedWorkerId!,
            scheduledDate: _scheduledDate,
            // Both halves or neither. The server refuses an amount with no unit, so the unit is
            // only sent when there is an amount for it to describe.
            salaryAmount: double.tryParse(_salaryController.text.trim()),
            salaryUnit: double.tryParse(_salaryController.text.trim()) == null
                ? null
                : _salaryUnit,
          );
      if (mounted) {
        Navigator.of(context).pop(updated);
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final workersAsync = ref.watch(businessWorkersProvider);

    return AlertDialog(
      // No count. A customer books a service, not a headcount — the number that used to sit here
      // came from the service definition and meant nothing about this order.
      title: const Text('Add worker'),
      content: workersAsync.when(
        loading: () => const SizedBox(
          height: 60,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => ErrorBanner(message: error.toString()),
        data: (workers) {
          final alreadyAssignedIds = widget.booking.assignedWorkers
              .where((a) => !a.isRejected)
              .map((a) => a.workerProfileId)
              .toSet();
          final activeWorkers = workers
              .where(
                (w) =>
                    w.isActive &&
                    !alreadyAssignedIds.contains(w.workerProfileId),
              )
              .toList();
          if (activeWorkers.isEmpty) {
            return const Text(
              'No more available workers to add. Invite one from the Workers tab first.',
            );
          }

          final selectedIsBusy =
              _selectedWorkerId != null &&
              _isBusyOnSelectedDate(_selectedWorkerId!);

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null) ...[
                ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 12),
              ],
              Builder(
                builder: (context) {
                  final selectedName = activeWorkers
                      .where((w) => w.workerProfileId == _selectedWorkerId)
                      .map((w) => w.workerName)
                      .firstOrNull;

                  return InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => _showWorkerPicker(activeWorkers),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Worker',
                        border: const OutlineInputBorder(),
                        suffixIcon: _isLoadingAvailability
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedName ?? 'Select a worker',
                            style: selectedName == null
                                ? TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  )
                                : null,
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  );
                },
              ),
              if (selectedIsBusy) ...[
                const SizedBox(height: 4),
                Text(
                  'This worker is already assigned to another job on this date — pick a different worker or change the date.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // The same pair a hiring post uses, because it records the same thing: what one
              // worker is paid for one job. Without it a hand-added worker had no wage anywhere,
              // so the order owed nobody and counted as settled having paid them nothing.
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _salaryController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Salary (optional)',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SalaryUnitDropdown(
                      value: _salaryUnit,
                      onChanged: (value) => setState(() => _salaryUnit = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _salaryController.text.trim().isEmpty
                    ? 'Leave blank if you pay them outside Zuno.'
                    : 'They will be included when you pay this job\'s crew.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: _pickScheduledDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date & time',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${formatDate(_scheduledDate)} · ${formatTime(_scheduledDate)}',
                      ),
                      const Icon(Icons.edit_calendar_outlined),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Assign'),
        ),
      ],
    );
  }
}
