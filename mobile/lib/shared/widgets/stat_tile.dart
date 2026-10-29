import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_colors.dart';

/// The label group naming the sections of tiles on both home screens — "Service jobs",
/// "Full-time jobs".
const dashboardSectionGroup = 'Dashboard.Section';

/// One number on a home screen: an icon, the count, and what it counts — "3 · Upcoming".
///
/// Shared by the business and worker homes, so a tile is the same size and shape in both panels.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;
  final StatusTone tone;

  /// Opens what is behind the number. Null leaves the tile inert.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = AppColors.status(tone, theme.brightness);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 17, color: colour),
                  const Spacer(),
                  // A quiet affordance rather than a button: the tile is the target, and three
                  // of these in a row should not read as three calls to action.
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 15,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [StatTile]s in rows of three. Every tile section on both home screens uses it, so they line up.
class StatTileGrid extends StatelessWidget {
  const StatTileGrid({required this.tiles, super.key});

  final List<Widget> tiles;

  /// Tiles per row. Three is as many as fits before the labels start truncating on a phone,
  /// so the rest wrap onto further rows rather than squeezing.
  static const _perRow = 3;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var start = 0; start < tiles.length; start += _perRow) ...[
          if (start > 0) const SizedBox(height: 10),
          // IntrinsicHeight, not CrossAxisAlignment.stretch. This Column sits in a ListView,
          // so its height is unbounded — and stretch would hand the tiles an infinite height
          // to fill, which fails the whole viewport's layout, not just this row.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = start; i < start + _perRow; i++) ...[
                  if (i > start) const SizedBox(width: 10),
                  // A short last row keeps the tile width of a full one, so every tile on the
                  // screen is the same size rather than the last two stretching to fill.
                  Expanded(
                    child: i < tiles.length ? tiles[i] : const SizedBox(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
