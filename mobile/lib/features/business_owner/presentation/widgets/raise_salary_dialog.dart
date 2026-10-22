import 'package:zuno/core/utils/formatting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/booking/domain/entities/booking_worker_assignment.dart';
import 'package:zuno/features/booking/presentation/providers/business_bookings_notifier.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post_application.dart';
import 'package:zuno/features/hiring_post/presentation/providers/business_hiring_posts_notifier.dart';
import 'package:zuno/shared/widgets/error_banner.dart';

/// A raise is extra pay added to the fixed wage — ₹1,000 plus ₹200 for three extra hours is
/// ₹1,200 — never a new total typed in. These are the amounts offered as one-tap shortcuts.
const raiseShortcuts = <double>[200, 500];

/// What the dialog hands back to the caller to actually raise the wage.
typedef RaiseAction =
    Future<void> Function(WidgetRef ref, double increase, String? reason);

/// Extra pay for one worker hired through a hiring post.
///
/// [crewTotal] is what the whole crew is owed now. When given, the dialog shows what it becomes
/// with this raise, so the business sees the figure it will be asked to pay.
Future<void> showRaiseSalaryDialog(
  BuildContext context, {
  required HiringPostApplication application,
  double? crewTotal,
}) {
  final current = application.agreedSalaryAmount ?? 0;
  return _show(
    context,
    title: 'Raise salary',
    subject: application.workerName,
    current: current,
    unit: application.agreedSalaryUnit,
    crewTotal: crewTotal,
    onRaise: (ref, increase, reason) async {
      await ref
          .read(businessHiringPostsProvider.notifier)
          .raiseAgreedSalary(
            applicationId: application.id,
            newAmount: current + increase,
            reason: reason,
          );
      // An order's "Pay crew" figure is worked out from this wage too, and it is loaded with the
      // order, not the post.
      ref.invalidate(businessBookingsProvider);
    },
  );
}

/// Extra pay for one worker the business added to an order directly.
Future<void> showRaiseAssignmentSalaryDialog(
  BuildContext context, {
  required String bookingId,
  required BookingWorkerAssignment worker,
  double? crewTotal,
}) => _show(
  context,
  title: 'Raise salary',
  subject: worker.workerName,
  current: worker.agreedSalaryAmount ?? 0,
  unit: worker.agreedSalaryUnit,
  crewTotal: crewTotal,
  onRaise: (ref, increase, reason) => ref
      .read(businessBookingsProvider.notifier)
      .raiseCrewMemberSalary(
        bookingId,
        worker.workerProfileId,
        increase: increase,
        reason: reason,
      ),
);

/// "Raise all" on an order: the same extra pay for each of [count] workers still to be paid.
Future<void> showRaiseOrderCrewDialog(
  BuildContext context, {
  required String bookingId,
  required int count,
  double? crewTotal,
}) => _show(
  context,
  title: 'Raise all',
  subject: '$count ${count == 1 ? 'worker' : 'workers'}',
  workerCount: count,
  crewTotal: crewTotal,
  onRaise: (ref, increase, reason) async {
    await ref
        .read(businessBookingsProvider.notifier)
        .raiseCrewSalary(bookingId, increase: increase, reason: reason);
    // Post hires on the order are raised on their post, which the order card reads too.
    ref.invalidate(businessHiringPostsProvider);
  },
);

/// "Raise all" on one of the business's own events.
Future<void> showRaisePostCrewDialog(
  BuildContext context, {
  required String postId,
  required int count,
  double? crewTotal,
}) => _show(
  context,
  title: 'Raise all',
  subject: '$count ${count == 1 ? 'worker' : 'workers'}',
  workerCount: count,
  crewTotal: crewTotal,
  onRaise: (ref, increase, reason) async {
    await ref
        .read(businessHiringPostsProvider.notifier)
        .raiseCrewSalary(postId, increase: increase, reason: reason);
    ref.invalidate(businessBookingsProvider);
  },
);

Future<void> _show(
  BuildContext context, {
  required String title,
  required String subject,
  required RaiseAction onRaise,
  double? current,
  String? unit,
  int workerCount = 1,
  double? crewTotal,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _RaiseSalaryDialog(
      title: title,
      subject: subject,
      current: current,
      unit: unit,
      workerCount: workerCount,
      crewTotal: crewTotal,
      onRaise: onRaise,
    ),
  );
}

/// The crew-row button that opens [showRaiseSalaryDialog]. Renders nothing once the worker's
/// salary can no longer be raised, so a row never offers an action the server would refuse.
class RaiseSalaryButton extends StatelessWidget {
  const RaiseSalaryButton({
    required this.application,
    this.crewTotal,
    this.iconSize,
    super.key,
  });

  final HiringPostApplication application;
  final double? crewTotal;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    if (!application.canRaiseSalary) return const SizedBox.shrink();

    return IconButton(
      icon: Icon(Icons.trending_up_rounded, size: iconSize),
      tooltip: 'Raise salary',
      onPressed: () => showRaiseSalaryDialog(
        context,
        application: application,
        crewTotal: crewTotal,
      ),
    );
  }
}

class _RaiseSalaryDialog extends ConsumerStatefulWidget {
  const _RaiseSalaryDialog({
    required this.title,
    required this.subject,
    required this.onRaise,
    this.current,
    this.unit,
    this.workerCount = 1,
    this.crewTotal,
  });

  final String title;

  /// The worker's name, or "5 workers" for Raise all.
  final String subject;

  /// One worker's current wage. Null for Raise all, where each worker keeps their own figure.
  final double? current;
  final String? unit;

  /// How many wages the extra pay lands on.
  final int workerCount;
  final double? crewTotal;
  final RaiseAction onRaise;

  @override
  ConsumerState<_RaiseSalaryDialog> createState() => _RaiseSalaryDialogState();
}

class _RaiseSalaryDialogState extends ConsumerState<_RaiseSalaryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;

  /// The extra pay typed, when it is a usable amount. Null otherwise.
  double? get _increase {
    final parsed = double.tryParse(_amountController.text.trim());
    return parsed != null && parsed > 0 ? parsed : null;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _useShortcut(double amount) {
    _amountController.text = amount.toStringAsFixed(0);
    setState(() {});
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final reason = _reasonController.text.trim();

    try {
      await widget.onRaise(ref, _increase!, reason.isEmpty ? null : reason);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String? _validateAmount(String? value) {
    final parsed = double.tryParse((value ?? '').trim());
    if (parsed == null || parsed <= 0) {
      return 'Enter the extra pay, more than ₹0.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emphasis = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.primary,
    );
    final unit = widget.unit == null ? null : salaryUnitWords(widget.unit!);
    final current = widget.current;
    final crewTotal = widget.crewTotal;
    final increase = _increase;

    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null) ...[
                ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 12),
              ],
              Text(
                current == null
                    ? 'Extra pay for each of ${widget.subject} still to be paid.'
                    : '${widget.subject} is paid ${rupees(current)}'
                          '${unit == null ? '' : ' $unit'}.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: current == null
                      ? 'Extra pay for each'
                      : 'Extra pay',
                  prefixText: '+ ₹ ',
                  border: const OutlineInputBorder(),
                ),
                validator: _validateAmount,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final amount in raiseShortcuts)
                    ActionChip(
                      label: Text('+${rupees(amount)}'),
                      onPressed: _isSaving ? null : () => _useShortcut(amount),
                    ),
                ],
              ),
              if (increase != null && current != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${rupees(current)} + ${rupees(increase)} = '
                  '${rupees(current + increase)}',
                  style: emphasis,
                ),
              ],
              if (crewTotal != null) ...[
                const SizedBox(height: 4),
                Text(
                  increase == null
                      ? 'Pay crew: ${rupees(crewTotal)}'
                      : 'Pay crew: ${rupees(crewTotal)} → '
                            '${rupees(crewTotal + increase * widget.workerCount)}',
                  style: emphasis,
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _reasonController,
                maxLines: 2,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  hintText: 'e.g. 3 extra hours on the day',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'This is recorded permanently and shown to the worker. '
                'Pay can only go up, and only before it is paid.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Raise'),
        ),
      ],
    );
  }
}
