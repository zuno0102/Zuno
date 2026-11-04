import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zuno/features/rental/domain/entities/rental_payment.dart';

/// The most steps one item can have — the Rent server's `Rent:MaxCancelSteps`.
const rentalMaxCancelSteps = 5;

/// How far ahead a step can start, in days (×24 for hours) — the server's `Rent:MaxCancelDaysBefore`.
const rentalMaxCancelDaysBefore = 366;

/// One step as the business types it: "5" days before → "0.5" %.
class RentalCancelStepRow {
  RentalCancelStepRow({int? unitsBefore, double? percent})
    : units = TextEditingController(text: unitsBefore?.toString() ?? ''),
      percent = TextEditingController(
        text: percent == null
            ? ''
            : rentalPercent(percent).replaceFirst('%', ''),
      );

  final TextEditingController units;
  final TextEditingController percent;

  /// Null while either box is not a number yet; the form's validators say which.
  RentalCancelStep? toStep() {
    final u = int.tryParse(units.text.trim());
    final p = double.tryParse(percent.text.trim());
    return u == null || p == null
        ? null
        : RentalCancelStep(unitsBefore: u, percent: p);
  }

  void dispose() {
    units.dispose();
    percent.dispose();
  }
}

/// What is wrong with the steps as a whole, as the server would say it — or null. Each box's own
/// range is checked by its validator.
String? rentalCancelStepsProblem(List<RentalCancelStep> steps) {
  if (steps.isEmpty) return null;
  if (steps.map((s) => s.unitsBefore).toSet().length != steps.length) {
    return 'Each cancellation step needs its own number of days or hours.';
  }
  if (!steps.any((s) => s.unitsBefore == 0)) {
    return 'Add a step for cancelling on the start day itself (0).';
  }
  final ordered = [...steps]
    ..sort((a, b) => a.unitsBefore.compareTo(b.unitsBefore));
  for (var i = 1; i < ordered.length; i++) {
    if (ordered[i].percent > ordered[i - 1].percent) {
      return 'Cancelling earlier cannot cost more than cancelling later.';
    }
  }
  return null;
}

/// The item form's cancellation charge, like a bus ticket: steps by time left before the start —
/// days, or hours for an hourly item — each a percent of the order, never above the limit Zuno set
/// for the kind of item ("Plastic chairs: up to 2%").
class RentalCancelStepsSection extends StatelessWidget {
  const RentalCancelStepsSection({
    required this.rows,
    required this.unit,
    required this.onAdd,
    required this.onRemove,
    this.limit,
    this.limitName,
    super.key,
  });

  final List<RentalCancelStepRow> rows;

  /// [RentalCancelUnit.day] or [RentalCancelUnit.hour].
  final String unit;

  /// The most percent allowed for the chosen category; null until one is chosen.
  final double? limit;

  /// What the limit is told by: the sub-category, or the category.
  final String? limitName;

  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  bool get _hours => unit == RentalCancelUnit.hour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final maxUnits = _hours
        ? rentalMaxCancelDaysBefore * 24
        : rentalMaxCancelDaysBefore;
    final noLimit = limit != null && limit! <= 0;

    return Column(
      key: const ValueKey('cancel-steps-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cancellation charge', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          limit == null
              ? 'Choose a category to see how much you may keep.'
              : noLimit
              ? 'Cancellation is always free for ${limitName ?? 'this kind of item'}.'
              : 'Up to ${rentalPercent(limit!)} of the order for '
                    '${limitName ?? 'this kind of item'}, set by Zuno. '
                    'Only when the customer cancels; you cancelling gives all of it back.',
          key: const ValueKey('cancel-steps-limit'),
          style: muted,
        ),
        if (rows.isEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Free cancellation. Add steps to keep part of the order when a '
            'customer cancels late, e.g. 5+ ${_hours ? 'hours' : 'days'} 0.5%, '
            '${_hours ? 'last hour' : 'on the day'} 2%.',
            style: muted,
          ),
        ],
        for (var i = 0; i < rows.length; i++)
          Padding(
            key: ValueKey('cancel-step-$i'),
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('cancel-step-$i-units'),
                    controller: rows[i].units,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: _hours ? 'Hours before' : 'Days before',
                      helperText: '0 = ${_hours ? 'last hour' : 'on the day'}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (value) {
                      final parsed = int.tryParse((value ?? '').trim());
                      if (parsed == null) return 'Enter a number.';
                      if (parsed > maxUnits) return 'At most $maxUnits.';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('cancel-step-$i-percent'),
                    controller: rows[i].percent,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Charge',
                      suffixText: '%',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (value) {
                      final text = (value ?? '').trim();
                      final parsed = double.tryParse(text);
                      if (parsed == null || parsed < 0) {
                        return 'Enter a percent.';
                      }
                      if (RegExp(r'\.\d{3,}$').hasMatch(text)) {
                        return 'At most 2 decimals.';
                      }
                      if (limit != null && parsed > limit! + 0.0001) {
                        return 'At most ${rentalPercent(limit!)}.';
                      }
                      return null;
                    },
                  ),
                ),
                IconButton(
                  key: ValueKey('cancel-step-$i-remove'),
                  tooltip: 'Remove step',
                  onPressed: () => onRemove(i),
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
              ],
            ),
          ),
        if (!noLimit && rows.length < rentalMaxCancelSteps)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('cancel-step-add'),
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                rows.isEmpty ? 'Add a cancellation charge' : 'Add a step',
              ),
            ),
          ),
      ],
    );
  }
}

/// The one box for a per-rental-day charge: a percent for each day (hour, for an hourly item)
/// rented, never above the limit Zuno set for the kind of item — "1% a day: a 2-day order 2%".
class RentalCancelPerDayField extends StatelessWidget {
  const RentalCancelPerDayField({
    required this.controller,
    required this.unit,
    this.limit,
    this.limitName,
    super.key,
  });

  final TextEditingController controller;

  /// [RentalCancelUnit.day] or [RentalCancelUnit.hour].
  final String unit;

  /// The most percent allowed for the chosen category; null until one is chosen.
  final double? limit;
  final String? limitName;

  @override
  Widget build(BuildContext context) {
    final noun = unit == RentalCancelUnit.hour ? 'hour' : 'day';
    final cap = limit;
    return TextFormField(
      key: const ValueKey('cancel-per-day'),
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Charge for each rental $noun',
        suffixText: '%',
        helperText: cap == null
            ? 'Choose a category to see how much you may keep.'
            : 'e.g. 1: a 2-$noun order cancelled costs 2%. '
                  'Never above ${rentalPercent(cap)} for '
                  '${limitName ?? 'this kind of item'}.',
        helperMaxLines: 2,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final text = (value ?? '').trim();
        final parsed = double.tryParse(text);
        if (parsed == null) {
          return 'Enter the charge for each rental $noun, e.g. 1.';
        }
        if (parsed <= 0) return 'More than 0%.';
        if (RegExp(r'\.\d{3,}$').hasMatch(text)) return 'At most 2 decimals.';
        if (cap != null && parsed > cap + 0.0001) {
          return 'At most ${rentalPercent(cap)}.';
        }
        return null;
      },
    );
  }
}
