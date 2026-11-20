import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/marketplace/data/marketplace_api.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_order.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_customer_providers.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_order_card.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_order_history.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_order_sheet.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/confirm_dialog.dart';
import 'package:zuno/shared/widgets/detail_row.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/star_rating_dialog.dart';
import 'package:zuno/shared/widgets/status_pill.dart';
import 'package:zuno/shared/widgets/step_progress_bar.dart';

/// The customer's own order: where it is on its way (a progress bar, as shops show it), what, where
/// it goes, how it is paid, the courier with Track — and what they can do now: pay, cancel before it
/// ships, rate it once delivered.
class CustomerMarketplaceOrderScreen extends ConsumerWidget {
  const CustomerMarketplaceOrderScreen({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(myMarketplaceOrderProvider(orderId));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          orderAsync.value == null
              ? 'Order'
              : 'Order #${orderAsync.value!.number}',
        ),
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ErrorBanner(message: error.toString()),
              TextButton.icon(
                onPressed: () =>
                    ref.invalidate(myMarketplaceOrderProvider(orderId)),
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
        data: (order) => RefreshIndicator(
          onRefresh: () =>
              ref.refresh(myMarketplaceOrderProvider(orderId).future),
          child: _Body(order: order),
        ),
      ),
    );
  }
}

/// The progress bar's stops for [order]: each step with the day it was reached. A cancelled order
/// ends in a red stop right after the last step it reached.
({List<ProgressStop> stops, int reached, int? stoppedAt}) marketplaceTrack(
  MarketplaceOrder order,
) {
  final track = order.track;
  final reached = track.lastIndexWhere((s) => s.reachedAt != null);
  ProgressStop stop(MarketplaceTrackStep s) => ProgressStop(
    label: s.name,
    caption: s.reachedAt == null ? null : formatDayMonth(s.reachedAt!),
  );

  if (!order.isCancelled || reached + 1 >= track.length) {
    return (
      stops: [for (final s in track) stop(s)],
      reached: reached,
      stoppedAt: null,
    );
  }
  final cancelledAt = order.cancelledAt;
  return (
    stops: [
      for (var i = 0; i < track.length; i++)
        i == reached + 1
            ? ProgressStop(
                label: order.statusName,
                caption: cancelledAt == null
                    ? null
                    : formatDayMonth(cancelledAt),
              )
            : stop(track[i]),
    ],
    reached: reached,
    stoppedAt: reached + 1,
  );
}

class _Body extends ConsumerWidget {
  const _Body({required this.order});

  final MarketplaceOrder order;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cancel this order?',
      message: order.isPaid
          ? 'The ${rupees(order.amount)} you paid goes back to your account.'
          : '${order.quantity} × ${order.titleWithVariant} will not be sent.',
      confirmLabel: 'Cancel order',
      cancelLabel: 'Keep it',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final messenger = AppMessenger.of(context);
    try {
      await ref.read(marketplaceCustomerRepositoryProvider).cancel(order.id);
      reloadMyMarketplaceOrders(ref);
      messenger.showSuccess('Order #${order.number} cancelled.');
    } catch (e) {
      messenger.showFailure(e.toString());
    }
  }

  Future<void> _rate(BuildContext context, WidgetRef ref) async {
    final input = await showStarRatingDialog(
      context,
      title: 'Rate ${order.titleWithVariant}',
    );
    if (input == null || !context.mounted) return;
    final messenger = AppMessenger.of(context);
    try {
      await ref
          .read(marketplaceCustomerRepositoryProvider)
          .review(order.id, input.score, input.comment);
      reloadMyMarketplaceOrders(ref);
      messenger.showSuccess('Thank you — your review is with the seller.');
    } catch (e) {
      messenger.showFailure(e.toString());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final note = marketplaceCustomerOrderNote(order);
    final image = order.imageUrl;
    final track = marketplaceTrack(order);
    // The steps the customer may take come from the server's table: Cancel only before it ships.
    final canCancel = order.actions.any((a) => a.toStatus == 'Cancelled');

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (image != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: MarketplaceApi.mediaUrl(image),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) =>
                      const SizedBox.square(dimension: 56),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${order.quantity} × ${order.titleWithVariant}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (order.sellerName case final seller?)
                    Text(seller, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            StatusPill(
              label: order.statusName,
              tone: marketplaceTone(order.statusTone),
            ),
          ],
        ),
        if (track.stops.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
              child: StepProgressBar(
                stops: track.stops,
                reached: track.reached,
                stoppedAt: track.stoppedAt,
              ),
            ),
          ),
        ],
        if (note != null) ...[
          const SizedBox(height: 10),
          Text(
            note,
            key: const ValueKey('marketplace-my-order-note'),
            style: theme.textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: 16),
        DetailRow(
          label: 'Deliver to',
          value: '${order.deliveryAddress} · ${order.pincode}',
        ),
        const SizedBox(height: 12),
        DetailRow(
          label: 'Quantity · Price',
          value:
              '${order.quantity} × ${rupees(order.unitPrice)} = ${rupees(order.amount)}',
        ),
        const SizedBox(height: 12),
        DetailRow(label: 'Payment', value: marketplaceOrderMoneyLine(order)),
        if (order.courierLine case final courier?) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DetailRow(label: 'Courier', value: courier),
              ),
              if (order.trackingUrl case final url?)
                TextButton.icon(
                  key: const ValueKey('marketplace-my-order-track'),
                  onPressed: () => launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Track'),
                ),
            ],
          ),
        ],
        if (order.ratingScore case final stars?) ...[
          const SizedBox(height: 12),
          DetailRow(
            label: 'Your review',
            value: order.ratingComment == null
                ? '$stars of 5'
                : '$stars of 5 · "${order.ratingComment}"',
          ),
        ],
        const SizedBox(height: 20),
        if (order.status == 'AwaitingPayment')
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FilledButton.icon(
              key: const ValueKey('marketplace-my-order-pay'),
              onPressed: () => payMarketplaceOnline(context, ref, order),
              icon: const Icon(Icons.payments_outlined),
              label: Text('Pay ${rupees(order.amount)}'),
            ),
          ),
        if (order.status == 'Delivered' && order.ratingScore == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FilledButton.icon(
              key: const ValueKey('marketplace-my-order-rate'),
              onPressed: () => _rate(context, ref),
              icon: const Icon(Icons.star_outline_rounded),
              label: const Text('Rate this order'),
            ),
          ),
        if (canCancel)
          OutlinedButton(
            key: const ValueKey('marketplace-my-order-cancel'),
            onPressed: () => _cancel(context, ref),
            child: const Text('Cancel order'),
          ),
        const SizedBox(height: 20),
        MarketplaceOrderHistory(events: order.events, forCustomer: true),
      ],
    );
  }
}
