import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/utils/upload_image.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zuno/shared/widgets/video_preview_player.dart';

/// The video's subtype for the upload — "mp4", "quicktime", "webm" — from the picked file.
///
/// The mime type when the picker gives one, otherwise guessed from the file name; mp4 is what a
/// phone records, so it is the answer when nothing says otherwise.
String videoMimeSubtype(XFile file) {
  final mime = file.mimeType;
  if (mime != null && mime.startsWith('video/')) {
    return mime.substring('video/'.length);
  }
  final name = file.name.toLowerCase();
  if (name.endsWith('.mov')) return 'quicktime';
  if (name.endsWith('.webm')) return 'webm';
  return 'mp4';
}

/// What the business has picked or removed in a service's photo and video slots, not yet saved.
///
/// Owned by the form, not by [ServiceMediaSlots], because saving is the form's job and comes in
/// a fixed order: the service (or item) is saved first, since a new one has no id to upload
/// against until it exists, and only then are these bytes and removals sent. The form reads them
/// here at that point; the slots only fill them in.
///
/// A slot that already holds a saved picture is tracked as removed rather than simply emptied,
/// so saving can tell "take the old one down" apart from "there never was one".
class ServiceMediaSelection extends ChangeNotifier {
  ServiceMediaSelection({
    required int slotCount,
    String? Function(int slot)? savedImageUrl,
    String? savedVideoUrl,
  }) : _pickedImages = List.filled(slotCount, null),
       _savedImageUrl = savedImageUrl,
       _savedVideoUrl = savedVideoUrl;

  final List<Uint8List?> _pickedImages;
  final Set<int> _removedImageSlots = {};
  final String? Function(int slot)? _savedImageUrl;
  final String? _savedVideoUrl;

  Uint8List? _pickedVideo;
  String? _pickedVideoMimeSubtype;
  bool _removedVideo = false;

  /// One per photo slot the server allows, fixed for the life of the form.
  int get slotCount => _pickedImages.length;

  /// The compressed bytes picked for [slot], or null if nothing new was picked there.
  Uint8List? pickedImage(int slot) => _pickedImages[slot];

  /// Whether the picture saved in [slot] is to be taken down.
  bool isImageRemoved(int slot) => _removedImageSlots.contains(slot);

  /// The saved picture still showing in [slot], or null once it has been removed.
  String? existingImageUrl(int slot) =>
      _removedImageSlots.contains(slot) ? null : _savedImageUrl?.call(slot);

  Uint8List? get pickedVideo => _pickedVideo;

  /// Set whenever [pickedVideo] is.
  String? get pickedVideoMimeSubtype => _pickedVideoMimeSubtype;
  bool get isVideoRemoved => _removedVideo;

  /// The saved video still in place, or null once it has been removed.
  String? get existingVideoUrl => _removedVideo ? null : _savedVideoUrl;

  /// Whether saving has anything to upload or remove.
  bool get hasChanges =>
      _pickedImages.any((bytes) => bytes != null) ||
      _removedImageSlots.isNotEmpty ||
      _pickedVideo != null ||
      _removedVideo;

  void setImage(int slot, Uint8List bytes) {
    _pickedImages[slot] = bytes;
    _removedImageSlots.remove(slot);
    notifyListeners();
  }

  void removeImage(int slot) {
    _pickedImages[slot] = null;
    if (_savedImageUrl?.call(slot) != null) {
      _removedImageSlots.add(slot);
    }
    notifyListeners();
  }

  void setVideo(Uint8List bytes, String mimeSubtype) {
    _pickedVideo = bytes;
    _pickedVideoMimeSubtype = mimeSubtype;
    _removedVideo = false;
    notifyListeners();
  }

  void removeVideo() {
    _pickedVideo = null;
    _pickedVideoMimeSubtype = null;
    if (existingVideoUrl != null) {
      _removedVideo = true;
    }
    notifyListeners();
  }
}

/// The "Photos & video" block of the service and service-item forms: one square per photo slot
/// the server allows, then the video slot, then the line saying what the limits are.
///
/// An empty slot picks straight away; a filled one asks whether to replace or remove it, and a
/// saved video can also be previewed. Pictures are compressed as they are picked, so what the form
/// later uploads is already the size the server wants. Anything that goes wrong is handed to
/// [onError] rather than shown here, so it lands in the form's own message banner.
class ServiceMediaSlots extends ConsumerStatefulWidget {
  const ServiceMediaSlots({
    required this.media,
    required this.onError,
    super.key,
  });

  final ServiceMediaSelection media;

  /// A message for the form to show, or null to clear one after a successful pick.
  final ValueChanged<String?> onError;

  @override
  ConsumerState<ServiceMediaSlots> createState() => _ServiceMediaSlotsState();
}

class _ServiceMediaSlotsState extends ConsumerState<ServiceMediaSlots> {
  ServiceMediaSelection get _media => widget.media;

  void _report(String? message) {
    if (mounted) widget.onError(message);
  }

  Future<void> _pickImage(int slot) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) {
      return;
    }

    try {
      final rawBytes = await picked.readAsBytes();
      final compressed = await compressForUpload(
        rawBytes,
        ref.read(currentAppOptionsProvider),
      );

      _media.setImage(slot, compressed);
      _report(null);
    } catch (e) {
      _report(
        'Could not process the selected image. Please try a different photo.',
      );
    }
  }

  Future<void> _handleImageSlotTap(int slot) async {
    final hasContent =
        _media.pickedImage(slot) != null ||
        _media.existingImageUrl(slot) != null;
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
      _media.removeImage(slot);
    }
  }

  Future<void> _pickVideo() async {
    final picked = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: Duration(
        seconds: ref.read(currentAppOptionsProvider).serviceVideoMaxSeconds,
      ),
    );
    if (picked == null) {
      return;
    }

    try {
      final bytes = await picked.readAsBytes();
      final options = ref.read(currentAppOptionsProvider);
      if (bytes.lengthInBytes > options.serviceVideoMaxBytes) {
        _report(options.serviceVideoTooLarge);
        return;
      }

      _media.setVideo(bytes, videoMimeSubtype(picked));
      _report(null);
    } catch (e) {
      _report(
        'Could not process the selected video. Please try a different clip.',
      );
    }
  }

  Future<void> _handleVideoTap() async {
    final hasExisting = _media.existingVideoUrl != null;
    final hasPending = _media.pickedVideo != null;

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

    final existingUrl = _media.existingVideoUrl;
    if (action == 'preview' && existingUrl != null) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: VideoPreviewPlayer(url: '${ApiConstants.baseUrl}$existingUrl'),
        ),
      );
    } else if (action == 'replace') {
      await _pickVideo();
    } else if (action == 'remove') {
      _media.removeVideo();
    }
  }

  Widget _buildImageSlot(int slot) {
    final pickedBytes = _media.pickedImage(slot);
    final existingUrl = _media.existingImageUrl(slot);

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
    final hasContent =
        _media.pickedVideo != null || _media.existingVideoUrl != null;

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
    return ListenableBuilder(
      listenable: _media,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Photos & video', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var slot = 0; slot < _media.slotCount; slot++) ...[
                  _buildImageSlot(slot),
                  const SizedBox(width: 10),
                ],
                _buildVideoSlot(),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ref.watch(currentAppOptionsProvider).serviceMediaHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
