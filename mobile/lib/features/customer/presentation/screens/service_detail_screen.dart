import 'package:zuno/core/utils/formatting.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/customer/domain/entities/service_detail.dart';
import 'package:zuno/features/customer/domain/entities/service_variant.dart';
import 'package:zuno/features/customer/presentation/providers/customer_providers.dart';
import 'package:zuno/features/customer/presentation/screens/create_booking_screen.dart';
import 'package:zuno/features/customer/presentation/screens/service_variant_detail_screen.dart';
import 'package:zuno/features/customer/presentation/widgets/service_gallery_app_bar.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/section_header.dart';
import 'package:zuno/shared/widgets/status_pill.dart';

/// One service, opened from a card in the feed.
///
/// The service is the subject — its pictures, its price, and every package it is sold in. The
/// business appears as a credit line that can be followed, not as the headline, because a
/// customer arrives here wanting *this* service rather than a tour of everything the business
/// offers.
class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({
    required this.serviceId,
    this.showRelatedServices = true,
    super.key,
  });

  final String serviceId;

  /// Whether to list the other services sold under this one.
  ///
  /// False when the page was opened from the home banner. A banner is an advertisement for one
  /// service, and a customer who tapped it came for that — a list of alternatives underneath reads as
  /// a change of subject rather than help.
  final bool showRelatedServices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(serviceDetailProvider(serviceId));

    return detailAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorBanner(message: error.toString()),
          ),
        ),
      ),
      data: (detail) => _ServiceDetailBody(
        detail: detail,
        showRelatedServices: showRelatedServices,
      ),
    );
  }
}

class _ServiceDetailBody extends StatelessWidget {
  const _ServiceDetailBody({
    required this.detail,
    required this.showRelatedServices,
  });

  final ServiceDetail detail;
  final bool showRelatedServices;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = detail.service;

    // Hidden on request when the page came from a banner — but never when hiding it would leave
    // nothing to book. A service priced at nothing is sold only through the services listed under
    // it, so suppressing that list there would turn the page into a dead end.
    final showRelated =
        detail.hasVariants &&
        (showRelatedServices || !detail.canBookServiceItself);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          ServiceGalleryAppBar(images: detail.images, title: service.name),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.serviceCategoryName.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    service.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        detail.priceLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      if (service.estimatedDurationMinutes case final mins?) ...[
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
                  if (service.description case final text?
                      when text.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(text, style: theme.textTheme.bodyMedium),
                  ],
                  // No service area here. The districts a business works in are how Zuno decides
                  // which services to show in the first place — a filter that has already run by the
                  // time this page opens. Printing it back reads as a restriction on a page the
                  // customer only reached because they were inside it.
                  const SizedBox(height: 18),
                  _BusinessLine(detail: detail),
                ],
              ),
            ),
          ),
          if (showRelated) ...[
            SliverToBoxAdapter(
              // "Packages" was the business's word for these and it did not survive the journey: a
              // business lists the kinds of work it does under a service, and a customer reads them
              // as the services themselves. Named for what they are to the person reading.
              child: SectionHeader(
                title: 'Related services',
                count: service.variants.length,
              ),
            ),
            SliverList.separated(
              itemCount: service.variants.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _VariantCard(
                  variant: service.variants[index],
                  // Tapping opens it properly. Book alone was the only thing these offered, which
                  // asked a customer to commit to something they had not been allowed to read.
                  onOpen: () => _openVariant(context, service.variants[index]),
                  onBook: () => _book(context, variant: service.variants[index]),
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
      // The service itself is bookable too, listed services or not. It used to be hidden the moment
      // any were listed, on the reasoning that each carries its own button — but that left a customer
      // who wanted the whole job, rather than one kind of it, with nothing to press. The server has
      // always accepted an order with no sub-service chosen; only this screen refused to offer it.
      bottomNavigationBar: detail.canBookServiceItself
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: () => _book(context),
                  // Named but not priced. The name is what distinguishes booking the whole service
                  // from booking one of the things listed under it; the price belongs on the page,
                  // not on the button.
                  child: Text(
                    detail.hasVariants
                        ? 'Book ${service.name}'
                        : 'Book this service',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            )
          : null,
    );
  }

  void _openVariant(BuildContext context, ServiceVariant variant) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ServiceVariantDetailScreen(
          variant: variant,
          service: detail.service,
          businessName: detail.business.businessName,
        ),
      ),
    );
  }

  void _book(BuildContext context, {ServiceVariant? variant}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreateBookingScreen(
          businessName: detail.business.businessName,
          service: detail.service,
          variant: variant,
        ),
      ),
    );
  }

}

/// Who is behind this service, and a way through to everything else they offer.
class _BusinessLine extends StatelessWidget {
  const _BusinessLine({required this.detail});

  final ServiceDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final business = detail.business;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/customer/business/${business.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage: business.logoUrl != null
                    ? CachedNetworkImageProvider(
                        '${ApiConstants.baseUrl}${business.logoUrl}',
                      )
                    : null,
                child: business.logoUrl == null
                    ? Text(
                        business.businessName.isNotEmpty
                            ? business.businessName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (business.hasRating) ...[
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: AppColors.ratingStar,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${business.ratingAverage!.toStringAsFixed(1)} '
                            '(${business.reviewCount})',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            business.location ?? 'Location not set',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (business.hasEarnedLevel) ...[
                const SizedBox(width: 8),
                StatusPill(
                  label: business.levelName,
                  tone: StatusTone.success,
                  compact: true,
                ),
              ],
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the services listed inside this one — the thing a customer actually books.
///
/// The whole card opens it; the button books it. Both are offered because the two readers are
/// different people: one already knows what they want, the other has never heard of it.
class _VariantCard extends StatelessWidget {
  const _VariantCard({
    required this.variant,
    required this.onOpen,
    required this.onBook,
  });

  final ServiceVariant variant;
  final VoidCallback onOpen;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumbnail = variant.imageUrlForSlot(0);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (thumbnail != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: '${ApiConstants.baseUrl}$thumbnail',
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Container(
                    width: 64,
                    height: 64,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (variant.serviceSubCategoryName case final subCategory?)
                    Text(
                      subCategory.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  Text(
                    variant.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (variant.description case final text?
                      when text.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        priceLabel(variant.price, variant.priceType),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      if (variant.estimatedDurationMinutes case final mins?) ...[
                        const SizedBox(width: 8),
                        Text(
                          '· ${formatDuration(mins)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.tonal(
                  onPressed: onBook,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('Book'),
                ),
                const SizedBox(height: 2),
                // Says the card is worth tapping. Without it the button looks like the only thing
                // here that does anything, which is exactly how it read before.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Details',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

}
