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
///
/// [initialValue] is followed: when the screen changes it (linking an order fills in the unit), the
/// field shows the new value. A null [onChanged] shows the field locked.
class SelectField<T> extends FormField<T> {
  SelectField({
    required String label,
    required List<SelectOption<T>> options,
    required ValueChanged<T>? onChanged,
    super.initialValue,
    super.validator,
    String? helperText,
    bool isDense = false,
    super.key,
  }) : super(
         enabled: onChanged != null,
         builder: (field) {
           final context = field.context;
           final theme = Theme.of(context);
           final chosen = options
               .where((o) => o.value == field.value)
               .firstOrNull;

           final change = onChanged;

           Future<void> open() async {
             if (change == null) return;
             FocusScope.of(context).unfocus();
             final picked = await showSelectSheet<T>(
               context,
               title: label,
               options: options,
               selected: field.value,
             );
             if (picked == null) return;
             field.didChange(picked.value);
             change(picked.value);
           }

           return Semantics(
             button: true,
             enabled: change != null,
             label: label,
             value: chosen?.label,
             child: InkWell(
               onTap: change == null ? null : open,
               borderRadius: BorderRadius.circular(12),
               // Nothing chosen: the label alone sits in the box, as on an empty text field, and
               // moves up once a choice is made. A "Choose" placeholder drawn there as well landed
               // on top of the label — "Job type" and "Choose" printed over each other.
               child: InputDecorator(
                 isEmpty: chosen == null,
                 decoration: InputDecoration(
                   labelText: label,
                   helperText: helperText,
                   enabled: change != null,
                   isDense: isDense,
                   errorText: field.errorText,
                   suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
                 ),
                 child: Text(
                   chosen?.label ?? '',
                   maxLines: 1,
                   overflow: TextOverflow.ellipsis,
                   style: theme.textTheme.bodyLarge,
                 ),
               ),
             ),
           );
         },
       );

  @override
  FormFieldState<T> createState() => _SelectFieldState<T>();
}

class _SelectFieldState<T> extends FormFieldState<T> {
  @override
  void didUpdateWidget(covariant SelectField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The screen set a different value: show it, rather than the one picked before.
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != value) {
      setValue(widget.initialValue);
    }
  }
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
