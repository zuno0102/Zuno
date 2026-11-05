import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_colors.dart';

/// What someone gave in [showStarRatingDialog]: 1-5 stars and, if they wrote one, a comment.
class StarRatingInput {
  const StarRatingInput({required this.score, this.comment});

  final int score;

  /// Trimmed; null when left empty.
  final String? comment;
}

/// The one "rate this" dialog: five tappable stars and an optional comment.
///
/// With no [initialScore] a star must be chosen before Submit works, so nobody sends a rating
/// they did not pick. Returns null when closed without submitting.
Future<StarRatingInput?> showStarRatingDialog(
  BuildContext context, {
  required String title,
  int? initialScore,
  int maxCommentLength = StarRatingDialog.commentMaxLength,
}) => showDialog<StarRatingInput>(
  context: context,
  builder: (_) => StarRatingDialog(
    title: title,
    initialScore: initialScore,
    maxCommentLength: maxCommentLength,
  ),
);

class StarRatingDialog extends StatefulWidget {
  const StarRatingDialog({
    required this.title,
    this.initialScore,
    this.maxCommentLength = commentMaxLength,
    super.key,
  });

  /// The servers' own limit on a rating comment.
  static const commentMaxLength = 1000;

  static const maxScore = 5;

  final String title;
  final int? initialScore;
  final int maxCommentLength;

  @override
  State<StarRatingDialog> createState() => _StarRatingDialogState();
}

class _StarRatingDialogState extends State<StarRatingDialog> {
  late int? _score = widget.initialScore;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _submit() {
    final score = _score;
    if (score == null) return;
    final comment = _comment.text.trim();
    Navigator.of(context).pop(
      StarRatingInput(score: score, comment: comment.isEmpty ? null : comment),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = _score;

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var star = 1; star <= StarRatingDialog.maxScore; star++)
                  IconButton(
                    key: ValueKey('rating-star-$star'),
                    tooltip: '$star ${star == 1 ? 'star' : 'stars'}',
                    icon: Icon(
                      score != null && star <= score
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: AppColors.ratingStar,
                    ),
                    onPressed: () => setState(() => _score = star),
                  ),
              ],
            ),
            if (score == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Tap a star to rate.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            TextField(
              key: const ValueKey('rating-comment'),
              controller: _comment,
              maxLines: 3,
              maxLength: widget.maxCommentLength,
              decoration: const InputDecoration(
                labelText: 'Comment (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('rating-submit'),
          onPressed: score == null ? null : _submit,
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
