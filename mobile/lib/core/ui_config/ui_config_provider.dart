import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/ui_config/ui_config.dart';
import 'package:zuno/features/auth/presentation/providers/auth_providers.dart';

part 'ui_config_provider.g.dart';

const _savedKey = 'ui_config.v1';
const _bundledFolder = 'assets/ui_config/';

/// The config the app starts with: the bundled copy, with the last copy saved from the server laid
/// over it. Called once in `main` before the first frame, and by the test setup.
Future<UiConfig> loadStartupUiConfig(AssetBundle bundle) async {
  final bundled = await loadBundledUiConfig(bundle);
  UiConfig.bundled = bundled;

  var config = bundled;
  try {
    final saved = (await SharedPreferences.getInstance()).getString(_savedKey);
    if (saved != null) {
      config = bundled.overlaidWith(
        UiConfig.fromJson(jsonDecode(saved) as Map<String, dynamic>),
      );
    }
  } catch (error) {
    // A saved copy that cannot be read is only a cache: start from the bundled one.
    debugPrint('[UiConfig] Ignoring the saved copy: $error');
  }

  UiConfig.current = config;
  return config;
}

/// Every `assets/ui_config/*.json`, as one config.
Future<UiConfig> loadBundledUiConfig(AssetBundle bundle) async {
  final manifest = await AssetManifest.loadFromAssetBundle(bundle);
  final paths =
      manifest
          .listAssets()
          .where((p) => p.startsWith(_bundledFolder) && p.endsWith('.json'))
          .toList()
        ..sort();

  final files = <Map<String, dynamic>>[];
  for (final path in paths) {
    files.add(
      jsonDecode(await bundle.loadString(path)) as Map<String, dynamic>,
    );
  }
  return UiConfig.fromFiles(files);
}

/// The labels and colours in force, rebuilt when a newer copy arrives from the server.
///
/// Starts with what [loadStartupUiConfig] set, then asks the server once per launch — sending the
/// version it already has, so an unchanged config costs a 304 and no download.
@Riverpod(keepAlive: true)
class UiConfigNotifier extends _$UiConfigNotifier {
  @override
  UiConfig build() {
    Future.microtask(refresh);
    return UiConfig.current;
  }

  Future<void> refresh() async {
    try {
      final current = state;
      final response = await ref
          .read(dioClientProvider)
          .get<Map<String, dynamic>>(
            ApiConstants.uiConfigPath,
            options: Options(
              headers: {
                if (current.version.isNotEmpty)
                  'If-None-Match': '"${current.version}"',
              },
              validateStatus: (status) =>
                  status != null && (status == 304 || status < 300),
            ),
          );
      if (response.statusCode == 304 || response.data == null) return;

      final fresh = UiConfig.bundled.overlaidWith(
        UiConfig.fromJson(response.data!),
      );
      UiConfig.current = fresh;
      state = fresh;
      await (await SharedPreferences.getInstance()).setString(
        _savedKey,
        jsonEncode(fresh.toJson()),
      );
    } catch (error) {
      // Offline or the server is down: what is on screen is already a complete config.
      debugPrint('[UiConfig] Could not refresh: $error');
    }
  }
}
