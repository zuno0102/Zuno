import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/shared/widgets/select_field.dart';

/// The values the business has typed or picked for a category's own details, by field key.
///
/// Owned by the form, so a change of category can start it afresh and saving can read it.
class MarketplaceAttributeValues {
  MarketplaceAttributeValues([Map<String, String> saved = const {}])
    : _values = {...saved};

  final Map<String, String> _values;
  final Map<String, TextEditingController> _controllers = {};

  /// The text box for [key], made on first use with the saved value in it.
  TextEditingController controller(String key) => _controllers.putIfAbsent(
    key,
    () => TextEditingController(text: _values[key]),
  );

  String? selected(String key) => _values[key];

  void select(String key, String value) => _values[key] = value;

  /// Every filled detail of [fields], trimmed — what the server is sent.
  Map<String, String> valuesFor(List<MarketplaceCategoryField> fields) => {
    for (final f in fields)
      if ((f.fieldType == MarketplaceFieldType.select
              ? _values[f.key]
              : _controllers[f.key]?.text.trim())
          case final v? when v.isNotEmpty)
        f.key: v,
  };

  /// Forgets the values of [keys] — the details only an old sub-category asked for.
  void clearKeys(Iterable<String> keys) {
    for (final key in keys) {
      _values.remove(key);
      _controllers[key]?.clear();
    }
  }

  /// Starts again for another category: nothing typed for one fits the other.
  void clear() {
    _values.clear();
    for (final c in _controllers.values) {
      c.clear();
    }
  }

  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
  }
}

/// The details the chosen category asks for — "Model year", "KM driven", "Fuel" for a vehicle —
/// drawn from the category's rows, so a detail the super admin adds shows here without a release.
class MarketplaceCategoryFieldsSection extends StatelessWidget {
  const MarketplaceCategoryFieldsSection({
    required this.fields,
    required this.values,
    required this.onChanged,
    super.key,
  });

  final List<MarketplaceCategoryField> fields;
  final MarketplaceAttributeValues values;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final shown = fields.where((f) => f.isActive).toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final field in shown) ...[
          _field(field),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _field(MarketplaceCategoryField field) {
    final label = field.isRequired ? field.label : '${field.label} (optional)';
    if (field.fieldType == MarketplaceFieldType.select) {
      return SelectField<String>(
        key: ValueKey('marketplace-field-${field.key}'),
        label: label,
        options: [for (final o in field.options) SelectOption(o, o)],
        initialValue: values.selected(field.key),
        onChanged: (v) {
          values.select(field.key, v);
          onChanged();
        },
        validator: (v) =>
            field.isRequired && v == null ? 'Choose ${field.label}.' : null,
      );
    }

    final isNumber = field.fieldType == MarketplaceFieldType.number;
    return TextFormField(
      key: ValueKey('marketplace-field-${field.key}'),
      controller: values.controller(field.key),
      maxLength: 200,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: isNumber
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
          : null,
      decoration: InputDecoration(
        labelText: label,
        suffixText: field.unit,
        border: const OutlineInputBorder(),
        counterText: '',
      ),
      validator: (v) {
        final text = (v ?? '').trim();
        if (text.isEmpty) {
          return field.isRequired ? '${field.label} is required.' : null;
        }
        return isNumber && double.tryParse(text) == null
            ? '${field.label} must be a number.'
            : null;
      },
    );
  }
}
