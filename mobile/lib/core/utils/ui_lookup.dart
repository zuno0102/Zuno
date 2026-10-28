import 'package:zuno/core/ui_config/ui_config.dart';

/// Lookups the label table's own `entry` does not cover.
extension UiConfigLookup on UiConfig {
  /// [code]'s own entry in [group], or null when the group does not list it — no `*` fallback and
  /// no code-in-words. For a place that says nothing, or something of its own, about a code it does
  /// not know.
  UiLabel? own(String group, String? code) =>
      code == null ? null : labels[group]?[code];
}
