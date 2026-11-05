import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/features/rental/presentation/providers/rental_customer_providers.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_booking_sheet.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_item_card.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
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

class _Body extends StatefulWidget {
  const _Body({required this.card, this.detail});

  final RentalCard card;
  final RentalItemDetail? detail;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  int _photo = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = widget.detail;
    final photos = detail?.imageUrls ?? [?widget.card.imageUrl];
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // The photos, swiped, with how many there are.
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (photos.isEmpty)
                const RentalPhoto(path: null)
              else
                PageView.builder(
                  itemCount: photos.length,
                  onPageChanged: (i) => setState(() => _photo = i),
                  itemBuilder: (_, i) => RentalPhoto(path: photos[i]),
                ),
              if (photos.length > 1)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Text(
                        '${_photo + 1} / ${photos.length}',
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.card.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              RatingLine.of(
                widget.card.rating,
                style: theme.textTheme.bodyMedium,
                key: const ValueKey('rental-item-rating'),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  widget.card.categoryName,
                  ?detail?.subCategoryName,
                ].join(' › '),
                style: muted,
              ),
              if (detail?.description case final text?
                  when text.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(text, style: theme.textTheme.bodyLarge),
              ],
              if (detail != null) ...[
                const SizedBox(height: 18),
                _Fact(
                  icon: Icons.sell_outlined,
                  label: 'Rate',
                  value:
                      '${rupees(detail.card.price)}${detail.card.unitSuffix} · '
                      '${detail.priceTypeName}',
                ),
                _Fact(
                  icon: Icons.inventory_2_outlined,
                  label: 'Pieces it has',
                  value: '${detail.quantityOwned}',
                ),
                _Fact(
                  icon: Icons.place_outlined,
                  label: 'Delivers to',
                  value: detail.districts.map((d) => d.name).join(', '),
                ),
                if (detail.video != null)
                  const _Fact(
                    icon: Icons.videocam_outlined,
                    label: 'Video',
                    value: 'This item has a video from the business',
                  ),
                const SizedBox(height: 18),
                _BusinessCard(
                  name: widget.card.businessName,
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

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Who rents it out — a verified business, as only verified businesses' items are shown.
class _BusinessCard extends StatelessWidget {
  const _BusinessCard({required this.name, this.logoPath});

  final String name;

  /// A path on the Service server, where business profiles live.
  final String? logoPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logo = logoPath;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          backgroundImage: logo == null || logo.isEmpty
              ? null
              : NetworkImage('${ApiConstants.baseUrl}$logo'),
          child: logo == null || logo.isEmpty
              ? Icon(
                  Icons.storefront_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                )
              : null,
        ),
        title: Text(
          name.isEmpty ? 'Business' : name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Row(
          children: [
            Icon(Icons.verified, size: 15, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            const Text('Verified business'),
          ],
        ),
      ),
    );
  }
}
