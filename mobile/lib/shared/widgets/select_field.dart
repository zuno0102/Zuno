import 'package:flutter/material.dart';

/// One choice in a [SelectField].
class SelectOption<T> {
  const SelectOption(this.value, this.label, {this.detail});

  final T value;
  final String label;

  /// A short line under the label in the picker, e.g. what "Contract" means.
  final String? detail;
}

/// A form field for picking one of a few options, in place of [DropdownButtonFormField].
///
/// That widget's menu places itself against the whole screen, so inside a bottom sheet it spreads
/// edge to edge and covers the fields around it. This one looks like the text boxes beside it —
/// label, the chosen value, a chevron — and opens its options as a bottom sheet of their own, with
/// the chosen one ticked. It validates like any other form field.
class SelectField<T> extends FormField<T> {
  SelectField({
    required String label,
    required List<SelectOption<T>> options,
    required ValueChanged<T> onChanged,
    super.initialValue,
    super.validator,
    String placeholder = 'Choose',
    bool isDense = false,
    super.key,
  }) : super(
         builder: (field) {
           final context = field.context;
           final theme = Theme.of(context);
           final chosen = options
               .where((o) => o.value == field.value)
               .firstOrNull;

           Future<void> open() async {
             FocusScope.of(context).unfocus();
             final picked = await showSelectSheet<T>(
               context,
               title: label,
               options: options,
               selected: field.value,
             );
             if (picked == null) return;
             field.didChange(picked.value);
             onChanged(picked.value);
           }

           return Semantics(
             button: true,
             label: label,
             value: chosen?.label,
             child: InkWell(
               onTap: open,
               borderRadius: BorderRadius.circular(12),
               child: InputDecorator(
                 isEmpty: chosen == null,
                 decoration: InputDecoration(
                   labelText: label,
                   isDense: isDense,
                   errorText: field.errorText,
                   suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
                 ),
                 child: Text(
                   chosen?.label ?? placeholder,
                   maxLines: 1,
                   overflow: TextOverflow.ellipsis,
                   style: chosen == null
                       ? theme.textTheme.bodyLarge?.copyWith(
                           color: theme.colorScheme.onSurfaceVariant,
                         )
                       : theme.textTheme.bodyLarge,
                 ),
               ),
             ),
           );
         },
       );
}

/// The picked option, so a choice of `null` is told apart from closing the sheet.
class SelectPick<T> {
  const SelectPick(this.value);

  final T value;
}

/// Shows [options] as a bottom sheet titled [title], [selected] ticked. Resolves to the pick, or
/// null when the sheet is closed without one.
Future<SelectPick<T>?> showSelectSheet<T>(
  BuildContext context, {
  required String title,
  required List<SelectOption<T>> options,
  T? selected,
}) => showModalBottomSheet<SelectPick<T>>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (sheetContext) {
    final theme = Theme.of(sheetContext);
    final scheme = theme.colorScheme;
    return ConstrainedBox(
      // A long list scrolls inside the sheet; a short one sits snug at the bottom.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              children: [
                for (final o in options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      key: ValueKey('select-option-${o.value}'),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      selected: o.value == selected,
                      selectedTileColor: scheme.primaryContainer,
                      selectedColor: scheme.onPrimaryContainer,
                      title: Text(
                        o.label,
                        style: TextStyle(
                          fontWeight: o.value == selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      subtitle: o.detail == null ? null : Text(o.detail!),
                      trailing: o.value == selected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: scheme.primary,
                            )
                          : Icon(
                              Icons.circle_outlined,
                              color: scheme.outlineVariant,
                            ),
                      onTap: () =>
                          Navigator.of(sheetContext).pop(SelectPick(o.value)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  },
);
