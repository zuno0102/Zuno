import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/router/push_screen.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/marketplace/data/marketplace_api.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_customer.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_customer_providers.dart';
import 'package:zuno/features/marketplace/presentation/screens/customer_marketplace_post_screen.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/listing_card.dart';

/// A path the Marketplace server returned, as a full address; null stays null.
String? marketplacePhotoUrl(String? path) =>
    path == null || path.isEmpty ? null : MarketplaceApi.mediaUrl(path);

/// "₹38 / kg", "₹2,400"; null without a price (an advert). [price] overrides the card's own,
/// e.g. a colour sold at its own price.
String? marketplacePrice(MarketplaceCard card, {double? price}) {
  price ??= card.price;
  if (price == null) return null;
  final unit = card.priceUnit;
  return unit == null || unit.isEmpty
      ? rupees(price)
      : '${rupees(price)} / $unit';
}

/// Opens a post's page.
void openMarketplacePost(BuildContext context, MarketplaceCard card) =>
    pushScreen(context, CustomerMarketplacePostScreen(preview: card));

/// A post on the customer's home, search and wishlist — the shared [ListingCard] with a heart.
class MarketplacePostCard extends StatelessWidget {
  const MarketplacePostCard({required this.card, super.key});

  final MarketplaceCard card;

  @override
  Widget build(BuildContext context) {
    final was = card.originalPrice;
    final b2b = card.isWholesale && card.minOrderQuantity != null;
    return ListingCard(
      key: ValueKey('marketplace-card-${card.id}'),
      imageUrl: marketplacePhotoUrl(card.imageUrl),
      price: marketplacePrice(card),
      wasPrice: was == null ? null : rupees(was),
      saving: switch (card.percentOff) {
        final off? when off > 0 => '$off% off',
        _ => null,
      },
      title: card.title,
      placeLine: b2b
          ? 'B2B · smallest order ${card.minOrderQuantity}${card.priceUnit == null ? '' : ' ${card.priceUnit}'}'
          : [card.categoryName, card.districtName].join(' · '),
      businessName: card.businessName,
      badge: card.isAvailable ? null : 'Not available',
      dimmed: !card.isAvailable,
      photoCorner: MarketplaceHeartButton(card: card),
      // A post no longer on sale has no page to open; say why instead.
      onTap: card.isAvailable
          ? () => openMarketplacePost(context, card)
          : () => AppMessenger.of(context).showInfo(
              'No longer on sale. Tap the heart to take it off your wishlist.',
            ),
    );
  }
}

/// The heart that saves a post to the wishlist. Shows the tap at once; goes back with a message
/// if the server refuses it.
class MarketplaceHeartButton extends ConsumerWidget {
  const MarketplaceHeartButton({required this.card, super.key});

  final MarketplaceCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved =
        ref.watch(marketplaceSavedPostsProvider.select((s) => s[card.id])) ??
        card.isFavourite;
    final theme = Theme.of(context);

    return IconButton.filledTonal(
      key: ValueKey('marketplace-heart-${card.id}'),
      tooltip: saved ? 'Remove from wishlist' : 'Save to wishlist',
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.94),
      ),
      onPressed: () async {
        final messenger = AppMessenger.of(context);
        try {
          await ref.read(marketplaceSavedPostsProvider.notifier).toggle(card);
        } catch (e) {
          messenger.showFailure(e.toString());
        }
      },
      icon: Icon(
        saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: saved
            ? AppColors.status(StatusTone.danger, theme.brightness)
            : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
