import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:zuno/features/marketplace/presentation/screens/business_marketplace_tab.dart';
import 'package:zuno/shared/widgets/counted_tab_label.dart';
import 'package:zuno/shared/widgets/empty_state.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/filter_chip_bar.dart';

/// Orders › Marketplace: the business's posts in sub-tabs by main category — All · Products · B2B ·
/// Food · Ads — the same bar as Service's Bookings · Status management · Messages. Each tab has
/// its status chips — Active, Paused, Expired, Closed, Sold — over the same cards and menu as
/// Services › Marketplace.
///
/// Category and status names come from the server's tables; the counts from the Marketplace
/// summary, so they cover every post, not one page of them.
class BusinessMarketplaceOrdersTab extends ConsumerWidget {
  const BusinessMarketplaceOrdersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(marketplaceSummaryProvider).value;
    final categories =
        ref.watch(marketplaceCategoriesProvider).value ??
        const <MarketplaceCategory>[];
    final tabs = <MarketplaceCategory?>[null, ...categories];

    return DefaultTabController(
      // A new controller once the categories arrive: the tab count changes.
      key: ValueKey(tabs.length),
      length: tabs.length,
      child: Column(
        children: [
          ListTabBar(
            labels: [
              for (final category in tabs)
                CountedTabLabel(
                  key: ValueKey(
                    'marketplace-orders-category-${category?.id ?? 'all'}',
                  ),
                  label: category?.shortName ?? 'All',
                  count: summary?.count(categoryId: category?.id) ?? 0,
                ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final category in tabs) _CategoryPosts(category: category),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One category tab: its posts, narrowed by a status chip.
class _CategoryPosts extends ConsumerStatefulWidget {
  const _CategoryPosts({required this.category});

  /// Null for every category.
  final MarketplaceCategory? category;

  @override
  ConsumerState<_CategoryPosts> createState() => _CategoryPostsState();
}

class _CategoryPostsState extends ConsumerState<_CategoryPosts>
    with AutomaticKeepAliveClientMixin {
  /// The status chosen; null for all.
  String? _status;

  /// Until the status table has loaded; then its rows decide the chips and their order.
  static const _order = [
    MarketplacePostStatus.active,
    MarketplacePostStatus.paused,
    MarketplacePostStatus.expired,
    MarketplacePostStatus.closed,
    MarketplacePostStatus.sold,
  ];

  // Each tab keeps its chosen chip and scroll place while another is looked at.
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final category = widget.category;
    final summary = ref.watch(marketplaceSummaryProvider).value;
    final options = ref.watch(marketplaceOptionsProvider).value;
    final posts = businessMarketplacePostsProvider(
      categoryId: category?.id,
      status: _status,
    );
    final postsAsync = ref.watch(posts);

    return RefreshIndicator(
      onRefresh: () async {
        reloadMarketplace(ref);
        await ref.read(posts.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          FilterChipBar(
            chips: [
              for (final status in [
                null,
                ...?options?.statuses.map((s) => s.code),
                if (options == null) ..._order,
              ])
                CountChip(
                  key: ValueKey('marketplace-orders-${status ?? 'all'}'),
                  label: status == null
                      ? 'All'
                      : options?.status(status)?.name ?? status,
                  count: summary?.count(
                    categoryId: category?.id,
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
                      title: _emptyTitle(options, category),
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
