import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/router/push_screen.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/ui_config/ui_config.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:zuno/features/marketplace/presentation/screens/business_marketplace_tab.dart';
import 'package:zuno/features/marketplace/presentation/screens/marketplace_stock_screen.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/section_header.dart';
import 'package:zuno/shared/widgets/stat_tile.dart';

/// The Marketplace section of the business home screen, in four groups:
/// - Products: Live posts (every item live across the Marketplace), Inactive (everything not on
///   sale, expired food offers too) and Product stock.
/// - B2B: Live and B2B stock.
/// - Food: Live and Food remaining (portions).
/// - Ads: Live and Expired.
///
/// Each tile opens the posts behind its number. Counted by the Marketplace server, like the Rent
/// tiles beside it.
class MarketplaceDashboardTiles extends ConsumerWidget {
  const MarketplaceDashboardTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(marketplaceSummaryProvider);

    // Marketplace is its own server: if it cannot be reached, this section says so and the rest
    // of the home screen carries on.
    if (summaryAsync.hasError && !summaryAsync.hasValue) {
      return ErrorBanner(message: summaryAsync.error.toString());
    }

    final s = summaryAsync.value;
    // A dash while loading rather than a spinner, so the section keeps its shape.
    String count(int Function(MarketplaceSummary) of) =>
        s == null ? '–' : '${of(s)}';
    StatusTone some(int? n, StatusTone tone) =>
        (n ?? 0) > 0 ? tone : StatusTone.waiting;
    void open(
      String title, {
      String? status,
      String? kind,
      bool wholesale = false,
      bool inactive = false,
    }) => pushScreen(
      context,
      MarketplacePostListScreen(
        title: title,
        status: status,
        kind: kind,
        wholesale: wholesale,
        inactive: inactive,
      ),
    );
    Widget group(String name) => SectionHeader(
      title: UiConfig.current.label(dashboardSectionGroup, name),
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
    );
    // Stock tiles carry no number, as on Rent: the page they open has a tile per post.
    StatTile stock(String key, String label, IconData icon, Widget page) =>
        StatTile(
          key: ValueKey(key),
          label: label,
          value: '',
          icon: icon,
          tone: StatusTone.progress,
          onTap: () => pushScreen(context, page),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        group('Products'),
        StatTileGrid(
          tiles: [
            StatTile(
              key: const ValueKey('marketplace-tile-active'),
              label: 'Live posts',
              // Every item live across the Marketplace: a product's main colour / size and each
              // other one on sale, and each B2B post, food offer and advert.
              value: count((s) => s.liveCount),
              icon: Icons.storefront_outlined,
              tone: some(s?.liveCount, StatusTone.success),
              onTap: () =>
                  open('Live posts', status: MarketplacePostStatus.active),
            ),
            // Paused posts, colours / sizes switched off, and food offers whose time is over.
            StatTile(
              key: const ValueKey('marketplace-tile-inactive'),
              label: 'Inactive',
              value: count((s) => s.inactiveCount),
              icon: Icons.pause_circle_outline,
              tone: some(s?.inactiveCount, StatusTone.progress),
              onTap: () => open('Inactive', inactive: true),
            ),
            stock(
              'marketplace-tile-stock',
              'Product stock',
              Icons.inventory_outlined,
              const MarketplaceStockScreen(),
            ),
          ],
        ),
        group('B2B'),
        StatTileGrid(
          tiles: [
            StatTile(
              key: const ValueKey('marketplace-tile-b2b-live'),
              label: 'Live',
              value: count((s) => s.liveWholesale),
              icon: Icons.storefront_outlined,
              tone: some(s?.liveWholesale, StatusTone.success),
              onTap: () => open(
                'B2B live',
                status: MarketplacePostStatus.active,
                wholesale: true,
              ),
            ),
            stock(
              'marketplace-tile-b2b-stock',
              'B2B stock',
              Icons.local_shipping_outlined,
              const MarketplaceStockScreen(wholesale: true),
            ),
          ],
        ),
        group('Food'),
        StatTileGrid(
          tiles: [
            StatTile(
              key: const ValueKey('marketplace-tile-food-live'),
              label: 'Live',
              value: count((s) => s.liveFood),
              icon: Icons.restaurant_outlined,
              tone: some(s?.liveFood, StatusTone.success),
              onTap: () => open(
                'Food live',
                status: MarketplacePostStatus.active,
                kind: MarketplacePostKind.foodOffer,
              ),
            ),
            // Portions still offered in the food offers running now.
            StatTile(
              key: const ValueKey('marketplace-tile-food-left'),
              label: 'Food remaining',
              value: count((s) => s.foodPortionsLeft),
              icon: Icons.lunch_dining_outlined,
              tone: some(s?.foodPortionsLeft, StatusTone.progress),
              onTap: () => open(
                'Food remaining',
                status: MarketplacePostStatus.active,
                kind: MarketplacePostKind.foodOffer,
              ),
            ),
          ],
        ),
        group('Ads'),
        StatTileGrid(
          tiles: [
            StatTile(
              key: const ValueKey('marketplace-tile-ads-live'),
              label: 'Live',
              value: count((s) => s.liveAds),
              icon: Icons.campaign_outlined,
              tone: some(s?.liveAds, StatusTone.success),
              onTap: () => open(
                'Ads live',
                status: MarketplacePostStatus.active,
                kind: MarketplacePostKind.advertisement,
              ),
            ),
            StatTile(
              key: const ValueKey('marketplace-tile-ads-expired'),
              label: 'Expired',
              value: count((s) => s.expiredAds),
              icon: Icons.timer_off_outlined,
              // Asks for a look: an advert has run out and may want new dates.
              tone: some(s?.expiredAds, StatusTone.danger),
              onTap: () => open(
                'Ads expired',
                status: MarketplacePostStatus.expired,
                kind: MarketplacePostKind.advertisement,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
