import 'package:flutter/material.dart';
import 'package:zuno/core/ui_config/ui_config.dart';

/// The "Per" picker beside a wage: Event, Day or Hour, read from the `SalaryUnit` labels.
///
/// One widget for the hiring post and the assign-worker dialog, so the two can never offer
/// different units. A null [onChanged] shows it locked.
class SalaryUnitDropdown extends StatelessWidget {
  const SalaryUnitDropdown({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String value;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = UiConfig.current;
    final change = onChanged;

    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'Per',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final code in ui.codes('SalaryUnit'))
          DropdownMenuItem(
            value: code,
            child: Text(ui.label('SalaryUnit', code)),
          ),
      ],
      onChanged: change == null
          ? null
          : (selected) => change(selected ?? value),
    );
  }
}
