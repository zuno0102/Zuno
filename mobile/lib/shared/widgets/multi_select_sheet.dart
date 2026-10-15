import 'package:flutter/material.dart';

class MultiSelectOption {
  const MultiSelectOption({required this.id, required this.label});

  final String id;
  final String label;
}

/// Shows a searchable, checkbox-based multi-select bottom sheet and returns the selected
/// ids, or null if dismissed without confirming. Used anywhere a user picks several items
/// from a list (India states, districts, ...) — a single reusable pattern instead of a
/// bespoke picker per screen.
/// [clearLabel] adds a button that empties the selection and closes, for a filter somebody wants
/// gone rather than changed. Without it the only way out is to untick everything by hand, which on a
/// list of districts means hunting for the ones you ticked.
Future<Set<String>?> showMultiSelectSheet({
  required BuildContext context,
  required String title,
  required List<MultiSelectOption> options,
  required Set<String> initialSelectedIds,
  String? clearLabel,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _MultiSelectSheet(
      title: title,
      options: options,
      initialSelectedIds: initialSelectedIds,
      clearLabel: clearLabel,
    ),
  );
}

class _MultiSelectSheet extends StatefulWidget {
  const _MultiSelectSheet({
    required this.title,
    required this.options,
    required this.initialSelectedIds,
    this.clearLabel,
  });

  final String title;
  final List<MultiSelectOption> options;
  final Set<String> initialSelectedIds;
  final String? clearLabel;

  @override
  State<_MultiSelectSheet> createState() => _MultiSelectSheetState();
}

class _MultiSelectSheetState extends State<_MultiSelectSheet> {
  late final Set<String> _selectedIds = {...widget.initialSelectedIds};
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.options
        : widget.options
              .where(
                (o) => o.label.toLowerCase().contains(_query.toLowerCase()),
              )
              .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_selectedIds.isNotEmpty)
                      Text(
                        '${_selectedIds.length} selected',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    // Only once there is something to clear. A button that can never do anything is
                    // worse than no button.
                    if (widget.clearLabel case final label?
                        when _selectedIds.isNotEmpty)
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).pop(<String>{}),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(label),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No matches.'))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final option = filtered[index];
                          final selected = _selectedIds.contains(option.id);
                          return CheckboxListTile(
                            title: Text(option.label),
                            value: selected,
                            onChanged: (checked) => setState(() {
                              if (checked ?? false) {
                                _selectedIds.add(option.id);
                              } else {
                                _selectedIds.remove(option.id);
                              }
                            }),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selectedIds),
                    child: const Text('Done'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
