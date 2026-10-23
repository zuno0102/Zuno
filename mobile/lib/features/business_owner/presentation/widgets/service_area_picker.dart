import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/catalog/domain/entities/district.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zuno/shared/widgets/error_banner.dart';

class ServiceAreaSelection {
  const ServiceAreaSelection({
    required this.stateIds,
    required this.districtIds,
  });

  final Set<String> stateIds;
  final Set<String> districtIds;
}

/// Lets a business owner pick which India states and districts a service is offered in.
/// Both lists live in one sheet (no modal-over-modal): states first, then districts
/// filtered live to whichever states are currently checked.
Future<ServiceAreaSelection?> showServiceAreaPicker(
  BuildContext context, {
  required Set<String> initialStateIds,
  required Set<String> initialDistrictIds,
}) {
  return showModalBottomSheet<ServiceAreaSelection>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ServiceAreaPickerSheet(
      initialStateIds: initialStateIds,
      initialDistrictIds: initialDistrictIds,
    ),
  );
}

class _ServiceAreaPickerSheet extends ConsumerStatefulWidget {
  const _ServiceAreaPickerSheet({
    required this.initialStateIds,
    required this.initialDistrictIds,
  });

  final Set<String> initialStateIds;
  final Set<String> initialDistrictIds;

  @override
  ConsumerState<_ServiceAreaPickerSheet> createState() =>
      _ServiceAreaPickerSheetState();
}

class _ServiceAreaPickerSheetState
    extends ConsumerState<_ServiceAreaPickerSheet> {
  late final Set<String> _stateIds = {...widget.initialStateIds};
  late final Set<String> _districtIds = {...widget.initialDistrictIds};

  /// Accumulated district -> state mapping as district lists load, so unchecking a state
  /// can drop its (now hidden) districts from the selection instead of leaving orphans.
  final Map<String, String> _districtStateMap = {};

  /// Whether the states list is open.
  ///
  /// Shut as soon as one is picked, which is what makes the districts reachable. Both lists
  /// were open at once before, so choosing a state left its districts below three dozen state
  /// rows — far enough down that the sheet looked like it had done nothing.
  late bool _statesExpanded = widget.initialStateIds.isEmpty;

  final _searchController = TextEditingController();
  String _search = '';

  String get _stateIdsCsv => (_stateIds.toList()..sort()).join(',');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statesAsync = ref.watch(locationStatesProvider);
    final districtsAsync = _stateIds.isEmpty
        ? const AsyncValue<List<District>>.data([])
        : ref.watch(districtsForStatesProvider(_stateIdsCsv));

    ref.listen(districtsForStatesProvider(_stateIdsCsv), (previous, next) {
      next.whenData((districts) {
        for (final district in districts) {
          _districtStateMap[district.id] = district.stateId;
        }
      });
    });

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.9,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Service area',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Step 1. A header that is also the way back in, so the states can be
                    // changed later without the list sitting in front of the districts the
                    // whole time.
                    statesAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(),
                      ),
                      error: (error, _) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: ErrorBanner(
                          message: 'Failed to load states: $error',
                        ),
                      ),
                      data: (states) {
                        final chosen = states
                            .where((s) => _stateIds.contains(s.id))
                            .toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () => setState(
                                () => _statesExpanded = !_statesExpanded,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        chosen.isEmpty
                                            ? '1. Choose states'
                                            : '1. States · ${chosen.length} chosen',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ),
                                    Icon(
                                      _statesExpanded
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (!_statesExpanded && chosen.isNotEmpty)
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: chosen
                                    .map(
                                      (state) => Chip(
                                        label: Text(state.name),
                                        onDeleted: () => setState(() {
                                          _stateIds.remove(state.id);
                                          _districtIds.removeWhere(
                                            (id) =>
                                                _districtStateMap[id] ==
                                                state.id,
                                          );
                                          if (_stateIds.isEmpty) {
                                            _statesExpanded = true;
                                          }
                                        }),
                                      ),
                                    )
                                    .toList(),
                              ),
                            if (_statesExpanded)
                              ...states.map(
                                (state) => CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(state.name),
                                  value: _stateIds.contains(state.id),
                                  onChanged: (checked) => setState(() {
                                    if (checked ?? false) {
                                      _stateIds.add(state.id);
                                      // Straight on to the districts, which is what the
                                      // business opened this sheet to choose.
                                      _statesExpanded = false;
                                    } else {
                                      _stateIds.remove(state.id);
                                      _districtIds.removeWhere(
                                        (id) =>
                                            _districtStateMap[id] == state.id,
                                      );
                                    }
                                  }),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const Divider(height: 24),
                    Text(
                      '2. Choose districts',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_stateIds.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Choose a state first.'),
                      )
                    else
                      districtsAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: LinearProgressIndicator(),
                        ),
                        error: (error, _) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: ErrorBanner(
                            message: 'Failed to load districts: $error',
                          ),
                        ),
                        data: (districts) =>
                            _districtList(context, districts),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      ServiceAreaSelection(
                        stateIds: _stateIds,
                        districtIds: _districtIds,
                      ),
                    ),
                    // Says what is about to be saved. Done used to be a bare word on a sheet
                    // scrolled far from the ticks, with no way to tell a finished selection
                    // from an accidental one without scrolling back up.
                    child: Text(
                      _districtIds.isEmpty
                          ? 'Done'
                          : 'Done · ${_districtIds.length} '
                                '${_districtIds.length == 1 ? 'district' : 'districts'}',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The districts of the chosen states, grouped under each state, with a search box.
  ///
  /// A flat list was workable for one state and not for three: a business covering Kerala,
  /// Karnataka and Tamil Nadu had to read a couple of hundred names with the state in brackets
  /// after each. Grouped, the state is said once as a heading, and "All" takes a whole state in
  /// one tap — which is what a business working across a whole state actually wants.
  Widget _districtList(BuildContext context, List<District> districts) {
    final theme = Theme.of(context);
    final needle = _search.trim().toLowerCase();

    final byState = <String, List<District>>{};
    for (final district in districts) {
      if (needle.isNotEmpty && !district.name.toLowerCase().contains(needle)) {
        continue;
      }
      byState.putIfAbsent(district.stateName, () => []).add(district);
    }

    final stateNames = byState.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search districts',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _search.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _search = '');
                    },
                  ),
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _search = value),
        ),
        const SizedBox(height: 4),
        if (stateNames.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No district matches that search.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final stateName in stateNames) ...[
          Builder(
            builder: (context) {
              final inState = byState[stateName]!;
              final allChosen = inState.every(
                (d) => _districtIds.contains(d.id),
              );

              return Row(
                children: [
                  Expanded(
                    child: Text(
                      stateName,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  // Takes or drops only what the search is showing, so "All" never quietly
                  // selects districts the business cannot see on screen.
                  TextButton(
                    onPressed: () => setState(() {
                      if (allChosen) {
                        _districtIds.removeAll(inState.map((d) => d.id));
                      } else {
                        _districtIds.addAll(inState.map((d) => d.id));
                      }
                    }),
                    child: Text(allChosen ? 'Clear' : 'All'),
                  ),
                ],
              );
            },
          ),
          ...byState[stateName]!.map(
            (district) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(district.name),
              value: _districtIds.contains(district.id),
              onChanged: (checked) => setState(() {
                if (checked ?? false) {
                  _districtIds.add(district.id);
                } else {
                  _districtIds.remove(district.id);
                }
              }),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
