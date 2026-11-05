import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The web build keeps the same file names from one release to the next — main.dart.js, the
/// icon font, the font list. Kept for days in a phone's browser, an old icon font met newer code
/// and every icon added since drew as nothing (the Rent tiles, My rents, the − button). So every
/// file that changes with a release is checked again on each visit; only the app's own home-screen
/// icons may be kept.
void main() {
  final rules =
      (jsonDecode(File('web/vercel.json').readAsStringSync())
              as Map<String, dynamic>)['headers']
          as List<dynamic>;

  String? cacheFor(String path) {
    for (final rule in rules.cast<Map<String, dynamic>>()) {
      if (RegExp('^${rule['source']}\$').hasMatch(path)) {
        for (final h
            in (rule['headers'] as List).cast<Map<String, dynamic>>()) {
          if (h['key'] == 'Cache-Control') return h['value'] as String;
        }
      }
    }
    return null;
  }

  for (final path in [
    '/index.html',
    '/main.dart.js',
    '/flutter_bootstrap.js',
    '/assets/fonts/MaterialIcons-Regular.otf',
    '/assets/FontManifest.json',
    '/assets/AssetManifest.bin.json',
    '/assets/packages/cupertino_icons/assets/CupertinoIcons.ttf',
    '/canvaskit/canvaskit.wasm',
  ]) {
    test('$path is checked again on every visit', () {
      expect(cacheFor(path), contains('no-cache'));
      expect(cacheFor(path), isNot(contains('max-age')));
    });
  }

  test('the home-screen icons may stay cached', () {
    expect(cacheFor('/icons/Icon-192.png'), contains('max-age'));
  });
}
