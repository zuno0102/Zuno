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

/// The Home group a category's posts count in — its label code: Food and Ads by kind, B2B for a
/// wholesale-only category, Products for the rest.
String marketplaceDashboardGroup(MarketplaceCategory category) =>
    switch (category.kind) {
      MarketplacePostKind.foodOffer => 'Food',
      MarketplacePostKind.advertisement => 'Ads',
      _ when category.isWholesaleOnly => 'B2B',
      _ => 'Products',
    };

/// The Marketplace section of the business home screen, in four groups, each counting only its own
/// posts:
/// - Products: Live posts and Inactive (item by item: a product's main colour / size and each
///   other one), and Product stock.
/// - B2B: Live, Inactive and B2B stock.
/// - Food: Live, Inactive (switched off or its time over) and Food remaining (portions).
/// - Ads: Live, Inactive and Expired.
///
/// Only the groups the business has posted in show. Each tile opens the posts behind its number.
/// Counted by the Marketplace server, like the Rent tiles beside it.
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
    final categories = ref.watch(marketplaceCategoriesProvider).value;
    // Only the groups the business has posted in — by each category's kind and how it sells, from
    // the category table. All four until the posts and the categories are known.
    final used = s == null || categories == null
        ? null
        : {
            for (final c in categories)
              if (s.count(categoryId: c.id) > 0) marketplaceDashboardGroup(c),
          };
    bool shows(String group) => used == null || used.contains(group);
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
      bool products = false,
      bool inactive = false,
    }) => pushScreen(
      context,
      MarketplacePostListScreen(
        title: title,
        status: status,
        kind: kind,
        wholesale: wholesale,
        products: products,
        inactive: inactive,
      ),
    );
    Widget group(String name) => SectionHeader(
      title: UiConfig.current.label(dashboardSectionGroup, name),
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
    );
    // A group's Inactive tile: what is not on show in that group, opening those posts.
    StatTile inactiveTile(
      String key,
      String title,
      int Function(MarketplaceSummary) of, {
      String? kind,
      bool wholesale = false,
      bool products = false,
    }) => StatTile(
      key: ValueKey(key),
      label: 'Inactive',
      value: count(of),
      icon: Icons.pause_circle_outline,
      tone: some(s == null ? null : of(s), StatusTone.progress),
      onTap: () => open(
        title,
        kind: kind,
        wholesale: wholesale,
        products: products,
        inactive: true,
      ),
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
        if (shows('Products')) ...[
          group('Products'),
          StatTileGrid(
            tiles: [
              StatTile(
                key: const ValueKey('marketplace-tile-active'),
                label: 'Live posts',
                // Products only, item by item: a product's main colour / size and each other one
                // on sale. B2B, food and ads count in their own groups.
                value: count((s) => s.liveCount),
                icon: Icons.storefront_outlined,
                tone: some(s?.liveCount, StatusTone.success),
                onTap: () => open(
                  'Live products',
                  status: MarketplacePostStatus.active,
                  products: true,
                ),
              ),
              // Paused products and colours / sizes switched off, item by item.
              inactiveTile(
                'marketplace-tile-inactive',
                'Inactive products',
                (s) => s.inactiveCount,
                products: true,
              ),
              stock(
                'marketplace-tile-stock',
                'Product stock',
                Icons.inventory_outlined,
                const MarketplaceStockScreen(),
              ),
            ],
          ),
        ],
        if (shows('B2B')) ...[
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
              inactiveTile(
                'marketplace-tile-b2b-inactive',
                'B2B inactive',
                (s) => s.inactiveWholesale,
                wholesale: true,
              ),
              stock(
                'marketplace-tile-b2b-stock',
                'B2B stock',
                Icons.local_shipping_outlined,
                const MarketplaceStockScreen(wholesale: true),
              ),
            ],
          ),
        ],
        if (shows('Food')) ...[
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
              // Switched off, or its time is over.
              inactiveTile(
                'marketplace-tile-food-inactive',
                'Food inactive',
                (s) => s.inactiveFood,
                kind: MarketplacePostKind.foodOffer,
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
        ],
        if (shows('Ads')) ...[
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
              inactiveTile(
                'marketplace-tile-ads-inactive',
                'Ads inactive',
                (s) => s.inactiveAds,
                kind: MarketplacePostKind.advertisement,
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
      ],
    );
  }
}
