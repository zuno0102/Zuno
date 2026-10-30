import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_area_picker.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_form_message_banner.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_form_pickers.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_media_slots.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_questions_section.dart';
import 'package:zuno/features/rental/data/rental_api.dart';
import 'package:zuno/features/rental/domain/entities/rental_item.dart';
import 'package:zuno/features/rental/domain/entities/rental_payment.dart';
import 'package:zuno/features/rental/presentation/providers/rental_payment_providers.dart';
import 'package:zuno/features/rental/presentation/providers/rental_providers.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_price_type_picker.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/primary_button.dart';

/// Photo slots per rent item — the Rent server's `Rent:ImageSlots`.
const rentalImageSlots = 3;

/// Shows the add/edit sheet for a rent item. Pass [existing] to edit, omit it to add one.
Future<void> showRentalItemFormSheet(
  BuildContext context, {
  RentalItem? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => RentalItemFormSheet(existing: existing),
  );
}

/// "Rate per day (INR)" — the price box follows the chosen card's name from the rate table.
String rentalRateFieldLabel(RentalPriceTypeOption? option) =>
    option == null ? 'Rate (INR)' : 'Rate ${option.name.toLowerCase()} (INR)';

/// The rent item form: the same look and order as the service form — photos, category, area,
/// name, rate — plus how many the business has, whether it can be rented right now, and the
/// questions every customer renting it answers.
class RentalItemFormSheet extends ConsumerStatefulWidget {
  const RentalItemFormSheet({this.existing, super.key});

  final RentalItem? existing;

  @override
  ConsumerState<RentalItemFormSheet> createState() =>
      _RentalItemFormSheetState();
}

class _RentalItemFormSheetState extends ConsumerState<RentalItemFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.existing?.name,
  );
  late final _descriptionController = TextEditingController(
    text: widget.existing?.description,
  );
  late final _priceController = TextEditingController(
    text: _plainNumber(widget.existing?.price),
  );
  late final _quantityController = TextEditingController(
    text: (widget.existing?.quantityOwned ?? 1).toString(),
  );
  late final _advanceController = TextEditingController(
    text: _plainNumber(widget.existing?.advanceAmount),
  );

  /// No advance, a fixed one for the order, or one per piece — from the server's advance table.
  late String _advanceType =
      widget.existing?.advanceType ?? RentalAdvanceType.none;

  late String? _categoryId = widget.existing?.rentalCategoryId;
  late String? _subCategoryId = widget.existing?.rentalSubCategoryId;
  late String _priceType = widget.existing?.priceType ?? RentalPriceType.daily;
  late bool _isAvailable = widget.existing?.isAvailable ?? true;
  late Set<String> _stateIds = {
    for (final d in widget.existing?.districts ?? const <RentalItemDistrict>[])
      d.stateId,
  };
  late Set<String> _districtIds = {
    for (final d in widget.existing?.districts ?? const <RentalItemDistrict>[])
      d.id,
  };

  /// The questions, each holding its own text box; saved ones keep their id so answers stay linked.
  late final List<ServiceQuestionRow> _questions = [
    for (final q in widget.existing?.questions ?? const <RentalItemQuestion>[])
      ServiceQuestionRow(id: q.id, prompt: q.prompt, isRequired: q.isRequired),
  ];

  /// Picked and removed photos and video, uploaded once the item itself is saved.
  late final _media = ServiceMediaSelection(
    slotCount: rentalImageSlots,
    savedImageUrl: widget.existing?.imageUrlForSlot,
    savedVideoUrl: widget.existing?.video?.url,
  );

  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  static String _plainNumber(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _advanceController.dispose();
    for (final row in _questions) {
      row.dispose();
    }
    _media.dispose();
    super.dispose();
  }

  RentalItemInput _input() => RentalItemInput(
    rentalCategoryId: _categoryId!,
    rentalSubCategoryId: _subCategoryId,
    name: _nameController.text.trim(),
    description: _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim(),
    priceType: _priceType,
    price: double.parse(_priceController.text.trim()),
    quantityOwned: int.parse(_quantityController.text.trim()),
    isAvailable: _isAvailable,
    districtIds: _districtIds.toList(),
    questions: [for (final row in _questions) row.toPayload()],
    advanceType: _advanceType,
    advanceAmount: _advanceType == RentalAdvanceType.none
        ? null
        : double.tryParse(_advanceController.text.trim()),
  );

  /// Whether anything on the item itself differs from what is saved; media is checked apart.
  bool _fieldsChanged(RentalItem existing, RentalItemInput input) =>
      existing.rentalCategoryId != input.rentalCategoryId ||
      existing.rentalSubCategoryId != input.rentalSubCategoryId ||
      existing.name != input.name ||
      existing.description != input.description ||
      existing.priceType != input.priceType ||
      existing.price != input.price ||
      existing.quantityOwned != input.quantityOwned ||
      existing.isAvailable != input.isAvailable ||
      existing.advanceType != input.advanceType ||
      existing.advanceAmount != input.advanceAmount ||
      !const SetEquality<String>().equals(
        existing.districts.map((d) => d.id).toSet(),
        input.districtIds.toSet(),
      ) ||
      !const DeepCollectionEquality().equals([
        for (final q in existing.questions)
          {'id': q.id, 'prompt': q.prompt, 'isRequired': q.isRequired},
      ], input.questions);

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final fieldsValid = _formKey.currentState!.validate();
    final problem = _categoryId == null
        ? 'Select a category.'
        : _districtIds.isEmpty
        ? 'Select at least one district where this item can be rented.'
        : null;
    if (!fieldsValid || problem != null) {
      setState(() => _errorMessage = problem);
      return;
    }

    final existing = widget.existing;
    final input = _input();
    final fieldsChanged = existing == null || _fieldsChanged(existing, input);

    // Nothing changed: close without a call or a "saved" message.
    if (!fieldsChanged && !_media.hasChanges) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final repository = ref.read(rentalRepositoryProvider);
    try {
      // The item first: a new one has no id to upload its photos against until it exists.
      final id = existing == null
          ? (await repository.create(input)).id
          : fieldsChanged
          ? (await repository.update(existing.id, input)).id
          : existing.id;

      for (var slot = 0; slot < _media.slotCount; slot++) {
        final bytes = _media.pickedImage(slot);
        if (bytes != null) {
          await repository.uploadImage(id, slot, bytes);
        } else if (_media.isImageRemoved(slot)) {
          await repository.removeImage(id, slot);
        }
      }
      if (_media.pickedVideo case final video?) {
        await repository.uploadVideo(id, video, _media.pickedVideoMimeSubtype!);
      } else if (_media.isVideoRemoved) {
        await repository.removeVideo(id);
      }

      reloadRentals(ref);
      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _successMessage = existing == null
            ? 'Rent item added.'
            : 'Rent item updated.';
      });
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickCategory(List<RentalCategory> categories) async {
    final picked = await _pickFromList(
      title: 'Category',
      options: [for (final c in categories) (c.id, c.name)],
      selectedId: _categoryId,
    );
    if (picked == null) return;
    setState(() {
      // A sub-category belongs to one category, so it cannot survive a change of category.
      if (picked != _categoryId) _subCategoryId = null;
      _categoryId = picked;
    });
  }

  Future<void> _pickSubCategory(List<RentalSubCategory> options) async {
    final picked = await _pickFromList(
      title: 'Sub-category',
      options: [
        (anySubCategory, 'Any in this category'),
        for (final s in options) (s.id, s.name),
      ],
      selectedId: _subCategoryId ?? anySubCategory,
    );
    if (picked == null) return;
    setState(() => _subCategoryId = picked == anySubCategory ? null : picked);
  }

  Future<String?> _pickFromList({
    required String title,
    required List<(String, String)> options,
    required String? selectedId,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final (id, name) in options)
                      ListTile(
                        title: Text(name),
                        trailing: id == selectedId
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () => Navigator.of(context).pop(id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  String? _areaSummary() {
    if (_districtIds.isEmpty) return null;
    return '${_stateIds.length} state${_stateIds.length == 1 ? '' : 's'} • '
        '${_districtIds.length} district${_districtIds.length == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(rentalCategoriesProvider);
    final priceTypesAsync = ref.watch(rentalPriceTypesProvider);
    final chosenPriceType = priceTypesAsync.value?.firstWhereOrNull(
      (o) => o.code == _priceType,
    );
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
                    isEditing ? 'Edit rent item' : 'Add rent item',
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
                    mediaBaseUrl: RentApi.baseUrl,
                    onError: (message) =>
                        setState(() => _errorMessage = message),
                  ),
                  const SizedBox(height: 16),
                  categoriesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => ErrorBanner(
                      message: 'Failed to load categories: $error',
                    ),
                    data: (categories) {
                      final category = categories.firstWhereOrNull(
                        (c) => c.id == _categoryId,
                      );
                      final subs =
                          category?.subCategories ??
                          const <RentalSubCategory>[];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ServicePickerField(
                            label: 'Category',
                            value: category?.name,
                            placeholder: 'Select a category',
                            onTap: () => _pickCategory(categories),
                          ),
                          if (subs.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            ServicePickerField(
                              label: 'Sub-category',
                              helperText: 'Optional — narrows the category',
                              value: subs
                                  .firstWhereOrNull(
                                    (s) => s.id == _subCategoryId,
                                  )
                                  ?.name,
                              placeholder: 'Any in this category',
                              onTap: () => _pickSubCategory(subs),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  ServicePickerField(
                    label: 'Service area',
                    value: _areaSummary(),
                    placeholder: 'Select service area',
                    onTap: _openServiceAreaPicker,
                    ellipsize: true,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _nameController,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Item name',
                      hintText: 'e.g. Plastic chair, Cutting machine',
                      border: OutlineInputBorder(),
                      counterText: '',
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
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 14),
                  priceTypesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => ErrorBanner(
                      message: 'Failed to load the ways of charging: $error',
                    ),
                    data: (options) => RentalPriceTypePicker(
                      options: options,
                      value: _priceType,
                      onChanged: (code) => setState(() => _priceType = code),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: rentalRateFieldLabel(chosenPriceType),
                            helperText: 'For one item',
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
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Quantity you have',
                            hintText: 'e.g. 1000',
                            helperText: 'How many you rent out',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final parsed = int.tryParse((value ?? '').trim());
                            return (parsed == null || parsed < 1)
                                ? 'At least 1.'
                                : null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // An advance once set is asked on every order: online in the app, cash or UPI
                  // offline.
                  switch (ref.watch(rentalPaymentOptionsProvider)) {
                    AsyncData(:final value) => RentalChoiceCards(
                      title: 'Advance before renting',
                      options: [
                        for (final o in value.advanceTypes)
                          (o.code, o.name, o.detail),
                      ],
                      value: _advanceType,
                      onChanged: (code) => setState(() => _advanceType = code),
                    ),
                    AsyncError(:final error) => ErrorBanner(
                      message: 'Failed to load the advance options: $error',
                    ),
                    _ => const LinearProgressIndicator(),
                  },
                  if (_advanceType != RentalAdvanceType.none) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('advance-amount'),
                      controller: _advanceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: _advanceType == RentalAdvanceType.perPiece
                            ? 'Advance for each piece'
                            : 'Advance for the order',
                        prefixText: '₹ ',
                        helperText: _advanceType == RentalAdvanceType.perPiece
                            ? 'e.g. 2 — 300 chairs ask ₹600'
                            : 'e.g. 500, however many pieces',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final parsed = double.tryParse((value ?? '').trim());
                        return (parsed == null || parsed <= 0)
                            ? 'Enter the advance, or choose no advance.'
                            : null;
                      },
                    ),
                  ],
                  const SizedBox(height: 4),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Available now',
                      style: TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      'Turn off while it cannot be rented, e.g. under repair.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    value: _isAvailable,
                    onChanged: (value) => setState(() => _isAvailable = value),
                  ),
                  const SizedBox(height: 16),
                  ServiceQuestionsSection(
                    rows: _questions,
                    emptyHint:
                        'Add a box for anything you need to know before you rent '
                        'this out, e.g. event date and venue.',
                    filledHint:
                        'Every customer renting this item answers these.',
                    onAdd: () =>
                        setState(() => _questions.add(ServiceQuestionRow())),
                    onRemove: (index) =>
                        setState(() => _questions.removeAt(index).dispose()),
                    onToggleRequired: (index) => setState(
                      () => _questions[index].isRequired =
                          !_questions[index].isRequired,
                    ),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: isEditing ? 'Save changes' : 'Add rent item',
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
              color: Theme.of(context).colorScheme.primary,
              onColor: Theme.of(context).colorScheme.onPrimary,
              icon: Icons.check_circle,
            ),
          ),
      ],
    );
  }
}
