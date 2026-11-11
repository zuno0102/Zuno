import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:zuno/features/marketplace/presentation/screens/business_marketplace_tab.dart';
import 'package:zuno/shared/widgets/empty_state.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/filter_chip_bar.dart';

/// Orders › Marketplace: the business's posts by where they stand — Active, Paused, Expired,
/// Closed — with the same cards and menu as Services › Marketplace, the way Status management sits
/// beside the Service orders.
///
/// Status names come from the server's status table; the counts from the Marketplace summary.
class BusinessMarketplaceOrdersTab extends ConsumerStatefulWidget {
  const BusinessMarketplaceOrdersTab({super.key});

  @override
  ConsumerState<BusinessMarketplaceOrdersTab> createState() =>
      _BusinessMarketplaceOrdersTabState();
}

class _BusinessMarketplaceOrdersTabState
    extends ConsumerState<BusinessMarketplaceOrdersTab> {
  /// The status chosen on the filter bar; null for all.
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
    final postsAsync = ref.watch(
      businessMarketplacePostsProvider(status: _status),
    );

    int? countOf(String? status) => summary == null
        ? null
        : switch (status) {
            MarketplacePostStatus.active => summary.active,
            MarketplacePostStatus.paused => summary.paused,
            MarketplacePostStatus.expired => summary.expired,
            MarketplacePostStatus.closed => summary.closed,
            _ =>
              summary.active +
                  summary.paused +
                  summary.expired +
                  summary.closed,
          };

    return RefreshIndicator(
      onRefresh: () async {
        reloadMarketplace(ref);
        await ref.read(
          businessMarketplacePostsProvider(status: _status).future,
        );
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          FilterChipBar(
            chips: [
              for (final status in [null, ..._order])
                CountChip(
                  key: ValueKey('marketplace-orders-${status ?? 'all'}'),
                  label: status == null
                      ? 'All'
                      : options?.status(status)?.name ?? status,
                  count: countOf(status),
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
                      onPressed: () => ref.invalidate(
                        businessMarketplacePostsProvider(status: _status),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ],
            data: (posts) => posts.isEmpty
                ? [
                    EmptyState(
                      icon: Icons.storefront_outlined,
                      title: _status == null
                          ? 'Nothing posted yet'
                          : 'No ${(options?.status(_status!)?.name ?? _status!).toLowerCase()} posts',
                      message:
                          'Add posts from Services › Marketplace. They show here by status.',
                    ),
                  ]
                : [
                    for (final post in posts)
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
}
