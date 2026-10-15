import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Colours live in one file and are reached by name.
///
/// They had leaked out into seventeen places. Most were copies of a colour `AppColors` already
/// defined: the rating star was written as a hex twice and as `Colors.amber` once, which is a
/// different amber, so the same star was two shades depending on the screen. The trust cards
/// carried their own copy of the success green. Those copies do not stay in step — the first time
/// a palette moves, half the app follows and half does not.
///
/// This fails on a raw colour written into a widget, so the next one is caught when it is added
/// rather than found later by eye.
void main() {
  /// `Colors.white`, `Colors.black` and `Colors.transparent` are allowed: they are absolutes, not
  /// palette choices, and naming them would say less than they already say.
  final allowed = RegExp(r'(?<![A-Za-z])Colors\.(white|black|transparent)\b');

  final hexLiteral = RegExp(r'Color\(0x[0-9a-fA-F]{6,8}\)');

  /// Not preceded by a letter, so `AppColors.status(...)` — the right way to reach one — is not
  /// mistaken for `Colors.green`.
  final namedMaterial = RegExp(r'(?<![A-Za-z])Colors\.[a-z]+');

  /// Where colours are allowed to be written down.
  const palette = 'lib/core/theme/app_colors.dart';

  test('no colour is written into a widget', () {
    final offenders = <String>[];

    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;

      final path = file.path.replaceAll(r'\', '/');
      if (path.endsWith(palette) || path.endsWith('.g.dart')) continue;

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//') || line.trimLeft().startsWith('///')) {
          continue;
        }

        final withoutAllowed = line.replaceAll(allowed, '');
        if (hexLiteral.hasMatch(withoutAllowed) ||
            namedMaterial.hasMatch(withoutAllowed)) {
          offenders.add('$path:${i + 1}  ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These write a colour instead of naming one. Add it to $palette and use it from there:\n'
          '${offenders.join('\n')}',
    );
  });
}
