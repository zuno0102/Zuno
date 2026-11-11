import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Reads the app's assets straight from the project folder, at once.
///
/// The real bundle reads through the engine, which a widget test's clock does not wait for, so a
/// screen that loads a help or legal page never finishes. Given as the [DefaultAssetBundle].
class FileAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) =>
      SynchronousFuture(ByteData.sublistView(File(key).readAsBytesSync()));

  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      SynchronousFuture(File(key).readAsStringSync());
}
