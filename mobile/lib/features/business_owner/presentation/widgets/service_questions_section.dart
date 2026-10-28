import 'package:flutter/material.dart';

/// One editable question row on the service form.
///
/// Holds its own controller so typing does not rebuild the whole sheet, and its [id] so a saved
/// question is edited in place rather than replaced — replacing it would orphan every answer
/// customers have already given to it.
class ServiceQuestionRow {
  ServiceQuestionRow({this.id, String prompt = '', this.isRequired = false})
    : controller = TextEditingController(text: prompt);

  /// Null for a row the business has just added.
  final String? id;
  final TextEditingController controller;
  bool isRequired;

  String get prompt => controller.text.trim();

  /// What the server is sent. No id at all for a new row, rather than a null one.
  Map<String, dynamic> toPayload() => {
    if (id != null) 'id': id,
    'prompt': prompt,
    'isRequired': isRequired,
  };

  void dispose() => controller.dispose();
}

/// The boxes this service asks a customer, and the ➕ that adds one.
///
/// Nothing here is fixed by the app: a caterer types "Enter your dishes count", a painter types
/// "Wall size details". The booking form then draws whatever is in this list, which is what
/// lets the business see the facts it needs before deciding how many people the job takes.
///
/// The form owns [rows] and changes them in its own state, so it knows what to save; this only
/// draws them and says which button was pressed.
class ServiceQuestionsSection extends StatelessWidget {
  const ServiceQuestionsSection({
    required this.rows,
    required this.onAdd,
    required this.onRemove,
    required this.onToggleRequired,
    super.key,
  });

  final List<ServiceQuestionRow> rows;
  final VoidCallback onAdd;

  /// With the index of the row.
  final ValueChanged<int> onRemove;

  /// With the index of the row.
  final ValueChanged<int> onToggleRequired;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'What should the customer tell you?',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 19),
              label: const Text('Add'),
            ),
          ],
        ),
        Text(
          rows.isEmpty
              ? 'Add a box for anything you need to know before you can staff the job.'
              : 'Every customer booking this service answers these.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),

        for (var index = 0; index < rows.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: rows[index].controller,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Question ${index + 1}',
                      hintText: 'e.g. Enter your dishes count',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Type the question, or remove this row.'
                        : null,
                  ),
                ),
                const SizedBox(width: 4),
                // Required is a toggle rather than a second field: it is one bit, and a checkbox
                // beside the box reads faster than a row of its own.
                Tooltip(
                  message: rows[index].isRequired
                      ? 'Must be answered'
                      : 'Optional',
                  child: IconButton(
                    icon: Icon(
                      rows[index].isRequired
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: rows[index].isRequired
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                    onPressed: () => onToggleRequired(index),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: theme.colorScheme.outline,
                  ),
                  tooltip: 'Remove',
                  onPressed: () => onRemove(index),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
