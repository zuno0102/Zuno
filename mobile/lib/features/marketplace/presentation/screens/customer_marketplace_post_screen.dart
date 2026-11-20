import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/router/push_screen.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_customer.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_customer_providers.dart';
import 'package:zuno/features/marketplace/presentation/screens/customer_marketplace_order_screen.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_lot_request_sheet.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_order_sheet.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_post_card.dart';
import 'package:zuno/shared/widgets/call_icon_button.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/fact_row.dart';
import 'package:zuno/shared/widgets/job_location_card.dart';
import 'package:zuno/shared/widgets/photo_gallery.dart';

/// A Marketplace post as a customer opens it: photos, price, what it is, who sells it — and the one
/// thing to do with it at the bottom: **Buy now** for a product, **Request this lot** for B2B. Food
/// offers and adverts show where the shop is, to go there.
class CustomerMarketplacePostScreen extends ConsumerStatefulWidget {
  const CustomerMarketplacePostScreen({required this.preview, super.key});

  /// The card the customer tapped, shown at once while the rest loads.
  final MarketplaceCard preview;

  @override
  ConsumerState<CustomerMarketplacePostScreen> createState() =>
      _CustomerMarketplacePostScreenState();
}

class _CustomerMarketplacePostScreenState
    extends ConsumerState<CustomerMarketplacePostScreen> {
  /// The colour / size chosen; the first on sale until the customer picks.
  String? _variantId;

  MarketplaceVariant? _variant(MarketplacePostDetail detail) {
    final onSale = detail.variants.where((v) => v.stock > 0).toList();
    if (onSale.isEmpty) return null;
    return onSale.firstWhere(
      (v) => v.id == _variantId,
      orElse: () => onSale.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(marketplacePostProvider(widget.preview.id));
    final detail = detailAsync.value;
    final card = detail?.card ?? widget.preview;

    return Scaffold(
      appBar: AppBar(title: Text(card.title)),
      bottomNavigationBar: detail == null ? null : _bottomBar(detail),
      body: detailAsync.when(
        loading: () => _Body(card: card),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorBanner(message: error.toString()),
          ),
        ),
        data: (detail) => _Body(
          card: detail.card,
          detail: detail,
          variant: _variant(detail),
          onVariant: (id) => setState(() => _variantId = id),
        ),
      ),
    );
  }

  /// Buy now: the sheet places the order; an online one is paid at once, then its page opens.
  Future<void> _buy(
    MarketplacePostDetail detail,
    MarketplaceVariant? variant,
  ) async {
    final order = await showMarketplaceOrderSheet(
      context,
      detail: detail,
      variant: variant,
    );
    if (order == null || !mounted) return;
    if (order.status == 'AwaitingPayment') {
      await payMarketplaceOnline(context, ref, order);
      if (!mounted) return;
    }
    await pushScreen(
      context,
      CustomerMarketplaceOrderScreen(orderId: order.id),
    );
  }

  Widget? _bottomBar(MarketplacePostDetail detail) {
    final theme = Theme.of(context);
    final variant = _variant(detail);
    final price = marketplacePrice(detail.card, price: variant?.price);
    final Widget? action = detail.canOrder
        ? FilledButton.icon(
            key: const ValueKey('marketplace-buy-now'),
            onPressed:
                detail.paymentMethods.isEmpty ||
                    (detail.variants.isNotEmpty && variant == null)
                ? null
                : () => _buy(detail, variant),
            icon: const Icon(Icons.shopping_bag_outlined),
            label: const Text('Buy now'),
          )
        : detail.canRequest
        ? FilledButton.icon(
            key: const ValueKey('marketplace-request-lot'),
            onPressed: () => showMarketplaceLotRequestSheet(context, detail),
            icon: const Icon(Icons.handshake_outlined),
            label: const Text('Request this lot'),
          )
        : null;
    if (action == null) return null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                price ?? '',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            action,
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.card, this.detail, this.variant, this.onVariant});

  final MarketplaceCard card;
  final MarketplacePostDetail? detail;
  final MarketplaceVariant? variant;
  final ValueChanged<String>? onVariant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = this.detail;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    // The colour chosen, in its own photos when it has any; else the product's.
    final own = variant?.imageUrls;
    final photos = own != null && own.isNotEmpty
        ? [for (final slot in own.keys.toList()..sort()) own[slot]!]
        : detail?.media ?? [?card.imageUrl];
    final was = card.originalPrice;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        PhotoGallery(
          // A new colour starts at its first photo.
          key: ValueKey('marketplace-gallery-${variant?.id}'),
          // An advert's photo is its 3 : 1 banner.
          aspectRatio: card.isAd ? 3 : 4 / 3,
          urls: [for (final p in photos) ?marketplacePhotoUrl(p)],
          overlay: Positioned(
            top: 8,
            right: 8,
            child: MarketplaceHeartButton(card: card),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (marketplacePrice(card, price: variant?.price)
                  case final price?) ...[
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    text: price,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                    children: [
                      if (was != null)
                        TextSpan(
                          text: '  ${rupees(was)}',
                          style: muted?.copyWith(
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                [card.categoryName, ?card.subCategoryName].join(' › '),
                style: muted,
              ),
              if (detail?.description case final text?
                  when text.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(text, style: theme.textTheme.bodyLarge),
              ],
              if (detail != null) ...[
                if (detail.variants.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text('Colour / size', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  _VariantChips(
                    variants: detail.variants,
                    chosen: variant,
                    onChosen: onVariant,
                  ),
                ],
                const SizedBox(height: 12),
                ..._facts(detail),
                if (card.isFood || card.isAd) ...[
                  const SizedBox(height: 12),
                  JobLocationCard(
                    key: const ValueKey('marketplace-post-place'),
                    caption: 'Where to go',
                    addressLines: [card.area, card.districtName],
                    latitude: card.latitude,
                    longitude: card.longitude,
                  ),
                ],
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

  List<Widget> _facts(MarketplacePostDetail detail) {
    final unit = card.priceUnit == null ? '' : ' ${card.priceUnit}';
    final phone = detail.contactPhone;
    return [
      if (card.isFood && card.quantity != null)
        FactRow(
          icon: Icons.restaurant_outlined,
          label: 'Left',
          value: '${card.quantity}',
        ),
      if (card.endsAt case final ends? when card.isFood || card.isAd)
        FactRow(
          icon: Icons.schedule_outlined,
          label: card.isFood ? 'Ends' : 'Runs till',
          value: '${formatDayMonth(ends)}, ${formatTime(ends)}',
        ),
      if (card.isWholesale) ...[
        if (card.minOrderQuantity case final least?)
          FactRow(
            icon: Icons.scale_outlined,
            label: 'Smallest order',
            value: '$least$unit',
          ),
        if (card.quantity case final available?)
          FactRow(
            icon: Icons.inventory_2_outlined,
            label: 'Available',
            value: '$available$unit',
          ),
      ],
      if (detail.packQuantity case final pack? when pack > 1)
        FactRow(
          icon: Icons.layers_outlined,
          label: 'In one item',
          value: '$pack pieces',
        ),
      for (final d in detail.details)
        FactRow(icon: Icons.label_outline, label: d.name, value: d.value),
      if (detail.canOrder)
        FactRow(
          icon: Icons.local_shipping_outlined,
          label: 'Delivers to',
          value: detail.deliversTo,
        ),
      if (detail.canOrder && detail.paymentMethods.isNotEmpty)
        FactRow(
          icon: Icons.payments_outlined,
          label: 'Pay',
          value: detail.paymentMethods.map((m) => m.name).join(' · '),
        ),
      FactRow(icon: Icons.place_outlined, label: 'From', value: card.placeName),
      if (phone != null && phone.isNotEmpty)
        Row(
          children: [
            Expanded(
              child: FactRow(
                icon: Icons.phone_outlined,
                label: 'Call about it',
                value: phone,
              ),
            ),
            CallIconButton(phoneNumber: phone, tooltip: 'Call'),
          ],
        ),
    ];
  }
}

/// The colours / sizes, each with how many are left; one run out cannot be picked.
class _VariantChips extends StatelessWidget {
  const _VariantChips({
    required this.variants,
    required this.chosen,
    required this.onChosen,
  });

  final List<MarketplaceVariant> variants;
  final MarketplaceVariant? chosen;
  final ValueChanged<String>? onChosen;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final v in variants)
        ChoiceChip(
          key: ValueKey('marketplace-variant-${v.id}'),
          label: Text(
            v.stock > 0
                ? '${v.name} · ${v.stock} left'
                : '${v.name} · sold out',
          ),
          selected: v.id == chosen?.id,
          onSelected: v.stock > 0 && v.id != null && onChosen != null
              ? (_) => onChosen!(v.id!)
              : null,
        ),
    ],
  );
}
