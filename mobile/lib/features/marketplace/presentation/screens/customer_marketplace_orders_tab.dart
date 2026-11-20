import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_order.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_customer_providers.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_b2b_request_card.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_order_card.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_order_sheet.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_status_list.dart';
import 'package:zuno/shared/widgets/counted_tab_label.dart';
import 'package:zuno/shared/widgets/empty_state.dart';
import 'package:zuno/shared/widgets/filter_chip_bar.dart';

/// The customer's Marketplace orders: **Products** (what they bought, a chip per status they have)
/// and **B2B requests** (lots they asked for and the sellers' answers). Status names and colours
/// come from the server's tables, worded for the customer.
class CustomerMarketplaceOrdersTab extends ConsumerWidget {
  const CustomerMarketplaceOrdersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(myMarketplaceOrdersProvider()).value;
    final requests = ref.watch(myMarketplaceRequestsProvider).value;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          ListTabBar(
            labels: [
              CountedTabLabel(
                key: const ValueKey('my-marketplace-tab-products'),
                label: 'Products',
                count: orders?.allCount ?? 0,
              ),
              CountedTabLabel(
                key: const ValueKey('my-marketplace-tab-b2b'),
                label: 'B2B requests',
                count: requests?.totalCount ?? 0,
              ),
            ],
          ),
          const Expanded(
            child: TabBarView(children: [_MyOrders(), _MyRequests()]),
          ),
        ],
      ),
    );
  }
}

class _MyOrders extends ConsumerStatefulWidget {
  const _MyOrders();

  @override
  ConsumerState<_MyOrders> createState() => _MyOrdersState();
}

class _MyOrdersState extends ConsumerState<_MyOrders>
    with AutomaticKeepAliveClientMixin {
  String? _status;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final all = ref.watch(myMarketplaceOrdersProvider()).value;
    final page = myMarketplaceOrdersProvider(status: _status);
    // Only the statuses the customer has orders in, so the chips stay few.
    final counts = all?.counts ?? const <MarketplaceStatusCount>[];

    return MarketplaceStatusList<MarketplaceOrder>(
      chips: [
        CountChip(
          key: const ValueKey('my-marketplace-chip-all'),
          label: 'All',
          count: all?.allCount,
          selected: _status == null,
          onSelected: () => setState(() => _status = null),
        ),
        for (final c in counts)
          CountChip(
            key: ValueKey('my-marketplace-chip-${c.status}'),
            label: c.name ?? c.status,
            count: c.count,
            selected: _status == c.status,
            onSelected: () => setState(() => _status = c.status),
          ),
      ],
      items: ref.watch(page).whenData((p) => p.items),
      onRefresh: () async {
        reloadMyMarketplaceOrders(ref);
        await ref.read(page.future);
      },
      onRetry: () => ref.invalidate(page),
      empty: const EmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'No orders yet',
        message:
            'What you buy in Marketplace shows here, with where it is on its way.',
      ),
      itemBuilder: (order) =>
          MarketplaceOrderCard(order: order, forCustomer: true),
    );
  }
}

class _MyRequests extends ConsumerStatefulWidget {
  const _MyRequests();

  @override
  ConsumerState<_MyRequests> createState() => _MyRequestsState();
}

class _MyRequestsState extends ConsumerState<_MyRequests>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return MarketplaceStatusList<MarketplaceB2BRequest>(
      chips: const [],
      items: ref.watch(myMarketplaceRequestsProvider).whenData((p) => p.items),
      onRefresh: () => ref.refresh(myMarketplaceRequestsProvider.future),
      onRetry: () => ref.invalidate(myMarketplaceRequestsProvider),
      empty: const EmptyState(
        icon: Icons.handshake_outlined,
        title: 'No B2B requests yet',
        message:
            'Ask for a B2B lot from its page. The seller\'s answer shows here.',
      ),
      itemBuilder: (request) =>
          MarketplaceB2BRequestCard(request: request, forBuyer: true),
    );
  }
}
