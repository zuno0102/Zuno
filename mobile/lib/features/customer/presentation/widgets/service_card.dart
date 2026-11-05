import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/shared/widgets/rating_line.dart';
import 'package:zuno/features/customer/domain/entities/service_listing.dart';
import 'package:zuno/shared/widgets/status_pill.dart';

/// One bookable service, led by its picture.
///
/// The service is the headline and the business the credit line, because that is the order a
/// customer thinks in — they want catering first and a caterer second.
class ServiceCard extends StatelessWidget {
  const ServiceCard({required this.service, required this.onTap, super.key});

  final ServiceListing service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: service.imageUrl == null
                    ? Container(
                        color: theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.5,
                        ),
                        child: Icon(
                          Icons.image_outlined,
                          size: 30,
                          color: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.5),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: '${ApiConstants.baseUrl}${service.imageUrl}',
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    service.businessName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    service.priceLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // The service's own stars, or "New" until it has enough ratings.
                      Flexible(
                        child: RatingLine.of(
                          service.serviceRating,
                          key: const ValueKey('service-card-rating'),
                        ),
                      ),
                      if (service.hasEarnedLevel) ...[
                        const SizedBox(width: 6),
                        StatusPill(
                          label: service.levelName,
                          tone: StatusTone.success,
                          compact: true,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
