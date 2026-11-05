import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/rental/data/rental_api.dart';
import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/shared/widgets/rating_line.dart';

/// A rent item on the customer's Rent home and search — the photo, the rate on it, the name, where,
/// and who rents it out. One card for the grids and the sideways strips; the parent gives the width.
class RentalItemCard extends StatelessWidget {
  const RentalItemCard({required this.card, required this.onTap, super.key});

  final RentalCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      key: ValueKey('rental-card-${card.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RentalPhoto(path: card.imageUrl),
                  // The rate where the eye lands: on the picture, as a price tag.
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(
                          alpha: 0.94,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          '${rupees(card.price)}${card.unitSuffix}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  RatingLine.of(
                    card.rating,
                    key: ValueKey('rental-card-rating-${card.id}'),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          [card.categoryName, ?card.districtName].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: muted,
                        ),
                      ),
                    ],
                  ),
                  if (card.businessName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            card.businessName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A rent item's photo from the Rent server, or a quiet placeholder when it has none.
class RentalPhoto extends StatelessWidget {
  const RentalPhoto({required this.path, this.fit = BoxFit.cover, super.key});

  /// A path on the Rent server, as it returns them.
  final String? path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.inventory_2_outlined,
        size: 36,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
    final value = path;
    if (value == null || value.isEmpty) return placeholder;

    return CachedNetworkImage(
      imageUrl: RentApi.mediaUrl(value),
      fit: fit,
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => placeholder,
    );
  }
}
