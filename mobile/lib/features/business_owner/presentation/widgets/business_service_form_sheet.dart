import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/business_owner/domain/entities/business_service.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_services_notifier.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_area_picker.dart';
import 'package:zuno/features/catalog/domain/entities/service_category.dart';
import 'package:zuno/features/catalog/domain/entities/service_sub_category.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/primary_button.dart';

const _maxVideoBytes = 25 * 1024 * 1024;

String _videoMimeSubtype(XFile file) {
  final mime = file.mimeType;
  if (mime != null && mime.startsWith('video/')) {
    return mime.substring('video/'.length);
  }
  final name = file.name.toLowerCase();
  if (name.endsWith('.mov')) return 'quicktime';
  if (name.endsWith('.webm')) return 'webm';
  return 'mp4';
}

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

  /// Sentinel for the "any" row, since popping null only means the sheet was dismissed.
  static const _clearSubCategory = '__clear__';
  String _priceType = 'Fixed';
  bool _isActive = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  Set<String> _stateIds = {};
  Set<String> _districtIds = {};

  final List<Uint8List?> _pickedImageBytes = [null, null, null];
  final Set<int> _removedExistingImageSlots = {};

  Uint8List? _pickedVideoBytes;
  String? _pickedVideoMimeSubtype;
  bool _removedExistingVideo = false;

  /// The boxes this service asks a customer, as the business is editing them.
  ///
  /// Each row keeps the id of the question it came from, so saving edits it in place rather than
  /// replacing it — which is what leaves answers customers already gave still pointing somewhere.
  /// A row the business just added has no id yet.
  late final List<_QuestionRow> _questionRows = [
    for (final q in (widget.existing?.questions ?? const []))
      _QuestionRow(id: q.id, prompt: q.prompt, isRequired: q.isRequired),
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
    for (final row in _questionRows) {
      row.dispose();
    }
    super.dispose();
  }

  /// How the business charges for this service.
  ///
  /// A 2×2 grid of labelled tiles rather than chips or a segmented button. Four options is one
  /// too many for a segmented row on a phone — the labels squeeze to nothing — and plain chips
  /// gave almost no contrast between chosen and not, with nothing on screen saying what the row
  /// was even for. Each tile carries a line explaining what it means, because "per person" is
  /// not self-evident until you have used it once.
  Widget _buildPriceTypePicker() {
    const options = [
      (PriceType.fixed, 'Fixed price', 'One price for the job'),
      (PriceType.hourly, 'Per hour', 'Charged by the hour'),
      (PriceType.daily, 'Per day', 'Charged by the day'),
      (PriceType.perPerson, 'Per person', 'Rate × the crew you agree'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How do you charge?',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        for (var row = 0; row < 2; row++) ...[
          // IntrinsicHeight, not CrossAxisAlignment.stretch. Stretch asks the children to fill
          // the cross axis, which inside a scrolling column is unbounded — "BoxConstraints
          // forces an infinite height", and the whole page fails to render rather than just
          // this row. IntrinsicHeight measures the taller tile and matches the other to it,
          // which is the equal-height result actually wanted.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var column = 0; column < 2; column++) ...[
                  if (column == 1) const SizedBox(width: 10),
                  Expanded(child: _priceTypeTile(options[row * 2 + column])),
                ],
              ],
            ),
          ),
          if (row == 0) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _priceTypeTile((String, String, String) option) {
    final theme = Theme.of(context);
    final (value, label, explanation) = option;
    final selected = _priceType == value;

    return InkWell(
      onTap: () => _onPriceTypeChanged(value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
        decoration: BoxDecoration(
          // Filled and outlined when chosen, so which one is picked reads at a glance rather
          // than from a shade of grey.
          color: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 17,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              explanation,
              style: theme.textTheme.bodySmall?.copyWith(
                color: selected
                    ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addQuestionRow() => setState(() => _questionRows.add(_QuestionRow()));

  /// The boxes this service asks a customer, and the ➕ that adds one.
  ///
  /// Nothing here is fixed by the app: a caterer types "Enter your dishes count", a painter types
  /// "Wall size details". The booking form then draws whatever is in this list, which is what
  /// lets the business see the facts it needs before deciding how many people the job takes.
  Widget _buildQuestionsSection() {
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
              onPressed: _addQuestionRow,
              icon: const Icon(Icons.add, size: 19),
              label: const Text('Add'),
            ),
          ],
        ),
        Text(
          _questionRows.isEmpty
              ? 'Add a box for anything you need to know before you can staff the job.'
              : 'Every customer booking this service answers these.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),

        for (var index = 0; index < _questionRows.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _questionRows[index].controller,
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
                  message: _questionRows[index].isRequired
                      ? 'Must be answered'
                      : 'Optional',
                  child: IconButton(
                    icon: Icon(
                      _questionRows[index].isRequired
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: _questionRows[index].isRequired
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                    onPressed: () => setState(
                      () => _questionRows[index].isRequired =
                          !_questionRows[index].isRequired,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: theme.colorScheme.outline,
                  ),
                  tooltip: 'Remove',
                  onPressed: () => _removeQuestionRow(index),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _removeQuestionRow(int index) {
    setState(() {
      // Disposed as it leaves, not at the end: a controller for a row the business deleted has
      // nothing left to keep it alive.
      _questionRows.removeAt(index).dispose();
    });
  }

  Future<void> _pickImage(int slot) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) {
      return;
    }

    try {
      final rawBytes = await picked.readAsBytes();

      // The gallery may hand back HEIC/HEIF (common on modern phone camera defaults), which
      // Flutter's image renderer cannot decode at all. Re-encoding to JPEG here — using the
      // platform's native decoder, which does understand HEIC — guarantees the bytes this app
      // uploads and later tries to display are always something it can actually render.
      //
      // Bytes in, bytes out (rather than file paths) is deliberate: image_picker returns a
      // blob URL on web, not a real filesystem path, so any path-based API (dart:io File,
      // compressAndGetFile) silently fails there. This works identically on every platform.
      final compressed = await FlutterImageCompress.compressWithList(
        rawBytes,
        format: CompressFormat.jpeg,
        quality: 85,
        minWidth: 1600,
        minHeight: 1600,
      );

      setState(() {
        _pickedImageBytes[slot] = compressed;
        _removedExistingImageSlots.remove(slot);
        _errorMessage = null;
      });
    } catch (e) {
      setState(
        () => _errorMessage =
            'Could not process the selected image. Please try a different photo.',
      );
    }
  }

  void _removeImage(int slot) {
    setState(() {
      _pickedImageBytes[slot] = null;
      if (widget.existing?.imageUrlForSlot(slot) != null) {
        _removedExistingImageSlots.add(slot);
      }
    });
  }

  Future<void> _handleImageSlotTap(int slot) async {
    final hasContent =
        _pickedImageBytes[slot] != null || _existingImageUrl(slot) != null;
    if (!hasContent) {
      await _pickImage(slot);
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Replace'),
              onTap: () => Navigator.of(context).pop('replace'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove'),
              onTap: () => Navigator.of(context).pop('remove'),
            ),
          ],
        ),
      ),
    );

    if (action == 'replace') {
      await _pickImage(slot);
    } else if (action == 'remove') {
      _removeImage(slot);
    }
  }

  String? _existingImageUrl(int slot) =>
      _removedExistingImageSlots.contains(slot)
      ? null
      : widget.existing?.imageUrlForSlot(slot);

  Future<void> _pickVideo() async {
    final picked = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 30),
    );
    if (picked == null) {
      return;
    }

    try {
      final bytes = await picked.readAsBytes();
      if (bytes.lengthInBytes > _maxVideoBytes) {
        setState(
          () => _errorMessage =
              'Video must be 30 seconds or shorter and under 25MB.',
        );
        return;
      }

      setState(() {
        _pickedVideoBytes = bytes;
        _pickedVideoMimeSubtype = _videoMimeSubtype(picked);
        _removedExistingVideo = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(
        () => _errorMessage =
            'Could not process the selected video. Please try a different clip.',
      );
    }
  }

  void _removeVideo() {
    setState(() {
      _pickedVideoBytes = null;
      _pickedVideoMimeSubtype = null;
      if (_existingVideoUrl != null) {
        _removedExistingVideo = true;
      }
    });
  }

  String? get _existingVideoUrl =>
      _removedExistingVideo ? null : widget.existing?.video?.url;

  Future<void> _handleVideoTap() async {
    final hasExisting = _existingVideoUrl != null;
    final hasPending = _pickedVideoBytes != null;

    if (!hasExisting && !hasPending) {
      await _pickVideo();
      return;
    }

    final options = <String, String>{
      if (hasExisting) 'preview': 'Preview',
      'replace': 'Replace',
      'remove': 'Remove',
    };

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.entries
              .map(
                (entry) => ListTile(
                  leading: Icon(switch (entry.key) {
                    'preview' => Icons.play_circle_outline,
                    'replace' => Icons.video_library_outlined,
                    _ => Icons.delete_outline,
                  }),
                  title: Text(entry.value),
                  onTap: () => Navigator.of(context).pop(entry.key),
                ),
              )
              .toList(),
        ),
      ),
    );

    if (action == 'preview' && _existingVideoUrl != null) {
      if (!mounted) return;
      await _showVideoPreview(
        context,
        '${ApiConstants.baseUrl}${_existingVideoUrl!}',
      );
    } else if (action == 'replace') {
      await _pickVideo();
    } else if (action == 'remove') {
      _removeVideo();
    }
  }

  Future<void> _showVideoPreview(BuildContext context, String url) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(child: _VideoPreviewPlayer(url: url)),
    );
  }

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

    final hasMediaChanges =
        _pickedImageBytes.any((bytes) => bytes != null) ||
        _removedExistingImageSlots.isNotEmpty ||
        _pickedVideoBytes != null ||
        _removedExistingVideo;

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
        await notifier.setServiceQuestions(
          serviceId,
          [for (final row in _questionRows) row.toPayload()],
        );
      }

      for (var slot = 0; slot < _pickedImageBytes.length; slot++) {
        final bytes = _pickedImageBytes[slot];
        if (bytes != null) {
          await notifier.uploadServiceImage(serviceId, slot, bytes);
        } else if (_removedExistingImageSlots.contains(slot)) {
          await notifier.removeServiceImage(serviceId, slot);
        }
      }

      if (_pickedVideoBytes != null) {
        await notifier.uploadServiceVideo(
          serviceId,
          _pickedVideoBytes!,
          _pickedVideoMimeSubtype!,
        );
      } else if (_removedExistingVideo) {
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

  /// Opens category selection as its own bottom sheet with a plain, scrollable [ListView]
  /// rather than a [DropdownButtonFormField]: that widget's popup menu positions itself
  /// relative to the whole screen, not the modal bottom sheet's visible bounds, so inside a
  /// sheet like this one its menu renders overlapping the rest of the form instead of neatly
  /// under the field.
  Future<void> _showCategoryPicker(List<ServiceCategory> categories) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: categories
              .map(
                (category) => ListTile(
                  title: Text(category.name),
                  trailing: category.id == _selectedCategoryId
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.of(context).pop(category.id),
                ),
              )
              .toList(),
        ),
      ),
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
  List<ServiceSubCategory> _subCategoryOptions(List<ServiceCategory> categories) =>
      categories
          .firstWhereOrNull((c) => c.id == _selectedCategoryId)
          ?.subCategories ??
      const [];

  Future<void> _showSubCategoryPicker(List<ServiceSubCategory> options) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            // A way back out. The trade is optional, and without this a business that picked
            // one by mistake could only change it, never undo it.
            ListTile(
              title: const Text('Any in this category'),
              trailing: _selectedSubCategoryId == null
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () => Navigator.of(context).pop(_clearSubCategory),
            ),
            ...options.map(
              (option) => ListTile(
                title: Text(option.name),
                trailing: option.id == _selectedSubCategoryId
                    ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(option.id),
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      setState(
        () => _selectedSubCategoryId = selected == _clearSubCategory
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

  Widget _buildImageSlot(int slot) {
    final pickedBytes = _pickedImageBytes[slot];
    final existingUrl = _existingImageUrl(slot);

    Widget child;
    if (pickedBytes != null) {
      child = Image.memory(
        pickedBytes,
        fit: BoxFit.cover,
        width: 88,
        height: 88,
      );
    } else if (existingUrl != null) {
      child = CachedNetworkImage(
        imageUrl: '${ApiConstants.baseUrl}$existingUrl',
        fit: BoxFit.cover,
        width: 88,
        height: 88,
        errorWidget: (context, url, error) =>
            const Icon(Icons.broken_image_outlined),
      );
    } else {
      child = Icon(
        Icons.add_a_photo_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
    }

    return GestureDetector(
      onTap: () => _handleImageSlotTap(slot),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 88,
          height: 88,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: child,
        ),
      ),
    );
  }

  Widget _buildVideoSlot() {
    final hasContent = _pickedVideoBytes != null || _existingVideoUrl != null;

    return GestureDetector(
      onTap: _handleVideoTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 88,
          height: 88,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            hasContent ? Icons.videocam : Icons.videocam_outlined,
            color: hasContent
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  String _serviceAreaSummary() {
    if (_districtIds.isEmpty) return 'Select service area';
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
                    _MessageBanner(
                      message: _errorMessage!,
                      color: AppColors.error,
                      icon: Icons.error_outline,
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Photos & video',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var slot = 0; slot < 3; slot++) ...[
                          _buildImageSlot(slot),
                          const SizedBox(width: 10),
                        ],
                        _buildVideoSlot(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Up to 3 photos and one video (30 seconds, 25MB max).',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  categoriesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => ErrorBanner(
                      message: 'Failed to load categories: $error',
                    ),
                    data: (categories) {
                      final selectedName = categories
                          .where(
                            (category) => category.id == _selectedCategoryId,
                          )
                          .map((category) => category.name)
                          .firstOrNull;

                      return InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () => _showCategoryPicker(categories),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                selectedName ?? 'Select a category',
                                style: selectedName == null
                                    ? TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      )
                                    : null,
                              ),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      );
                    },
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

                        final selectedName = options
                            .where((sub) => sub.id == _selectedSubCategoryId)
                            .map((sub) => sub.name)
                            .firstOrNull;

                        return InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () => _showSubCategoryPicker(options),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Kind of work',
                              helperText: 'Optional — narrows the category',
                              border: OutlineInputBorder(),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  selectedName ?? 'Any in this category',
                                  style: selectedName == null
                                      ? TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        )
                                      : null,
                                ),
                                const Icon(Icons.arrow_drop_down),
                              ],
                            ),
                          ),
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                  const SizedBox(height: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: _openServiceAreaPicker,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Service area',
                        border: OutlineInputBorder(),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Expanded, so a long summary ("3 districts in Kerala, 2 in …")
                          // truncates instead of running off the edge. Without it the row
                          // overflows on a narrow phone.
                          Expanded(
                            child: Text(
                              _serviceAreaSummary(),
                              overflow: TextOverflow.ellipsis,
                              style: _districtIds.isEmpty
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
                  _buildPriceTypePicker(),
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
                  // Priced per head, so the crew size is the thing being agreed rather than
                  // something the business fixes in advance. The field would only invite a number
                  // that the order then contradicts.
                  if (isPerPersonPrice(_priceType))
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Workers agreed per order',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            // No invented headcount here: an example number would read as a
                            // default, and the only figure worth showing is the one the business
                            // is actually typing above.
                            'You propose the number when the order comes in, and the price '
                            'follows it — the rate above for each person on the job.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    )
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
                  _buildQuestionsSection(),
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
            child: _MessageBanner(
              message: _successMessage!,
              // Read from the theme, not from AppColors: the scheme is seeded per role, so a
              // constant here came out indigo on a business screen that is purple throughout.
              color: Theme.of(context).colorScheme.primary,
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

/// A compact, rounded inline message — used both for the brief success confirmation
/// shown inside the form sheet itself (rather than a SnackBar on the underlying screen,
/// so feedback stays scoped to the component the user is looking at) and for validation
/// errors, so both share the same visual language instead of two different banner styles.
class _MessageBanner extends StatelessWidget {
  const _MessageBanner({
    required this.message,
    required this.color,
    required this.icon,
  });

  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPreviewPlayer extends StatefulWidget {
  const _VideoPreviewPlayer({required this.url});

  final String url;

  @override
  State<_VideoPreviewPlayer> createState() => _VideoPreviewPlayerState();
}

class _VideoPreviewPlayerState extends State<_VideoPreviewPlayer> {
  late final VideoPlayerController _controller =
      VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          if (mounted) setState(() {});
          _controller.play();
        });

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const SizedBox(
        width: 200,
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_controller),
          GestureDetector(
            onTap: () => setState(
              () => _controller.value.isPlaying
                  ? _controller.pause()
                  : _controller.play(),
            ),
            child: AnimatedOpacity(
              opacity: _controller.value.isPlaying ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.play_circle_fill,
                size: 56,
                color: AppColors.onMediaMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One editable question row on the service form.
///
/// Holds its own controller so typing does not rebuild the whole sheet, and its [id] so a saved
/// question is edited in place rather than replaced — replacing it would orphan every answer
/// customers have already given to it.
class _QuestionRow {
  _QuestionRow({this.id, String prompt = '', this.isRequired = false})
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
