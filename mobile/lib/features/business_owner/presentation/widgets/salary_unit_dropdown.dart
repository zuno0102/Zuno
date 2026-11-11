import 'package:flutter/material.dart';
import 'package:zuno/core/ui_config/ui_config.dart';
import 'package:zuno/shared/widgets/select_field.dart';

/// The "Per" picker beside a wage: Event, Day or Hour, read from the `SalaryUnit` labels.
///
/// One widget for the hiring post and the assign-worker dialog, so the two can never offer
/// different units. A null [onChanged] shows it locked. Opens as a bottom sheet like every other
/// picker in the app, not a menu that spills over the fields beside it.
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

    return SelectField<String>(
      label: 'Per',
      initialValue: value,
      options: [
        for (final code in ui.codes('SalaryUnit'))
          SelectOption(code, ui.label('SalaryUnit', code)),
      ],
      onChanged: onChanged,
    );
  }
}
