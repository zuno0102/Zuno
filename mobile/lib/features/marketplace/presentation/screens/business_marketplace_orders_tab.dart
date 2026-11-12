import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:zuno/features/marketplace/presentation/screens/business_marketplace_tab.dart';
import 'package:zuno/shared/widgets/empty_state.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/filter_chip_bar.dart';

/// Orders › Marketplace: the business's posts by main category — Products, B2B, Food, Ads — and by
/// where they stand — Active, Paused, Expired, Closed — with the same cards and menu as
/// Services › Marketplace, the way Status management sits beside the Service orders.
///
/// The two rows of chips combine: each count is for the other row's choice ("Food" chosen →
/// "Paused 1" means paused food posts). Category and status names come from the server's tables;
/// the counts from the Marketplace summary, so they cover every post, not one page of them.
class BusinessMarketplaceOrdersTab extends ConsumerStatefulWidget {
  const BusinessMarketplaceOrdersTab({super.key});

  @override
  ConsumerState<BusinessMarketplaceOrdersTab> createState() =>
      _BusinessMarketplaceOrdersTabState();
}

class _BusinessMarketplaceOrdersTabState
    extends ConsumerState<BusinessMarketplaceOrdersTab> {
  /// The main category chosen on the top row; null for all.
  String? _categoryId;

  /// The status chosen on the second row; null for all.
  String? _status;

  static const _order = [
    MarketplacePostStatus.active,
    MarketplacePostStatus.paused,
    MarketplacePostStatus.expired,
    MarketplacePostStatus.closed,
  ];

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(marketplaceSummaryProvider).value;
    final options = ref.watch(marketplaceOptionsProvider).value;
    final categories =
        ref.watch(marketplaceCategoriesProvider).value ??
        const <MarketplaceCategory>[];
    final posts = businessMarketplacePostsProvider(
      categoryId: _categoryId,
      status: _status,
    );
    final postsAsync = ref.watch(posts);
    final chosenCategory = categories
        .where((c) => c.id == _categoryId)
        .firstOrNull;

    return RefreshIndicator(
      onRefresh: () async {
        reloadMarketplace(ref);
        await ref.read(posts.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (categories.isNotEmpty)
            FilterChipBar(
              chips: [
                for (final category in [null, ...categories])
                  CountChip(
                    key: ValueKey(
                      'marketplace-orders-category-${category?.id ?? 'all'}',
                    ),
                    label: category?.shortName ?? 'All',
                    count: summary?.count(
                      categoryId: category?.id,
                      status: _status,
                    ),
                    selected: _categoryId == category?.id,
                    onSelected: () =>
                        setState(() => _categoryId = category?.id),
                  ),
              ],
            ),
          FilterChipBar(
            chips: [
              for (final status in [null, ..._order])
                CountChip(
                  key: ValueKey('marketplace-orders-${status ?? 'all'}'),
                  label: status == null
                      ? 'All'
                      : options?.status(status)?.name ?? status,
                  count: summary?.count(
                    categoryId: _categoryId,
                    status: status,
                  ),
                  selected: _status == status,
                  onSelected: () => setState(() => _status = status),
                ),
            ],
          ),
          ...postsAsync.when(
            loading: () => const [
              Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (error, _) => [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ErrorBanner(message: error.toString()),
                    TextButton.icon(
                      onPressed: () => ref.invalidate(posts),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ],
            data: (list) => list.isEmpty
                ? [
                    EmptyState(
                      icon: Icons.storefront_outlined,
                      title: _emptyTitle(options, chosenCategory),
                      message:
                          'Add posts from Services › Marketplace. They show here by category and status.',
                    ),
                  ]
                : [
                    for (final post in list)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: MarketplacePostCard(post: post),
                      ),
                  ],
          ),
        ],
      ),
    );
  }

  /// "Nothing posted yet", "No paused posts", "Nothing in Nearby food yet",
  /// "No paused posts in Nearby food".
  String _emptyTitle(
    MarketplaceOptions? options,
    MarketplaceCategory? category,
  ) {
    final status = _status;
    final where = category == null ? '' : ' in ${category.name}';
    if (status == null) {
      return category == null ? 'Nothing posted yet' : 'Nothing$where yet';
    }
    final name = (options?.status(status)?.name ?? status).toLowerCase();
    return 'No $name posts$where';
  }
}
