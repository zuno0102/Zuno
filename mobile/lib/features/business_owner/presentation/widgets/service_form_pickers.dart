import 'package:flutter/material.dart';
import 'package:zuno/features/catalog/domain/entities/service_category.dart';
import 'package:zuno/features/catalog/domain/entities/service_sub_category.dart';

/// A form field that opens a picker rather than taking typing: the label, what is chosen (or a
/// muted [placeholder] while nothing is), and a drop-down arrow.
///
/// Drawn as an [InputDecorator] so it lines up with the text boxes around it on the service form.
class ServicePickerField extends StatelessWidget {
  const ServicePickerField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.helperText,
    this.ellipsize = false,
    super.key,
  });

  final String label;

  /// What is chosen, or null to show [placeholder].
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final String? helperText;

  /// Lets a long value shorten with an ellipsis instead of running off the edge — a service area
  /// summary ("3 districts in Kerala, 2 in …") can, a category name does not.
  final bool ellipsize;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      value ?? placeholder,
      overflow: ellipsize ? TextOverflow.ellipsis : null,
      style: value == null
          ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
          : null,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          border: const OutlineInputBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (ellipsize) Expanded(child: text) else text,
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

/// Opens category selection as its own bottom sheet with a plain, scrollable [ListView]
/// rather than a [DropdownButtonFormField]: that widget's popup menu positions itself
/// relative to the whole screen, not the modal bottom sheet's visible bounds, so inside a
/// sheet like the service form its menu renders overlapping the rest of the form instead of
/// neatly under the field.
///
/// Resolves to the chosen category's id, or null if the sheet was dismissed.
Future<String?> showServiceCategoryPicker(
  BuildContext context, {
  required List<ServiceCategory> categories,
  required String? selectedId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: categories
            .map(
              (category) => ListTile(
                title: Text(category.name),
                trailing: category.id == selectedId
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(category.id),
              ),
            )
            .toList(),
      ),
    ),
  );
}

/// What [showServiceSubCategoryPicker] resolves to when "Any in this category" is chosen.
///
/// A sentinel, since popping null only means the sheet was dismissed.
const anySubCategory = '__clear__';

/// The trades under a category, with "Any in this category" first.
///
/// Resolves to the chosen trade's id, [anySubCategory] for the "any" row, or null if the sheet
/// was dismissed.
Future<String?> showServiceSubCategoryPicker(
  BuildContext context, {
  required List<ServiceSubCategory> options,
  required String? selectedId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          // A way back out. The trade is optional, and without this a business that picked
          // one by mistake could only change it, never undo it.
          ListTile(
            title: const Text('Any in this category'),
            trailing: selectedId == null
                ? Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            onTap: () => Navigator.of(context).pop(anySubCategory),
          ),
          ...options.map(
            (option) => ListTile(
              title: Text(option.name),
              trailing: option.id == selectedId
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () => Navigator.of(context).pop(option.id),
            ),
          ),
        ],
      ),
    ),
  );
}
