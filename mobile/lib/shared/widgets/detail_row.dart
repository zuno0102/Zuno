import 'package:flutter/material.dart';

/// One fact on a detail screen or card: a label and its value, or an icon and a line of text.
///
/// Promoted out of eleven private copies (`_DetailRow`, `_DetailLine`, `_Line`, `_InfoRow`) that
/// had grown screen by screen. They came in five shapes, and each shape is a constructor here so a
/// screen says which one it means rather than tuning a dozen knobs:
///
/// * [DetailRow.new] — the label above its value, as an order's detail screen reads.
/// * [DetailRow.inline] — the label in a fixed column beside the value, for a short profile list.
/// * [DetailRow.icon] — an icon, then the label over the value and an optional quieter detail.
/// * [DetailRow.iconText] — an icon and one line of text, with no label, for a card's summary.
/// * [DetailRow.tile] — a dense list tile, the value (or a widget such as a pill) at the trailing
///   edge, for a settings-style card.
///
/// The spacing each copy used is kept as it was, so no screen changes look by moving here.
class DetailRow extends StatelessWidget {
  /// The label above its value.
  const DetailRow({
    required String this.label,
    required this.value,
    this.spacing = 10,
    super.key,
  }) : _shape = _Shape.stacked,
       icon = null,
       detail = null,
       labelWidth = 0,
       isMissing = false,
       iconColor = null,
       valueColor = null,
       muted = false,
       emphasised = false,
       maxLines = null,
       iconSize = 0,
       iconGap = 0,
       padding = EdgeInsets.zero,
       alignment = CrossAxisAlignment.start,
       trailing = null;

  /// The label in a column [labelWidth] wide, the value beside it.
  ///
  /// [isMissing] paints the value in the error colour, for a "Not set" a person should fix.
  const DetailRow.inline({
    required String this.label,
    required this.value,
    this.labelWidth = 92,
    this.isMissing = false,
    super.key,
  }) : _shape = _Shape.inline,
       icon = null,
       detail = null,
       spacing = 0,
       iconColor = null,
       valueColor = null,
       muted = false,
       emphasised = false,
       maxLines = null,
       iconSize = 0,
       iconGap = 0,
       padding = EdgeInsets.zero,
       alignment = CrossAxisAlignment.start,
       trailing = null;

  /// An icon, then the label over the value, with an optional quieter [detail] under it.
  ///
  /// Draws nothing when there is neither a value nor a detail, so a fact that is not known yet
  /// leaves no empty heading behind.
  const DetailRow.icon({
    required IconData this.icon,
    required String this.label,
    required this.value,
    this.detail,
    super.key,
  }) : _shape = _Shape.iconLabelled,
       spacing = 12,
       labelWidth = 0,
       isMissing = false,
       iconColor = null,
       valueColor = null,
       muted = false,
       emphasised = false,
       maxLines = null,
       iconSize = 18,
       iconGap = 10,
       padding = EdgeInsets.zero,
       alignment = CrossAxisAlignment.start,
       trailing = null;

  /// An icon and one line of small text, with no label.
  ///
  /// Both are muted by default, the quiet summary line under a card's title. [iconColor] and
  /// [valueColor] tint them; [muted] false leaves untinted text in the ordinary body colour; and
  /// [emphasised] makes the text bold — a line saying something needs attention reads at a glance.
  const DetailRow.iconText({
    required IconData this.icon,
    required String text,
    this.iconColor,
    this.valueColor,
    this.muted = true,
    this.emphasised = false,
    this.maxLines,
    this.iconSize = 14,
    this.iconGap = 7,
    this.padding = const EdgeInsets.symmetric(vertical: 2),
    this.alignment = CrossAxisAlignment.center,
    super.key,
  }) : _shape = _Shape.iconText,
       value = text,
       label = null,
       detail = null,
       spacing = 0,
       labelWidth = 0,
       isMissing = false,
       trailing = null;

  /// A dense list tile: the label on the left, the value — or [trailing] in its place — on the
  /// right, in bold.
  const DetailRow.tile({
    required String this.label,
    String? value,
    this.trailing,
    super.key,
  }) : _shape = _Shape.tile,
       value = value ?? '',
       icon = null,
       detail = null,
       spacing = 0,
       labelWidth = 0,
       isMissing = false,
       iconColor = null,
       valueColor = null,
       muted = false,
       emphasised = false,
       maxLines = null,
       iconSize = 0,
       iconGap = 0,
       padding = EdgeInsets.zero,
       alignment = CrossAxisAlignment.start;

  final _Shape _shape;

  /// What the value is. Null only on [DetailRow.iconText], which has none.
  final String? label;
  final String value;
  final IconData? icon;

  /// A quieter line under the value ([DetailRow.icon] only).
  final String? detail;

  /// The gap below the row ([DetailRow.new] and [DetailRow.icon]).
  final double spacing;

  /// How wide the label column is ([DetailRow.inline] only).
  final double labelWidth;
  final bool isMissing;
  final Color? iconColor;
  final Color? valueColor;

  /// Whether untinted text takes the muted colour ([DetailRow.iconText] only).
  final bool muted;
  final bool emphasised;
  final int? maxLines;
  final double iconSize;
  final double iconGap;
  final EdgeInsets padding;
  final CrossAxisAlignment alignment;

  /// Shown at the trailing edge instead of the value ([DetailRow.tile] only).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quiet = theme.colorScheme.onSurfaceVariant;

    switch (_shape) {
      case _Shape.stacked:
        return Padding(
          padding: EdgeInsets.only(bottom: spacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label!, style: theme.textTheme.labelMedium),
              Text(value),
            ],
          ),
        );

      case _Shape.inline:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: labelWidth,
                child: Text(
                  label!,
                  style: theme.textTheme.bodySmall?.copyWith(color: quiet),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isMissing ? theme.colorScheme.error : null,
                  ),
                ),
              ),
            ],
          ),
        );

      case _Shape.iconLabelled:
        if (value.trim().isEmpty && detail == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: EdgeInsets.only(bottom: spacing),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: iconSize, color: quiet),
              SizedBox(width: iconGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label!,
                      style: theme.textTheme.labelSmall?.copyWith(color: quiet),
                    ),
                    if (value.trim().isNotEmpty)
                      Text(value, style: theme.textTheme.bodyMedium),
                    if (detail case final extra?)
                      Text(
                        extra,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: quiet,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );

      case _Shape.iconText:
        return Padding(
          padding: padding,
          child: Row(
            crossAxisAlignment: alignment,
            children: [
              Icon(icon, size: iconSize, color: iconColor ?? quiet),
              SizedBox(width: iconGap),
              Expanded(
                child: Text(
                  value,
                  maxLines: maxLines,
                  overflow: maxLines == null ? null : TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: valueColor ?? (muted ? quiet : null),
                    fontWeight: emphasised ? FontWeight.w600 : null,
                  ),
                ),
              ),
            ],
          ),
        );

      case _Shape.tile:
        return ListTile(
          dense: true,
          title: Text(label!, style: theme.textTheme.bodyMedium),
          trailing:
              trailing ??
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
        );
    }
  }
}

enum _Shape { stacked, inline, iconLabelled, iconText, tile }
