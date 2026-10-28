import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/ui_config/ui_icons.dart';

/// How one status, unit or kind reads: its words, colour family and icon.
class UiLabel {
  const UiLabel({
    required this.label,
    this.short,
    this.detail,
    this.tone,
    this.icon,
    this.sort = 0,
  });

  factory UiLabel.fromJson(Map<String, dynamic> json) => UiLabel(
    label: json['label'] as String? ?? '',
    short: json['short'] as String?,
    detail: json['detail'] as String?,
    tone: json['tone'] as String?,
    icon: json['icon'] as String?,
    sort: (json['sort'] as num?)?.toInt() ?? 0,
  );

  final String label;

  /// A shorter form where space is tight — "per day", "/ month". Falls back to [label].
  final String? short;

  /// A sentence that explains it, such as an empty list's message.
  final String? detail;

  /// `success`, `progress`, `waiting` or `danger`.
  final String? tone;

  /// A Material icon name from [UiIcons].
  final String? icon;
  final int sort;

  String get shortLabel => short ?? label;

  /// The colour family, or [StatusTone.waiting] when none is set or the name is unknown — so a
  /// tone added on the server can never break an older app.
  StatusTone get statusTone =>
      StatusTone.values.asNameMap()[tone] ?? StatusTone.waiting;

  IconData? get iconData => UiIcons.byName(icon);

  Map<String, dynamic> toJson() => {
    'label': label,
    if (short != null) 'short': short,
    if (detail != null) 'detail': detail,
    if (tone != null) 'tone': tone,
    if (icon != null) 'icon': icon,
    'sort': sort,
  };
}

/// Every label and colour the app shows, from the server's display_labels and theme_colors tables.
///
/// Read through [UiConfig.current] (or the `uiConfigProvider` to rebuild when it changes). Until
/// the server has been reached it holds the copy bundled in `assets/ui_config`, which is identical
/// to the server's built-in values — so nothing on screen is ever blank or a guess.
class UiConfig {
  const UiConfig({
    required this.version,
    required this.labels,
    required this.colors,
  });

  /// Parses the server's reply, or what was saved from it: `{version, labels, colors}`.
  factory UiConfig.fromJson(Map<String, dynamic> json) => UiConfig(
    version: json['version'] as String? ?? '',
    labels: _parseLabels(json['labels']),
    colors: _parseColors(json['colors']),
  );

  /// Builds one config from the bundled files: `colors.json` and every `labels.*.json`.
  factory UiConfig.fromFiles(Iterable<Map<String, dynamic>> files) {
    final labels = <String, Map<String, UiLabel>>{};
    final colors = <String, (Color, Color)>{};
    for (final file in files) {
      labels.addAll(_parseLabels(file['groups']));
      colors.addAll(_parseColors(file['colors']));
    }
    return UiConfig(version: '', labels: labels, colors: colors);
  }

  static const empty = UiConfig(version: '', labels: {}, colors: {});

  /// The config in force. Set once at start-up from the bundled or saved copy, then replaced
  /// whenever a newer one arrives from the server.
  static UiConfig current = empty;

  /// The copy bundled with this build of the app. A config from the server is laid over it, so a
  /// label this build knows but an older server does not still reads correctly.
  static UiConfig bundled = empty;

  /// Changes whenever any label or colour does; empty for the bundled copy.
  final String version;

  /// Group → code → how it reads.
  final Map<String, Map<String, UiLabel>> labels;

  /// Key → (light, dark).
  final Map<String, (Color, Color)> colors;

  /// How [code] reads in [group]: its own entry, else the group's `*` fallback, else the code
  /// itself in words ("AwaitingPayment" → "Awaiting payment") so a value new to this app still
  /// reads as something.
  UiLabel entry(String group, String? code) {
    final entries = labels[group];
    return entries?[code] ??
        entries?['*'] ??
        UiLabel(label: _words(code ?? ''));
  }

  String label(String group, String? code) => entry(group, code).label;

  StatusTone tone(String group, String? code) => entry(group, code).statusTone;

  IconData? icon(String group, String? code) => entry(group, code).iconData;

  /// The codes of [group] in display order, without the `*` fallback — for a dropdown or a list of
  /// tabs.
  List<String> codes(String group) {
    final entries =
        (labels[group] ?? const <String, UiLabel>{}).entries
            .where((e) => e.key != '*')
            .toList()
          ..sort((a, b) => a.value.sort.compareTo(b.value.sort));
    return [for (final e in entries) e.key];
  }

  /// The colour for [key] in [brightness]. A key missing from the table is a bug in the app, not
  /// in the data, so it fails loudly in debug and paints a neutral grey in release.
  Color color(String key, Brightness brightness) {
    final pair = colors[key];
    assert(pair != null, 'No colour "$key" in the UI config.');
    if (pair == null) return bundled.colors[key]?.$1 ?? Colors.black;
    return brightness == Brightness.dark ? pair.$2 : pair.$1;
  }

  /// This config with every group entry and colour in [other] laid over it. [other]'s version wins.
  UiConfig overlaidWith(UiConfig other) => UiConfig(
    version: other.version,
    labels: {
      for (final group in {...labels.keys, ...other.labels.keys})
        group: {...?labels[group], ...?other.labels[group]},
    },
    colors: {...colors, ...other.colors},
  );

  Map<String, dynamic> toJson() => {
    'version': version,
    'labels': {
      for (final g in labels.entries)
        g.key: {for (final e in g.value.entries) e.key: e.value.toJson()},
    },
    'colors': {
      for (final c in colors.entries)
        c.key: {'light': _hex(c.value.$1), 'dark': _hex(c.value.$2)},
    },
  };

  static Map<String, Map<String, UiLabel>> _parseLabels(Object? json) {
    if (json is! Map) return {};
    return {
      for (final g in json.entries)
        if (g.value is Map)
          g.key as String: {
            for (final e in (g.value as Map).entries)
              if (e.value is Map)
                e.key as String: UiLabel.fromJson(
                  Map<String, dynamic>.from(e.value as Map),
                ),
          },
    };
  }

  static Map<String, (Color, Color)> _parseColors(Object? json) {
    if (json is! Map) return {};
    final colors = <String, (Color, Color)>{};
    for (final c in json.entries) {
      final value = c.value;
      if (value is! Map) continue;
      final light = _parseHex(value['light']);
      final dark = _parseHex(value['dark']);
      if (light != null && dark != null) {
        colors[c.key as String] = (light, dark);
      }
    }
    return colors;
  }

  /// `#AARRGGBB` → a colour, or null for anything else.
  static Color? _parseHex(Object? value) {
    if (value is! String || value.length != 9 || !value.startsWith('#')) {
      return null;
    }
    final argb = int.tryParse(value.substring(1), radix: 16);
    return argb == null ? null : Color(argb);
  }

  static String _hex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

  static String _words(String code) {
    final spaced = code.replaceAllMapped(
      RegExp('(?<=[a-z])([A-Z])'),
      (m) => ' ${m[1]!.toLowerCase()}',
    );
    return spaced;
  }
}
