import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:zuno/features/catalog/domain/entities/app_options.dart';

/// A picked photo, made ready to upload: re-encoded as JPEG at the configured quality and scaled
/// down to the configured width.
///
/// The gallery may hand back HEIC/HEIF (common on modern phone camera defaults), which Flutter's
/// image renderer cannot decode at all. Re-encoding to JPEG here — using the platform's native
/// decoder, which does understand HEIC — guarantees the bytes this app uploads and later tries to
/// display are always something it can actually render.
///
/// Bytes in, bytes out (rather than file paths) is deliberate: image_picker returns a blob URL on
/// web, not a real filesystem path, so any path-based API (dart:io File, compressAndGetFile)
/// silently fails there. This works identically on every platform.
Future<Uint8List> compressForUpload(Uint8List raw, AppOptions options) =>
    FlutterImageCompress.compressWithList(
      raw,
      format: CompressFormat.jpeg,
      quality: options.imageUploadQuality,
      minWidth: options.imageUploadMaxWidth,
      minHeight: options.imageUploadMaxWidth,
    );
