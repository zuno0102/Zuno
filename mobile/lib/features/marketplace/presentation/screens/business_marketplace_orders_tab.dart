import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_order.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_order_providers.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:zuno/features/marketplace/presentation/screens/business_marketplace_tab.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_b2b_request_card.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_dashboard_tiles.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_order_card.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_status_list.dart';
import 'package:zuno/shared/widgets/counted_tab_label.dart';
import 'package:zuno/shared/widgets/empty_state.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/filter_chip_bar.dart';

/// Orders › Marketplace in sub-tabs by main category — Products · B2B · Food · Ads — the same bar
/// as Service's Bookings · Status management · Messages:
/// - Products: customers' orders, with a chip per order status (New … Delivered, Closed).
/// - B2B: buyers' requests, to accept or decline.
/// - Food and Ads: no orders — their posts, with the post status chips.
///
/// Category, status and courier names come from the server's tables; the counts cover every order,
/// not one page of them.
class BusinessMarketplaceOrdersTab extends ConsumerWidget {
  const BusinessMarketplaceOrdersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(marketplaceSummaryProvider).value;
    final orders = ref.watch(businessMarketplaceOrdersProvider()).value;
    final requests = ref.watch(businessB2BRequestsProvider()).value;
    final categories =
        ref.watch(marketplaceCategoriesProvider).value ??
        const <MarketplaceCategory>[];

    // One tab per group, in the category table's order: orders and requests belong to the group,
    // not to one category, so a second category in a group adds no second tab.
    final tabs = <String, MarketplaceCategory>{};
    for (final category in categories) {
      tabs.putIfAbsent(marketplaceDashboardGroup(category), () => category);
    }

    int countOf(String group, MarketplaceCategory category) => switch (group) {
      'Products' => orders?.allCount ?? 0,
      'B2B' => requests?.allCount ?? 0,
      _ => summary?.count(categoryId: category.id) ?? 0,
    };

    return DefaultTabController(
      // A new controller once the categories arrive: the tab count changes.
      key: ValueKey(tabs.length),
      length: tabs.length,
      child: Column(
        children: [
          ListTabBar(
            labels: [
              for (final MapEntry(key: group, value: category) in tabs.entries)
                CountedTabLabel(
                  key: ValueKey('marketplace-orders-category-${category.id}'),
                  label: category.shortName,
                  count: countOf(group, category),
                ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final MapEntry(key: group, value: category)
                    in tabs.entries)
                  switch (group) {
                    'Products' => const _ProductOrders(),
                    'B2B' => const _B2BRequests(),
                    _ => _CategoryPosts(category: category),
                  },
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The Products tab: customers' orders, narrowed by a status chip.
class _ProductOrders extends ConsumerStatefulWidget {
  const _ProductOrders();

  @override
  ConsumerState<_ProductOrders> createState() => _ProductOrdersState();
}

class _ProductOrdersState extends ConsumerState<_ProductOrders>
    with AutomaticKeepAliveClientMixin {
  String? _status;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final options = ref.watch(marketplaceOptionsProvider).value;
    final all = ref.watch(businessMarketplaceOrdersProvider()).value;
    final page = businessMarketplaceOrdersProvider(status: _status);
    final statuses = options?.orderStatuses ?? const <MarketplaceOption>[];

    return MarketplaceStatusList<MarketplaceOrder>(
      chips: [
        for (final status in [null, ...statuses])
          CountChip(
            key: ValueKey('marketplace-order-chip-${status?.code ?? 'all'}'),
            label: status?.name ?? 'All',
            count: status == null
                ? all?.allCount
                : _count(all?.counts, status.code),
            selected: _status == status?.code,
            onSelected: () => setState(() => _status = status?.code),
          ),
      ],
      items: ref.watch(page).whenData((p) => p.items),
      onRefresh: () async {
        reloadMarketplaceOrders(ref);
        await ref.read(page.future);
      },
      onRetry: () => ref.invalidate(page),
      empty: EmptyState(
        icon: Icons.receipt_long_outlined,
        title: _status == null
            ? 'No orders yet'
            : 'No ${(statuses.where((s) => s.code == _status).firstOrNull?.name ?? _status!).toLowerCase()} orders',
        message:
            'When customers order your products, the orders show here with the next step to take.',
      ),
      itemBuilder: (order) => MarketplaceOrderCard(order: order),
    );
  }
}

/// The B2B tab: buyers' requests on the business's lots, narrowed by a status chip.
class _B2BRequests extends ConsumerStatefulWidget {
  const _B2BRequests();

  @override
  ConsumerState<_B2BRequests> createState() => _B2BRequestsState();
}

class _B2BRequestsState extends ConsumerState<_B2BRequests>
    with AutomaticKeepAliveClientMixin {
  String? _status;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final options = ref.watch(marketplaceOptionsProvider).value;
    final all = ref.watch(businessB2BRequestsProvider()).value;
    final page = businessB2BRequestsProvider(status: _status);
    final statuses = options?.b2bRequestStatuses ?? const <MarketplaceOption>[];

    return MarketplaceStatusList<MarketplaceB2BRequest>(
      chips: [
        for (final status in [null, ...statuses])
          CountChip(
            key: ValueKey('marketplace-b2b-chip-${status?.code ?? 'all'}'),
            label: status?.name ?? 'All',
            count: status == null
                ? all?.allCount
                : _count(all?.counts, status.code),
            selected: _status == status?.code,
            onSelected: () => setState(() => _status = status?.code),
          ),
      ],
      items: ref.watch(page).whenData((p) => p.items),
      onRefresh: () async {
        reloadMarketplaceOrders(ref);
        await ref.read(page.future);
      },
      onRetry: () => ref.invalidate(page),
      empty: EmptyState(
        icon: Icons.handshake_outlined,
        title: _status == null ? 'No B2B requests yet' : 'No requests here',
        message:
            'When buyers ask for your B2B lots, their requests show here to accept or decline.',
      ),
      itemBuilder: (request) => MarketplaceB2BRequestCard(request: request),
    );
  }
}

int? _count(List<MarketplaceStatusCount>? counts, String status) =>
    counts?.where((c) => c.status == status).firstOrNull?.count ??
    (counts == null ? null : 0);

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
