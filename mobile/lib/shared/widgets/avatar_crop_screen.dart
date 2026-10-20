import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/shared/widgets/app_messages.dart';

/// A full-screen editor for framing a profile picture before it is uploaded.
///
/// Without it a portrait photo goes up as-is and the circular avatar shows whatever happens to
/// sit in the middle — usually a chest, not a face. Here the person drags and pinches the photo
/// under a circle that matches exactly what the avatar will show.
///
/// Pops with the cropped square image (encoded by the cropper; re-encode before uploading), or
/// with null if they back out.
class AvatarCropScreen extends StatefulWidget {
  const AvatarCropScreen({super.key, required this.image});

  /// The photo to frame. Must be a format Dart can decode (JPEG/PNG/WebP) — HEIC is not, so
  /// normalise it first.
  final Uint8List image;

  /// The whole journey from a freshly picked photo to an upload-ready avatar: normalise it, let
  /// the person frame it, and re-encode the result. Returns null if they back out.
  static Future<Uint8List?> frame(BuildContext context, Uint8List rawBytes) async {
    // Phone cameras commonly hand back HEIC, which neither the cropper nor the server can read,
    // so it goes through the platform's own decoder first. Capping it near screen size also
    // keeps the cropper — which works in Dart — quick on a 50MP original.
    final normalised = await FlutterImageCompress.compressWithList(
      rawBytes,
      format: CompressFormat.jpeg,
      quality: 90,
      minWidth: 1280,
      minHeight: 1280,
    );
    if (!context.mounted) return null;

    final cropped = await open(context, normalised);
    if (cropped == null) return null;

    // Re-encoded once more as a JPEG. This is what holds the upload under the server's 5MB cap
    // (image_picker's own size arguments are ignored on the web), and 512px square is plenty
    // for an avatar.
    return FlutterImageCompress.compressWithList(
      cropped,
      format: CompressFormat.jpeg,
      quality: 85,
      minWidth: 512,
      minHeight: 512,
    );
  }

  /// Opens the editor and returns the cropped bytes, or null if cancelled.
  static Future<Uint8List?> open(BuildContext context, Uint8List image) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AvatarCropScreen(image: image),
      ),
    );
  }

  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<AvatarCropScreen> {
  final _controller = CropController();
  bool _isReady = false;
  bool _isCropping = false;

  void _crop() {
    setState(() => _isCropping = true);
    // A square crop rather than cropCircle(): the avatar is already drawn as a circle, and a
    // square keeps the image a plain opaque JPEG instead of a PNG with transparent corners.
    _controller.crop();
  }

  void _onCropped(CropResult result) {
    if (!mounted) return;
    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.of(context).pop(croppedImage);
      case CropFailure():
        setState(() => _isCropping = false);
        context.showFailureMessage('Could not crop this photo. Try another one.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Adjust photo'),
        actions: [
          TextButton(
            onPressed: _isReady && !_isCropping ? _crop : null,
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Crop(
                    image: widget.image,
                    controller: _controller,
                    onCropped: _onCropped,
                    withCircleUi: true,
                    // Pinch-to-zoom and drag on the photo itself, with the circle held still —
                    // the same feel as setting a picture in WhatsApp or Instagram.
                    interactive: true,
                    fixCropRect: true,
                    initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
                      size: 0.85,
                      aspectRatio: 1,
                    ),
                    baseColor: Colors.black,
                    maskColor: Colors.black.withValues(alpha: 0.6),
                    onStatusChanged: (status) {
                      if (status == CropStatus.ready && !_isReady) {
                        setState(() => _isReady = true);
                      }
                    },
                    progressIndicator: const CircularProgressIndicator(),
                  ),
                  if (_isCropping) const CircularProgressIndicator(),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Pinch to zoom and drag to position your face in the circle',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.onMediaMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
