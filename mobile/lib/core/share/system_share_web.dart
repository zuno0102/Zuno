import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:zuno/core/share/share_outcome.dart';

extension type _ShareData._(JSObject _) implements JSObject {
  external factory _ShareData({String? title, String? text, String? url});
}

extension type _Navigator._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> share(_ShareData data);
}

@JS('navigator')
external _Navigator get _navigator;

/// The browser's share sheet, through the Web Share API.
///
/// On a phone's browser this is the same sheet as a native app gets (WhatsApp, Instagram,
/// Facebook, …). Most desktop browsers other than Chrome and Edge on Windows lack it, and every
/// browser refuses it on plain http, so callers must handle [ShareOutcome.unavailable].
class SystemShare {
  const SystemShare._();

  static bool get _isSupported => _navigator.has('share');

  /// Opens the sheet. Must be called straight from a tap: browsers only allow it in direct
  /// response to the person, so do not await anything before calling this.
  static Future<ShareOutcome> share({
    required String text,
    String? title,
    String? url,
  }) async {
    if (!_isSupported) return ShareOutcome.unavailable;

    try {
      await _navigator
          .share(_ShareData(title: title, text: text, url: url))
          .toDart;
      return ShareOutcome.shared;
    } catch (error) {
      // AbortError is the person closing the sheet. Anything else (NotAllowedError when the
      // browser blocks it, a payload it rejects) means the sheet is not usable here.
      return error.toString().contains('AbortError')
          ? ShareOutcome.dismissed
          : ShareOutcome.unavailable;
    }
  }

  /// Not offered in the browser: applicants' documents are opened from the phone app, where
  /// they are handed to the system viewer and never left in a downloads folder.
  static Future<ShareOutcome> openFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async => ShareOutcome.unavailable;
}
