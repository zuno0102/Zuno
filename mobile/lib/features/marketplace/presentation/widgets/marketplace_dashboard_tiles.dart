import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/router/push_screen.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:zuno/features/marketplace/presentation/screens/business_marketplace_tab.dart';
import 'package:zuno/features/marketplace/presentation/screens/marketplace_stock_screen.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/stat_tile.dart';

/// The Marketplace section of the business home screen: live, paused and expired posts, how much of
/// the plan is used, and Stock. Each tile opens the posts behind its number; Stock opens the products'
/// stock.
///
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
    // A dash while loading rather than a spinner, so the section keeps its shape.
    String count(int Function(MarketplaceSummary) of) =>
        s == null ? '–' : '${of(s)}';
    StatusTone some(int? n, StatusTone tone) =>
        (n ?? 0) > 0 ? tone : StatusTone.waiting;
    void open(String title, {String? status}) => pushScreen(
      context,
      MarketplacePostListScreen(title: title, status: status),
    );

    return StatTileGrid(
      tiles: [
        StatTile(
          key: const ValueKey('marketplace-tile-active'),
          label: 'Live posts',
          value: count((s) => s.active),
          icon: Icons.storefront_outlined,
          tone: some(s?.active, StatusTone.success),
          onTap: () => open('Live posts', status: MarketplacePostStatus.active),
        ),
        StatTile(
          key: const ValueKey('marketplace-tile-paused'),
          label: 'Paused',
          value: count((s) => s.paused),
          icon: Icons.pause_circle_outline,
          tone: some(s?.paused, StatusTone.progress),
          onTap: () => open('Paused', status: MarketplacePostStatus.paused),
        ),
        StatTile(
          key: const ValueKey('marketplace-tile-expired'),
          label: 'Expired',
          value: count((s) => s.expired),
          icon: Icons.timer_off_outlined,
          // Asks for a look: an offer or advert has run out and may want new dates.
          tone: some(s?.expired, StatusTone.danger),
          onTap: () => open('Expired', status: MarketplacePostStatus.expired),
        ),
        StatTile(
          key: const ValueKey('marketplace-tile-plan'),
          label: s == null ? 'Plan' : '${s.plan.name} plan',
          value: s == null
              ? '–'
              : '${s.plan.usedActivePosts} / ${s.plan.maxActivePosts}',
          icon: Icons.workspace_premium_outlined,
          tone: s == null || s.plan.canAddActivePost
              ? StatusTone.success
              : StatusTone.progress,
          onTap: () => open('Marketplace posts'),
        ),
        // One tile for all stock, and no number on it, as on Rent: the Stock page it opens has a
        // tile per product with its figures.
        StatTile(
          key: const ValueKey('marketplace-tile-stock'),
          label: 'Stock',
          value: '',
          icon: Icons.inventory_outlined,
          tone: StatusTone.progress,
          onTap: () => pushScreen(context, const MarketplaceStockScreen()),
        ),
      ],
    );
  }
}
