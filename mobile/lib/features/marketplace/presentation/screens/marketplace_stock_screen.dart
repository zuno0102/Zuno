import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/router/push_screen.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:zuno/features/marketplace/presentation/screens/marketplace_stock_item_screen.dart';
import 'package:zuno/shared/widgets/empty_state.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/stock_figure_row.dart';

/// Stock: a tile per new product the business sells, each with how many are in stock, its colours
/// and sizes, and how many of those have run out. Opened from the Stock tile on the home screen, the
/// way Rent's Stock page is.
class MarketplaceStockScreen extends ConsumerWidget {
  const MarketplaceStockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockAsync = ref.watch(marketplaceStockProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Stock')),
      body: stockAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ErrorBanner(message: error.toString()),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => ref.invalidate(marketplaceStockProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return const EmptyState(
              icon: Icons.inventory_outlined,
              title: 'No stock yet',
              message:
                  'Add a new product on the Marketplace and its stock shows here.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              reloadMarketplace(ref);
              await ref.read(marketplaceStockProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // Two to a row: each tile carries its figures and a name that can be long.
                for (var start = 0; start < posts.length; start += 2) ...[
                  if (start > 0) const SizedBox(height: 10),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: MarketplaceStockTile(post: posts[start]),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: start + 1 < posts.length
                              ? MarketplaceStockTile(post: posts[start + 1])
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// How many of each line a product has run out of: its colours and sizes on sale at 0, or the
/// product itself when it has one stock count. An inactive one is not on sale, so not run out.
int marketplaceLinesOut(MarketplacePost post) => post.variants.isEmpty
    ? ((post.quantity ?? 0) <= 0 ? 1 : 0)
    : post.variants.where((v) => v.isActive && v.stock <= 0).length;

/// One product's stock: its name, then in stock, colours / sizes and run out. Opens its Stock and
/// Orders.
class MarketplaceStockTile extends StatelessWidget {
  const MarketplaceStockTile({required this.post, super.key});

  final MarketplacePost post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final out = marketplaceLinesOut(post);

    return Card(
      key: ValueKey('marketplace-stock-${post.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            pushScreen(context, MarketplaceStockItemScreen(postId: post.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (post.status != MarketplacePostStatus.active)
                Text(
                  'Not shown to customers now',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 8),
              StockFigureRow(
                label: 'In stock',
                value: post.quantity ?? 0,
                tone: (post.quantity ?? 0) > 0
                    ? StatusTone.success
                    : StatusTone.danger,
              ),
              if (post.variants.isNotEmpty)
                StockFigureRow(
                  label: 'Colours / sizes',
                  value: post.variants.length,
                ),
              StockFigureRow(
                label: 'Run out',
                value: out,
                tone: out > 0 ? StatusTone.danger : StatusTone.waiting,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
