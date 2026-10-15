import 'package:zuno/core/utils/formatting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post_application.dart';
import 'package:zuno/features/hiring_post/presentation/providers/business_hiring_posts_notifier.dart';
import 'package:zuno/shared/widgets/error_banner.dart';

/// Raises a confirmed worker's agreed salary — the "they stayed extra hours" case.
/// Increases only: the amount can never be revised downwards, here or on the server.
Future<void> showRaiseSalaryDialog(
  BuildContext context, {
  required HiringPostApplication application,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _RaiseSalaryDialog(application: application),
  );
}

class _RaiseSalaryDialog extends ConsumerStatefulWidget {
  const _RaiseSalaryDialog({required this.application});

  final HiringPostApplication application;

  @override
  ConsumerState<_RaiseSalaryDialog> createState() => _RaiseSalaryDialogState();
}

class _RaiseSalaryDialogState extends ConsumerState<_RaiseSalaryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;

  double get _currentAmount => widget.application.agreedSalaryAmount ?? 0;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final reason = _reasonController.text.trim();

    try {
      await ref
          .read(businessHiringPostsProvider.notifier)
          .raiseAgreedSalary(
            applicationId: widget.application.id,
            newAmount: double.parse(_amountController.text.trim()),
            reason: reason.isEmpty ? null : reason,
          );
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
      return 'Enter an amount greater than 0.';
    }
    if (parsed <= _currentAmount) {
      return 'Must be more than the agreed ₹${_trim(_currentAmount)}.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = salaryUnitWords(
      widget.application.agreedSalaryUnit ?? 'PerEvent',
    );

    return AlertDialog(
      title: const Text('Raise salary'),
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
                '${widget.application.workerName} is confirmed at '
                '₹${_trim(_currentAmount)} $unit.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'New amount',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
                validator: _validateAmount,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  hintText: 'e.g. 3 extra hours on the day',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This is recorded permanently and shown to the worker. '
                'A salary can only ever be increased.',
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

String _trim(double value) => value.truncateToDouble() == value
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);
