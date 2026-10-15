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

  String get _stateIdsCsv => (_stateIds.toList()..sort()).join(',');

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
                    Text(
                      'States',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
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
                      data: (states) => Column(
                        children: states
                            .map(
                              (state) => CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(state.name),
                                value: _stateIds.contains(state.id),
                                onChanged: (checked) => setState(() {
                                  if (checked ?? false) {
                                    _stateIds.add(state.id);
                                  } else {
                                    _stateIds.remove(state.id);
                                    _districtIds.removeWhere(
                                      (id) => _districtStateMap[id] == state.id,
                                    );
                                  }
                                }),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const Divider(height: 24),
                    Text(
                      'Districts',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_stateIds.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Select at least one state first.'),
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
                        data: (districts) => Column(
                          children: districts
                              .map(
                                (district) => CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    '${district.name} (${district.stateName})',
                                  ),
                                  value: _districtIds.contains(district.id),
                                  onChanged: (checked) => setState(() {
                                    if (checked ?? false) {
                                      _districtIds.add(district.id);
                                    } else {
                                      _districtIds.remove(district.id);
                                    }
                                  }),
                                ),
                              )
                              .toList(),
                        ),
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
