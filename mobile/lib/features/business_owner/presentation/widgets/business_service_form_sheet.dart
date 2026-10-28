import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/business_owner/domain/entities/business_service.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_services_notifier.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_area_picker.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_form_message_banner.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_form_pickers.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_media_slots.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_price_type_picker.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_questions_section.dart';
import 'package:zuno/features/catalog/domain/entities/service_category.dart';
import 'package:zuno/features/catalog/domain/entities/service_sub_category.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/primary_button.dart';

/// Shows the add/edit bottom sheet for a business service. Pass [existing] to edit,
/// omit it to create a new service.
Future<void> showBusinessServiceFormSheet(
  BuildContext context, {
  BusinessService? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _BusinessServiceFormSheet(existing: existing),
  );
}

class _BusinessServiceFormSheetState
    extends ConsumerState<_BusinessServiceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.existing?.name,
  );
  late final _itemNameController = TextEditingController(
    text: widget.existing?.itemName,
  );
  late final _descriptionController = TextEditingController(
    text: widget.existing?.description,
  );
  late final _priceController = TextEditingController(
    text: widget.existing?.price.toString(),
  );
  late final _durationController = TextEditingController(
    text: _initialDurationText(),
  );
  late final _requiredWorkerCountController = TextEditingController(
    text: (widget.existing?.requiredWorkerCount ?? 1).toString(),
  );

  String? _selectedCategoryId;

  /// The trade under that category, or null for "any in this category".
  String? _selectedSubCategoryId;

  String _priceType = 'Fixed';
  bool _isActive = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  Set<String> _stateIds = {};
  Set<String> _districtIds = {};

  /// The photos and video picked or removed on this form, uploaded once the service is saved.
  late final _media = ServiceMediaSelection(
    slotCount: ref.read(currentAppOptionsProvider).serviceImageSlots,
    savedImageUrl: widget.existing?.imageUrlForSlot,
    savedVideoUrl: widget.existing?.video?.url,
  );

  /// The boxes this service asks a customer, as the business is editing them.
  ///
  /// Each row keeps the id of the question it came from, so saving edits it in place rather than
  /// replacing it — which is what leaves answers customers already gave still pointing somewhere.
  /// A row the business just added has no id yet.
  late final List<ServiceQuestionRow> _questionRows = [
    for (final q in (widget.existing?.questions ?? const []))
      ServiceQuestionRow(id: q.id, prompt: q.prompt, isRequired: q.isRequired),
  ];

  // Per person is priced by headcount rather than time, so its duration stays in plain minutes
  // and is absent here on purpose — the `?? 1` below is the right answer for it.
  static const _durationUnitMultiplier = {
    PriceType.fixed: 1,
    PriceType.hourly: 60,
    PriceType.daily: 60 * 24,
  };

  /// Switching to or from a per-person price also settles the crew size.
  ///
  /// The two always move together: a per-person service carries 0, meaning "agreed with the
  /// customer for each order", and anything else needs a real number. Leaving the old value in
  /// the box would send a crew size the server then refuses.
  void _onPriceTypeChanged(String next) {
    setState(() {
      final wasPerPerson = isPerPersonPrice(_priceType);
      _priceType = next;

      if (isPerPersonPrice(next)) {
        _requiredWorkerCountController.text = '0';
      } else if (wasPerPerson) {
        // Coming back the other way, restore whatever this service had. 0 is a legal answer for
        // any price type — it means the crew is agreed per order — so it is left alone rather
        // than bumped to 1.
        _requiredWorkerCountController.text =
            (widget.existing?.requiredWorkerCount ?? 0).toString();
      }
    });
  }

  String _initialDurationText() {
    final minutes = widget.existing?.estimatedDurationMinutes;
    if (minutes == null) return '';
    final priceType = widget.existing?.priceType ?? 'Fixed';
    final multiplier = _durationUnitMultiplier[priceType] ?? 1;
    return (minutes / multiplier).round().toString();
  }

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.existing?.serviceCategoryId;
    _selectedSubCategoryId = widget.existing?.serviceSubCategoryId;
    _priceType = widget.existing?.priceType ?? 'Fixed';
    _isActive = widget.existing?.isActive ?? true;
    _stateIds = (widget.existing?.targetDistricts ?? [])
        .map((d) => d.stateId)
        .toSet();
    _districtIds = (widget.existing?.targetDistricts ?? [])
        .map((d) => d.id)
        .toSet();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _itemNameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    _requiredWorkerCountController.dispose();
    _media.dispose();
    for (final row in _questionRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addQuestionRow() =>
      setState(() => _questionRows.add(ServiceQuestionRow()));

  void _removeQuestionRow(int index) {
    setState(() {
      // Disposed as it leaves, not at the end: a controller for a row the business deleted has
      // nothing left to keep it alive.
      _questionRows.removeAt(index).dispose();
    });
  }

  void _toggleQuestionRequired(int index) => setState(
    () => _questionRows[index].isRequired = !_questionRows[index].isRequired,
  );

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _selectedCategoryId == null) {
      setState(
        () => _errorMessage = _selectedCategoryId == null
            ? 'Select a category.'
            : null,
      );
      return;
    }
    if (_districtIds.isEmpty) {
      setState(
        () => _errorMessage =
            'Select at least one district where this service is offered.',
      );
      return;
    }

    final existing = widget.existing;
    final name = _nameController.text.trim();
    final itemName = _itemNameController.text.trim().isEmpty
        ? null
        : _itemNameController.text.trim();
    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();
    final enteredDuration = int.tryParse(_durationController.text.trim());
    final duration = enteredDuration == null
        ? null
        : enteredDuration * (_durationUnitMultiplier[_priceType] ?? 1);
    final price = double.parse(_priceController.text.trim());
    // Read from the price type rather than the box: the box is not on screen for a per-person
    // service, so whatever it still holds is stale.
    final requiredWorkerCount = isPerPersonPrice(_priceType)
        ? 0
        : int.tryParse(_requiredWorkerCountController.text.trim()) ?? 1;
    final districtIds = _districtIds.toList();

    final hasMediaChanges = _media.hasChanges;

    // Questions are saved by their own call, so they need their own change check. Without it, a
    // business that edited nothing but the questions would hit the no-op branch below, close the
    // sheet, and lose every one of them.
    final existingQuestions = existing?.questions ?? const [];
    final hasQuestionChanges =
        _questionRows.length != existingQuestions.length ||
        _questionRows.indexed.any((entry) {
          final (index, row) = entry;
          final before = existingQuestions[index];
          return row.id != before.id ||
              row.prompt != before.prompt ||
              row.isRequired != before.isRequired;
        });

    // Only worth persisting/confirming if something actually differs from what's already
    // saved — a no-op save (user opens edit, changes nothing, taps Save) shouldn't hit the
    // API or show a success message.
    final hasFieldChanges =
        existing == null ||
        existing.serviceCategoryId != _selectedCategoryId ||
        existing.serviceSubCategoryId != _selectedSubCategoryId ||
        existing.name != name ||
        existing.itemName != itemName ||
        existing.description != description ||
        existing.priceType != _priceType ||
        existing.price != price ||
        existing.estimatedDurationMinutes != duration ||
        existing.requiredWorkerCount != requiredWorkerCount ||
        existing.isActive != _isActive ||
        !const SetEquality<String>().equals(
          existing.targetDistricts.map((d) => d.id).toSet(),
          _districtIds,
        );

    if (existing != null &&
        !hasFieldChanges &&
        !hasMediaChanges &&
        !hasQuestionChanges) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final notifier = ref.read(businessServicesProvider.notifier);

      String serviceId;
      if (existing == null) {
        final created = await notifier.addService(
          serviceCategoryId: _selectedCategoryId!,
          serviceSubCategoryId: _selectedSubCategoryId,
          name: name,
          itemName: itemName,
          description: description,
          priceType: _priceType,
          price: price,
          estimatedDurationMinutes: duration,
          requiredWorkerCount: requiredWorkerCount,
          districtIds: districtIds,
        );
        serviceId = created.id;
      } else {
        serviceId = existing.id;
        if (hasFieldChanges) {
          await notifier.editService(
            id: existing.id,
            serviceCategoryId: _selectedCategoryId!,
            serviceSubCategoryId: _selectedSubCategoryId,
            name: name,
            itemName: itemName,
            description: description,
            priceType: _priceType,
            price: price,
            estimatedDurationMinutes: duration,
            requiredWorkerCount: requiredWorkerCount,
            isActive: _isActive,
            districtIds: districtIds,
          );
        }
      }

      // After the service exists, like the images: a question belongs to a service, and a new
      // service has no id until it has been created. For a brand-new service the flag is simply
      // "were any rows typed", so a service saved without questions makes no call at all.
      if (hasQuestionChanges) {
        await notifier.setServiceQuestions(serviceId, [
          for (final row in _questionRows) row.toPayload(),
        ]);
      }

      for (var slot = 0; slot < _media.slotCount; slot++) {
        final bytes = _media.pickedImage(slot);
        if (bytes != null) {
          await notifier.uploadServiceImage(serviceId, slot, bytes);
        } else if (_media.isImageRemoved(slot)) {
          await notifier.removeServiceImage(serviceId, slot);
        }
      }

      if (_media.pickedVideo case final video?) {
        await notifier.uploadServiceVideo(
          serviceId,
          video,
          _media.pickedVideoMimeSubtype!,
        );
      } else if (_media.isVideoRemoved) {
        await notifier.removeServiceVideo(serviceId);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
        _successMessage = existing == null
            ? 'Service added.'
            : 'Service updated.';
      });

      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showCategoryPicker(List<ServiceCategory> categories) async {
    final selected = await showServiceCategoryPicker(
      context,
      categories: categories,
      selectedId: _selectedCategoryId,
    );

    if (selected != null) {
      setState(() {
        // Clearing the trade with it. Every kind of work belongs to one category, so one chosen
        // under the old category would now claim this service does work it no longer offers —
        // "Plumbing · Bedroom cleaning". The server refuses that pair anyway; clearing it here
        // means the business re-picks from the new list instead of being told off on save.
        if (_selectedCategoryId != selected) {
          _selectedSubCategoryId = null;
        }
        _selectedCategoryId = selected;
      });
    }
  }

  /// The trades under the chosen category, and nothing else.
  List<ServiceSubCategory> _subCategoryOptions(
    List<ServiceCategory> categories,
  ) =>
      categories
          .firstWhereOrNull((c) => c.id == _selectedCategoryId)
          ?.subCategories ??
      const [];

  Future<void> _showSubCategoryPicker(List<ServiceSubCategory> options) async {
    final selected = await showServiceSubCategoryPicker(
      context,
      options: options,
      selectedId: _selectedSubCategoryId,
    );

    if (selected != null) {
      setState(
        () => _selectedSubCategoryId = selected == anySubCategory
            ? null
            : selected,
      );
    }
  }

  Future<void> _openServiceAreaPicker() async {
    final result = await showServiceAreaPicker(
      context,
      initialStateIds: _stateIds,
      initialDistrictIds: _districtIds,
    );
    if (result != null) {
      setState(() {
        _stateIds = result.stateIds;
        _districtIds = result.districtIds;
      });
    }
  }

  /// "2 states • 5 districts", or null while no district is chosen.
  String? _serviceAreaSummary() {
    if (_districtIds.isEmpty) return null;
    return '${_stateIds.length} state${_stateIds.length == 1 ? '' : 's'} • ${_districtIds.length} district${_districtIds.length == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(serviceCategoriesProvider);
    final isEditing = widget.existing != null;

    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditing ? 'Edit service' : 'Add service',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_errorMessage != null) ...[
                    ServiceFormMessageBanner(
                      message: _errorMessage!,
                      color: AppColors.error,
                      onColor: Theme.of(context).colorScheme.onError,
                      icon: Icons.error_outline,
                    ),
                    const SizedBox(height: 16),
                  ],
                  ServiceMediaSlots(
                    media: _media,
                    onError: (message) =>
                        setState(() => _errorMessage = message),
                  ),
                  const SizedBox(height: 16),
                  categoriesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => ErrorBanner(
                      message: 'Failed to load categories: $error',
                    ),
                    data: (categories) => ServicePickerField(
                      label: 'Category',
                      value: categories
                          .where(
                            (category) => category.id == _selectedCategoryId,
                          )
                          .map((category) => category.name)
                          .firstOrNull,
                      placeholder: 'Select a category',
                      onTap: () => _showCategoryPicker(categories),
                    ),
                  ),
                  // Only once a category is chosen, because its whole content comes from that
                  // choice. Shown before one is made it would be an empty field asking a
                  // question it cannot yet offer any answers to.
                  if (_selectedCategoryId != null) ...[
                    const SizedBox(height: 14),
                    categoriesAsync.maybeWhen(
                      data: (categories) {
                        final options = _subCategoryOptions(categories);
                        if (options.isEmpty) return const SizedBox.shrink();

                        return ServicePickerField(
                          label: 'Kind of work',
                          helperText: 'Optional — narrows the category',
                          value: options
                              .where((sub) => sub.id == _selectedSubCategoryId)
                              .map((sub) => sub.name)
                              .firstOrNull,
                          placeholder: 'Any in this category',
                          onTap: () => _showSubCategoryPicker(options),
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                  const SizedBox(height: 14),
                  // Ellipsized, so a long summary truncates instead of running off the edge.
                  // Without it the row overflows on a narrow phone.
                  ServicePickerField(
                    label: 'Service area',
                    value: _serviceAreaSummary(),
                    placeholder: 'Select service area',
                    onTap: _openServiceAreaPicker,
                    ellipsize: true,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Service name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Name is required.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _itemNameController,
                    decoration: const InputDecoration(
                      labelText: 'Item name',
                      hintText: 'e.g. Stick Wall Painting / Red Theme Painting',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ServicePriceTypePicker(
                    value: _priceType,
                    onChanged: _onPriceTypeChanged,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: rateFieldLabel(_priceType),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final parsed = double.tryParse(
                              (value ?? '').trim(),
                            );
                            return (parsed == null || parsed <= 0)
                                ? 'Enter a valid price.'
                                : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _durationController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: durationFieldLabel(_priceType),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (isPerPersonPrice(_priceType))
                    const PerPersonCrewNotice()
                  else
                    TextFormField(
                      controller: _requiredWorkerCountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Workers required per order',
                        border: OutlineInputBorder(),
                        helperText:
                            'Use 0 if it depends on the event — you agree the '
                            'crew with the customer before confirming.',
                        helperMaxLines: 2,
                      ),
                      // Zero is a real answer, not a missing one. A business that cannot know the
                      // crew until it hears what the event is should be able to say so, and then
                      // settle the number with the customer before the order is confirmed.
                      validator: (value) {
                        final parsed = int.tryParse((value ?? '').trim());
                        if (parsed == null) return 'Enter a number, or 0.';
                        return parsed < 0 ? 'This cannot be negative.' : null;
                      },
                    ),
                  const SizedBox(height: 18),
                  ServiceQuestionsSection(
                    rows: _questionRows,
                    onAdd: _addQuestionRow,
                    onRemove: _removeQuestionRow,
                    onToggleRequired: _toggleQuestionRequired,
                  ),
                  if (isEditing) ...[
                    const SizedBox(height: 4),
                    SwitchListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Active',
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        'Inactive services are hidden from customers.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      value: _isActive,
                      onChanged: (value) => setState(() => _isActive = value),
                    ),
                  ],
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: isEditing ? 'Save changes' : 'Add service',
                    onPressed: _submit,
                    isLoading: _isSaving,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
        if (_successMessage != null)
          Positioned(
            top: 12,
            right: 20,
            child: ServiceFormMessageBanner(
              message: _successMessage!,
              // Read from the theme, not from AppColors: the scheme is seeded per role, so a
              // constant here came out indigo on a business screen that is purple throughout.
              color: Theme.of(context).colorScheme.primary,
              onColor: Theme.of(context).colorScheme.onPrimary,
              icon: Icons.check_circle,
            ),
          ),
      ],
    );
  }
}

class _BusinessServiceFormSheet extends ConsumerStatefulWidget {
  const _BusinessServiceFormSheet({this.existing});

  final BusinessService? existing;

  @override
  ConsumerState<_BusinessServiceFormSheet> createState() =>
      _BusinessServiceFormSheetState();
}
