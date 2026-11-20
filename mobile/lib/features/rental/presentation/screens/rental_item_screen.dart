import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/features/rental/presentation/providers/rental_customer_providers.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_booking_sheet.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_item_card.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/fact_row.dart';
import 'package:zuno/shared/widgets/photo_gallery.dart';
import 'package:zuno/shared/widgets/rating_line.dart';

/// A rent item as a customer opens it: the photos, the rate, what it is, where it is offered, who
/// rents it out — and **Book** at the bottom, always in reach.
class RentalItemScreen extends ConsumerWidget {
  const RentalItemScreen({required this.itemId, this.preview, super.key});

  final String itemId;

  /// The card the customer tapped, shown at once while the rest loads.
  final RentalCard? preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(rentalItemDetailProvider(itemId));
    final detail = detailAsync.value;
    final card = detail?.card ?? preview;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(card?.name ?? 'Rent item')),
      bottomNavigationBar: detail == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${rupees(detail.card.price)}${detail.card.unitSuffix}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            detail.priceTypeName,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      key: const ValueKey('rent-book'),
                      onPressed: () => showRentalBookingSheet(context, detail),
                      icon: const Icon(Icons.event_available_outlined),
                      label: const Text('Book'),
                    ),
                  ],
                ),
              ),
            ),
      body: detailAsync.when(
        loading: () => card == null
            ? const Center(child: CircularProgressIndicator())
            : _Body(card: card),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorBanner(message: error.toString()),
          ),
        ),
        data: (detail) => _Body(card: detail.card, detail: detail),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.card, this.detail});

  final RentalCard card;
  final RentalItemDetail? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = this.detail;
    final photos = detail?.imageUrls ?? [?card.imageUrl];
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // The photos, swiped, with how many there are.
        PhotoGallery(urls: [for (final p in photos) ?rentalPhotoUrl(p)]),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              RatingLine.of(
                card.rating,
                style: theme.textTheme.bodyMedium,
                key: const ValueKey('rental-item-rating'),
              ),
              const SizedBox(height: 4),
              Text(
                [card.categoryName, ?detail?.subCategoryName].join(' › '),
                style: muted,
              ),
              if (detail?.description case final text?
                  when text.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(text, style: theme.textTheme.bodyLarge),
              ],
              if (detail != null) ...[
                const SizedBox(height: 18),
                FactRow(
                  icon: Icons.sell_outlined,
                  label: 'Rate',
                  value:
                      '${rupees(detail.card.price)}${detail.card.unitSuffix} · '
                      '${detail.priceTypeName}',
                ),
                FactRow(
                  icon: Icons.inventory_2_outlined,
                  label: 'Pieces it has',
                  value: '${detail.quantityOwned}',
                ),
                FactRow(
                  icon: Icons.place_outlined,
                  label: 'Delivers to',
                  value: detail.districts.map((d) => d.name).join(', '),
                ),
                if (detail.video != null)
                  const FactRow(
                    icon: Icons.videocam_outlined,
                    label: 'Video',
                    value: 'This item has a video from the business',
                  ),
                const SizedBox(height: 18),
                VerifiedBusinessCard(
                  name: card.businessName,
                  logoPath: detail.businessLogoUrl,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
