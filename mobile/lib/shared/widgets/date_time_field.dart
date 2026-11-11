import 'package:flutter/material.dart';
import 'package:zuno/core/utils/formatting.dart';

/// A form field for a date, or a date and a time, that looks like the text boxes beside it —
/// label, the chosen value, a calendar mark — and opens the system pickers on tap.
///
/// With [withTime] false only a day is asked, and the value keeps the time of day it had (or
/// midnight): a run of dates for an advert, not an hour.
class DateTimeField extends FormField<DateTime> {
  DateTimeField({
    required String label,
    required ValueChanged<DateTime> onChanged,
    required DateTime firstDate,
    required DateTime lastDate,
    super.initialValue,
    super.validator,
    bool withTime = true,
    String? helperText,
    super.key,
  }) : super(
         builder: (field) {
           final context = field.context;
           final value = field.value;
           Future<void> open() async {
             FocusScope.of(context).unfocus();
             final start = value ?? DateTime.now();
             final day = await showDatePicker(
               context: context,
               firstDate: firstDate,
               lastDate: lastDate,
               initialDate: start.isBefore(firstDate)
                   ? firstDate
                   : start.isAfter(lastDate)
                   ? lastDate
                   : start,
               helpText: label,
             );
             if (day == null || !context.mounted) return;
             var picked = DateTime(
               day.year,
               day.month,
               day.day,
               start.hour,
               start.minute,
             );
             if (withTime) {
               final time = await showTimePicker(
                 context: context,
                 initialTime: TimeOfDay.fromDateTime(start),
                 helpText: label,
               );
               if (time == null) return;
               picked = DateTime(
                 day.year,
                 day.month,
                 day.day,
                 time.hour,
                 time.minute,
               );
             }
             field.didChange(picked);
             onChanged(picked);
           }

           return Semantics(
             button: true,
             label: label,
             value: value == null ? null : _text(value, withTime),
             child: InkWell(
               onTap: open,
               borderRadius: BorderRadius.circular(12),
               child: InputDecorator(
                 isEmpty: value == null,
                 decoration: InputDecoration(
                   labelText: label,
                   helperText: helperText,
                   errorText: field.errorText,
                   suffixIcon: const Icon(Icons.event_outlined),
                 ),
                 child: Text(
                   value == null ? '' : _text(value, withTime),
                   maxLines: 1,
                   overflow: TextOverflow.ellipsis,
                   style: Theme.of(context).textTheme.bodyLarge,
                 ),
               ),
             ),
           );
         },
       );

  static String _text(DateTime value, bool withTime) => withTime
      ? '${formatDate(value)}, ${formatTime(value)}'
      : formatDate(value);
}
