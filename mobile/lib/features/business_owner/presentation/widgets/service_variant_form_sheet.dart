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
import 'package:zuno/features/business_owner/domain/entities/service_variant.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_services_notifier.dart';
import 'package:zuno/features/catalog/domain/entities/service_category.dart';
import 'package:zuno/features/catalog/domain/entities/service_sub_category.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
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

  final List<Uint8List?> _pickedImageBytes = [null, null, null];
  final Set<int> _removedExistingImageSlots = {};

  Uint8List? _pickedVideoBytes;
  String? _pickedVideoMimeSubtype;
  bool _removedExistingVideo = false;

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

  Future<void> _showSubCategoryPicker(
    List<ServiceSubCategory> options,
  ) async {
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
    super.dispose();
  }

  Future<void> _pickImage(int slot) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) {
      return;
    }

    try {
      final rawBytes = await picked.readAsBytes();

      // See the equivalent comment in business_service_form_sheet.dart: re-encoding to JPEG
      // handles HEIC/HEIF from the gallery, and bytes-in/bytes-out (not file paths) is what
      // makes this work identically on web too.
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

    final hasMediaChanges =
        _pickedImageBytes.any((bytes) => bytes != null) ||
        _removedExistingImageSlots.isNotEmpty ||
        _pickedVideoBytes != null ||
        _removedExistingVideo;

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

      for (var slot = 0; slot < _pickedImageBytes.length; slot++) {
        final bytes = _pickedImageBytes[slot];
        if (bytes != null) {
          await notifier.uploadServiceVariantImage(
            widget.serviceId,
            variantId,
            slot,
            bytes,
          );
        } else if (_removedExistingImageSlots.contains(slot)) {
          await notifier.removeServiceVariantImage(
            widget.serviceId,
            variantId,
            slot,
          );
        }
      }

      if (_pickedVideoBytes != null) {
        await notifier.uploadServiceVariantVideo(
          widget.serviceId,
          variantId,
          _pickedVideoBytes!,
          _pickedVideoMimeSubtype!,
        );
      } else if (_removedExistingVideo) {
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
                    segments: const [
                      ButtonSegment(value: 'Fixed', label: Text('Fixed price')),
                      ButtonSegment(
                        value: 'Hourly',
                        label: Text('Hourly rate'),
                      ),
                      ButtonSegment(value: 'Daily', label: Text('Daily rate')),
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
            child: _MessageBanner(
              message: _successMessage!,
              color: AppColors.primary,
              icon: Icons.check_circle,
            ),
          ),
      ],
    );
  }
}

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
