import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuno/core/ui_config/ui_config_provider.dart';

/// Runs before every test file: loads the bundled labels and colours the app starts with, so a
/// widget under test paints exactly what the app would before it reaches the server.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  await loadStartupUiConfig(rootBundle);

  // Every test starts with nothing saved on the device, so one test's saved location or filter can
  // never leak into the next.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  await testMain();
}
