import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/shared/domain/star_rating.dart';

/// How a star rating reads everywhere in the app: "★ 4.6 (12)", or "New" while the server holds
/// the average back because there are too few ratings to be fair.
///
/// Never "0.0", and never a count on its own that looks like a score.
class RatingLine extends StatelessWidget {
  const RatingLine({
    required this.average,
    required this.count,
    this.label,
    this.style,
    this.starSize = 14,
    super.key,
  });

  RatingLine.of(StarRating rating, {String? label, TextStyle? style, Key? key})
    : this(
        average: rating.average,
        count: rating.count,
        label: label,
        style: style,
        key: key,
      );

  final double? average;
  final int count;

  /// Put in front, e.g. "Service" in the per-line breakdown.
  final String? label;

  /// Defaults to the theme's small body text.
  final TextStyle? style;
  final double starSize;

  /// The words after the star: "4.6 (12)", "New", or "New · 2 ratings".
  static String text(double? average, int count) {
    if (average != null) return '${average.toStringAsFixed(1)} ($count)';
    if (count <= 0) return 'New';
    return 'New · $count ${count == 1 ? 'rating' : 'ratings'}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = style ?? theme.textTheme.bodySmall;
    final rated = average != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label case final name?)
          Text(
            '$name ',
            style: base?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        if (rated) ...[
          Icon(Icons.star_rounded, size: starSize, color: AppColors.ratingStar),
          const SizedBox(width: 2),
        ],
        Flexible(
          child: Text(
            text(average, count),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: rated
                ? base?.copyWith(fontWeight: FontWeight.w700)
                : base?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// "Service ★ 4.5 (12) · Rent ★ 4.8 (6)" — shown only when more than one line has ratings, so a
/// business that runs one line is not described twice.
class LineRatingsRow extends StatelessWidget {
  const LineRatingsRow({required this.lines, this.style, super.key});

  final LineRatings lines;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (!lines.isSplit) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final base = style ?? theme.textTheme.bodySmall;
    final entries = lines.rated.entries.toList();

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 2,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0)
            Text(
              ' · ',
              style: base?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          RatingLine.of(
            entries[i].value,
            label: entries[i].key,
            style: base,
            key: ValueKey('line-rating-${entries[i].key}'),
          ),
        ],
      ],
    );
  }
}
