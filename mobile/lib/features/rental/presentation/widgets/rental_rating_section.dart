import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/features/rental/domain/entities/rental_stock.dart';
import 'package:zuno/features/rental/presentation/providers/rental_order_providers.dart';
import 'package:zuno/features/rental/presentation/providers/rental_providers.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/star_rating_dialog.dart';

/// The rating on a rent order, as each side sees it.
///
/// The customer gets "Rate this rental" once the server says the rental can be rated (returned and
/// fully paid), and "You rated ★ 4" after. The business sees "Customer rated ★ 4". Nothing shows
/// before then.
class RentalRatingSection extends ConsumerWidget {
  const RentalRatingSection({
    required this.order,
    required this.audience,
    super.key,
  });

  final RentalOrder order;
  final RentalAudience audience;

  /// The space above it, when it shows; nothing when it does not.
  static const topGap = 12.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = _content(context, ref);
    if (content == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: topGap),
      child: content,
    );
  }

  Widget? _content(BuildContext context, WidgetRef ref) {
    if (audience == RentalAudience.business) {
      final score = order.customerRating;
      if (score == null) return null;
      return _GivenRating(
        key: const ValueKey('rental-customer-rating'),
        prefix: 'Customer rated',
        score: score,
        comment: order.customerRatingComment,
      );
    }

    if (order.myRating case final score?) {
      return _GivenRating(
        key: const ValueKey('rental-my-rating'),
        prefix: 'You rated',
        score: score,
        comment: order.myRatingComment,
      );
    }

    if (!order.canRate) return null;
    return FilledButton.icon(
      key: const ValueKey('rate-rental'),
      onPressed: () => rateRental(context, ref, order),
      icon: const Icon(Icons.star_outline_rounded),
      label: const Text('Rate this rental'),
    );
  }
}

/// Asks for stars and a comment, then saves them. Returns the order as it now stands, or null
/// when nothing was saved (closed, or refused — the server's reason is shown).
Future<RentalOrder?> rateRental(
  BuildContext context,
  WidgetRef ref,
  RentalOrder order,
) async {
  final input = await showStarRatingDialog(context, title: 'Rate this rental');
  if (input == null || !context.mounted) return null;

  // Before the await, as the app's messages need.
  final messenger = AppMessenger.of(context);
  final reload = rentalReloader(ref);
  try {
    final rated = await ref
        .read(rentalCustomerRepositoryProvider)
        .rate(order.id, input.score, comment: input.comment);
    reload();
    messenger.showSuccess('Thanks — your rating is saved.');
    return rated;
  } catch (e) {
    messenger.showFailure(e.toString());
    return null;
  }
}

/// "You rated ★ 4", with the comment under it when there is one.
class _GivenRating extends StatelessWidget {
  const _GivenRating({
    required this.prefix,
    required this.score,
    this.comment,
    super.key,
  });

  final String prefix;
  final int score;
  final String? comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('$prefix ', style: theme.textTheme.bodyMedium),
                Icon(Icons.star_rounded, size: 18, color: AppColors.ratingStar),
                const SizedBox(width: 2),
                Text(
                  '$score',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (comment case final text? when text.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
