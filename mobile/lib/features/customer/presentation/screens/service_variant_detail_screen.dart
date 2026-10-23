import 'package:flutter/material.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/customer/domain/entities/customer_service.dart';
import 'package:zuno/features/customer/domain/entities/service_variant.dart';
import 'package:zuno/features/customer/presentation/screens/create_booking_screen.dart';
import 'package:zuno/features/customer/presentation/widgets/service_gallery_app_bar.dart';
import 'package:zuno/features/customer/presentation/widgets/share_service.dart';
import 'package:zuno/core/router/push_screen.dart';

/// One of the services listed inside another, opened on its own.
///
/// A business sells painting as a service and lists the kinds of painting under it, each with its own
/// pictures, description, price and duration. On the customer's side those only ever offered a Book
/// button — no way to look at one before committing to it, even though every one of them carries a
/// full page's worth of detail the business had filled in. This is that page.
///
/// Deliberately the same shape as the service page it was opened from: gallery, what it is, what it
/// costs, how long it takes, then the description. Somebody two taps in should not feel they have
/// landed somewhere lesser.
class ServiceVariantDetailScreen extends StatelessWidget {
  const ServiceVariantDetailScreen({
    required this.variant,
    required this.service,
    required this.businessName,
    super.key,
  });

  final ServiceVariant variant;

  /// The service this one sits inside, which is what a booking is actually placed against.
  final CustomerService service;

  final String businessName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final images = variant.media.where((m) => m.isImage).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          ServiceGalleryAppBar(
            images: images,
            title: variant.name,
            onShare: () => shareService(
              context,
              name: variant.name,
              price: priceLabel(variant.price, variant.priceType),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (variant.serviceSubCategoryName ??
                            service.serviceCategoryName)
                        .toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    variant.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        priceLabel(variant.price, variant.priceType),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      if (variant.estimatedDurationMinutes case final mins?) ...[
                        const SizedBox(width: 10),
                        Icon(
                          Icons.schedule_rounded,
                          size: 15,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          formatDuration(mins),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (variant.description case final text? when text.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    // In full, not the two clipped lines the list can afford.
                    Text(text, style: theme.textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 18),
                  // Which service this belongs to, so somebody two taps deep still knows what they
                  // are looking at and what name will appear on their order.
                  Text(
                    'Part of ${service.name} · $businessName',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: () => pushScreen(context, CreateBookingScreen(
                  businessName: businessName,
                  service: service,
                  variant: variant,
                )),
            child: Text('Book ${variant.name}'),
          ),
        ),
      ),
    );
  }
}
