import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/customer/domain/entities/service_listing.dart';

/// The services customers book most, as a row you swipe along.
///
/// Horizontal on purpose: eight of these as a grid would be four more rows before anything else on
/// the page, and the point of the strip is that it costs one screen's height however many are in it.
/// The full list underneath is where somebody browses properly.
class PopularServicesStrip extends StatelessWidget {
  const PopularServicesStrip({required this.services, super.key});

  final List<ServiceListing> services;

  /// Tall enough for a picture worth judging and the two lines under it, and no taller.
  static const _height = 186.0;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) return const SizedBox.shrink();

    return SizedBox(
          height: _height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
            itemCount: services.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) =>
                _StripCard(service: services[index]),
          ),
    );
  }
}

class _StripCard extends StatelessWidget {
  const _StripCard({required this.service});

  final ServiceListing service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = service.imageUrl;

    return SizedBox(
      // Narrow enough that the next card shows at the edge, which is what says the row scrolls.
      width: 150,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/customer/service/${service.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: imageUrl == null
                    ? Container(
                        color: theme.colorScheme.primaryContainer,
                        child: Icon(
                          Icons.image_outlined,
                          color: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.5),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: '${ApiConstants.baseUrl}$imageUrl',
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image_outlined, size: 18),
                        ),
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        service.businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        priceLabel(service.price, service.priceType),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
