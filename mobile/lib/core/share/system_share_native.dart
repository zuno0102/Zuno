import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:zuno/core/share/share_outcome.dart';

/// Android's share chooser, opened by `MainActivity` (android/app/src/main/kotlin/…/MainActivity.kt).
class SystemShare {
  const SystemShare._();

  /// Must match `SHARE_CHANNEL` in MainActivity.kt.
  static const _channel = MethodChannel('com.zuno.zuno/share');

  /// Opens the chooser with [text]. [url] is appended on its own line, so messaging apps turn it
  /// into a link.
  ///
  /// [ShareOutcome.unavailable] on anything but Android, or if the chooser could not open, so the
  /// caller can fall back to copying. Android does not report whether the person went on to share,
  /// so an opened chooser counts as [ShareOutcome.shared].
  static Future<ShareOutcome> share({
    required String text,
    String? title,
    String? url,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return ShareOutcome.unavailable;
    }

    try {
      await _channel.invokeMethod<void>('share', {
        'text': url == null ? text : '$text\n$url',
        'title': title,
      });
      return ShareOutcome.shared;
    } on PlatformException {
      return ShareOutcome.unavailable;
    } on MissingPluginException {
      return ShareOutcome.unavailable;
    }
  }
}
