import 'package:flutter/material.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_price_type_picker.dart';
import 'package:zuno/features/rental/domain/entities/rental_item.dart';

/// How the business charges for a rent item — the same radio cards as the service form, two to a
/// row, with the options and their wording from the Rent server's rate-type table.
class RentalPriceTypePicker extends StatelessWidget {
  const RentalPriceTypePicker({
    required this.options,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<RentalPriceTypeOption> options;

  /// The code currently chosen.
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => RentalChoiceCards(
    title: 'How do you charge?',
    options: [for (final o in options) (o.code, o.name, o.detail)],
    value: value,
    onChanged: onChanged,
  );
}

/// A titled set of radio cards, two to a row — the service form's cards, for any table-driven
/// choice on the rent forms: the rate, the advance.
class RentalChoiceCards extends StatelessWidget {
  const RentalChoiceCards({
    required this.title,
    required this.options,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String title;

  /// Code, name, and the line explaining it — in display order.
  final List<(String, String, String)> options;

  /// The code currently chosen.
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        for (var start = 0; start < options.length; start += 2) ...[
          if (start > 0) const SizedBox(height: 10),
          // IntrinsicHeight so both cards in a row match the taller one, as on the service form.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _tile(options[start])),
                const SizedBox(width: 10),
                // An odd last option keeps its half width rather than stretching across the row.
                Expanded(
                  child: start + 1 < options.length
                      ? _tile(options[start + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _tile((String, String, String) option) => PriceTypeTile(
    option: option,
    selected: value == option.$1,
    onTap: onChanged,
  );
}
