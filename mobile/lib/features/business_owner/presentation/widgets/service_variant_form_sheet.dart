import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/ui_config/ui_config.dart';
import 'package:zuno/features/business_owner/domain/entities/business_service.dart';
import 'package:zuno/features/business_owner/domain/entities/service_variant.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_services_notifier.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_form_message_banner.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_media_slots.dart';
import 'package:zuno/features/catalog/domain/entities/service_category.dart';
import 'package:zuno/features/catalog/domain/entities/service_sub_category.dart';
import 'package:zuno/shared/widgets/primary_button.dart';

/// Shows the add/edit bottom sheet for one sub-item ("variant") of a service — e.g. adding
/// "Chenda Melam" under a "Band Set" service. Pass [existing] to edit, omit it to create.
Future<void> showServiceVariantFormSheet(
  BuildContext context, {
  required String serviceId,
  ServiceVariant? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _ServiceVariantFormSheet(serviceId: serviceId, existing: existing),
  );
}

class _ServiceVariantFormSheet extends ConsumerStatefulWidget {
  const _ServiceVariantFormSheet({required this.serviceId, this.existing});

  final String serviceId;
  final ServiceVariant? existing;

  @override
  ConsumerState<_ServiceVariantFormSheet> createState() =>
      _ServiceVariantFormSheetState();
}

class _ServiceVariantFormSheetState
    extends ConsumerState<_ServiceVariantFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.existing?.name,
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

  String _priceType = 'Fixed';

  /// The kind of work this item is. The main category is never asked for here — it belongs to
  /// the parent service, and only that category's sub-categories are offered.
  String? _subCategoryId;

  /// Set when the item was submitted without a sub category. A picker is not a [TextFormField],
  /// so the form's own validator cannot speak for it.
  String? _subCategoryError;

  bool _isActive = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  /// The photos and video picked or removed on this form, uploaded once the item is saved.
  late final _media = ServiceMediaSelection(
    slotCount: ref.read(currentAppOptionsProvider).serviceImageSlots,
    savedImageUrl: widget.existing?.imageUrlForSlot,
    savedVideoUrl: widget.existing?.video?.url,
  );

  static const _durationUnitMultiplier = {
    'Fixed': 1,
    'Hourly': 60,
    'Daily': 60 * 24,
  };

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
    _priceType = widget.existing?.priceType ?? 'Fixed';
    _subCategoryId = widget.existing?.serviceSubCategoryId;
    _isActive = widget.existing?.isActive ?? true;
  }

  /// The sub-categories this item may be tagged with: the ones belonging to the parent
  /// service's category, and no others.
  List<ServiceSubCategory> _subCategoryOptions(
    List<BusinessService> services,
    List<ServiceCategory> categories,
  ) {
    final service = services.firstWhereOrNull((s) => s.id == widget.serviceId);
    if (service == null) return const [];

    return categories
            .firstWhereOrNull((c) => c.id == service.serviceCategoryId)
            ?.subCategories ??
        const [];
  }

  Future<void> _showSubCategoryPicker(List<ServiceSubCategory> options) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: options
              .map(
                (option) => ListTile(
                  title: Text(option.name),
                  trailing: option.id == _subCategoryId
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.of(context).pop(option.id),
                ),
              )
              .toList(),
        ),
      ),
    );

    if (selected != null) {
      setState(() {
        _subCategoryId = selected;
        _subCategoryError = null;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    _media.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final subCategoryOptions = _subCategoryOptions(
      ref.read(businessServicesProvider).value ?? const [],
      ref.read(serviceCategoriesProvider).value ?? const [],
    );
    // Only demanded when there is something to choose from — a category with no sub-categories
    // must not be able to block saving.
    final missingSubCategory =
        subCategoryOptions.isNotEmpty && _subCategoryId == null;
    setState(
      () => _subCategoryError = missingSubCategory
          ? 'Choose a sub category.'
          : null,
    );

    if (!_formKey.currentState!.validate() || missingSubCategory) {
      return;
    }

    final existing = widget.existing;
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();
    final enteredDuration = int.tryParse(_durationController.text.trim());
    final duration = enteredDuration == null
        ? null
        : enteredDuration * (_durationUnitMultiplier[_priceType] ?? 1);
    final price = double.parse(_priceController.text.trim());

    final hasMediaChanges = _media.hasChanges;

    final hasFieldChanges =
        existing == null ||
        existing.name != name ||
        existing.serviceSubCategoryId != _subCategoryId ||
        existing.description != description ||
        existing.priceType != _priceType ||
        existing.price != price ||
        existing.estimatedDurationMinutes != duration ||
        existing.isActive != _isActive;

    if (existing != null && !hasFieldChanges && !hasMediaChanges) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final notifier = ref.read(businessServicesProvider.notifier);

      String variantId;
      if (existing == null) {
        final created = await notifier.addServiceVariant(
          serviceId: widget.serviceId,
          name: name,
          serviceSubCategoryId: _subCategoryId,
          description: description,
          priceType: _priceType,
          price: price,
          estimatedDurationMinutes: duration,
        );
        variantId = created.variants.last.id;
      } else {
        variantId = existing.id;
        if (hasFieldChanges) {
          await notifier.editServiceVariant(
            serviceId: widget.serviceId,
            variantId: existing.id,
            name: name,
            serviceSubCategoryId: _subCategoryId,
            description: description,
            priceType: _priceType,
            price: price,
            estimatedDurationMinutes: duration,
            isActive: _isActive,
          );
        }
      }

      for (var slot = 0; slot < _media.slotCount; slot++) {
        final bytes = _media.pickedImage(slot);
        if (bytes != null) {
          await notifier.uploadServiceVariantImage(
            widget.serviceId,
            variantId,
            slot,
            bytes,
          );
        } else if (_media.isImageRemoved(slot)) {
          await notifier.removeServiceVariantImage(
            widget.serviceId,
            variantId,
            slot,
          );
        }
      }

      if (_media.pickedVideo case final video?) {
        await notifier.uploadServiceVariantVideo(
          widget.serviceId,
          variantId,
          video,
          _media.pickedVideoMimeSubtype!,
        );
      } else if (_media.isVideoRemoved) {
        await notifier.removeServiceVariantVideo(widget.serviceId, variantId);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
        _successMessage = existing == null ? 'Item added.' : 'Item updated.';
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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    // Both lists are already loaded by the screen behind this sheet, so this resolves without
    // a spinner in the common case. An empty result simply hides the field.
    final subCategoryOptions = _subCategoryOptions(
      ref.watch(businessServicesProvider).value ?? const [],
      ref.watch(serviceCategoriesProvider).value ?? const [],
    );
    final selectedSubCategoryName = subCategoryOptions
        .firstWhereOrNull((option) => option.id == _subCategoryId)
        ?.name;

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
                    isEditing ? 'Edit item' : 'Add item',
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
                  if (subCategoryOptions.isNotEmpty) ...[
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () => _showSubCategoryPicker(subCategoryOptions),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Sub category',
                          border: const OutlineInputBorder(),
                          errorText: _subCategoryError,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                selectedSubCategoryName ??
                                    'Select a sub category',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: selectedSubCategoryName == null
                                    ? TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      )
                                    : null,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Item name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Name is required.'
                        : null,
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
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: [
                      for (final code in UiConfig.current.codes(
                        'PriceType.VariantForm',
                      ))
                        ButtonSegment(
                          value: code,
                          label: Text(
                            UiConfig.current.label(
                              'PriceType.VariantForm',
                              code,
                            ),
                          ),
                        ),
                    ],
                    selected: {_priceType},
                    onSelectionChanged: (selection) =>
                        setState(() => _priceType = selection.first),
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
                        'Inactive items are hidden from customers.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      value: _isActive,
                      onChanged: (value) => setState(() => _isActive = value),
                    ),
                  ],
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: isEditing ? 'Save changes' : 'Add item',
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
