import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/core/utils/upload_image.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zuno/features/marketplace/data/marketplace_api.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_order.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_order_providers.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_order_card.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_order_history.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/call_icon_button.dart';
import 'package:zuno/shared/widgets/detail_row.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/status_pill.dart';

/// One product order: who ordered what, where it goes, how it is paid, the courier, the history,
/// and the next step.
class MarketplaceOrderDetailScreen extends ConsumerWidget {
  const MarketplaceOrderDetailScreen({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(businessMarketplaceOrderProvider(orderId));
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
                    ref.invalidate(businessMarketplaceOrderProvider(orderId)),
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
        data: (order) => RefreshIndicator(
          onRefresh: () =>
              ref.refresh(businessMarketplaceOrderProvider(orderId).future),
          child: _Body(order: order),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.order});

  final MarketplaceOrder order;

  Future<void> _addReceipt(BuildContext context, WidgetRef ref) async {
    final messenger = AppMessenger.of(context);
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    try {
      final bytes = await compressForUpload(
        await picked.readAsBytes(),
        ref.read(currentAppOptionsProvider),
      );
      await ref
          .read(marketplaceOrderRepositoryProvider)
          .uploadReceipt(order.id, bytes);
      reloadMarketplaceOrders(ref);
      messenger.showSuccess('Receipt photo saved.');
    } catch (e) {
      messenger.showFailure(e.toString());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final note = marketplaceOrderNote(order);
    final receipt = order.receiptUrl;
    // Every shipped order carries its courier and number.
    final shipped = order.courierLine != null && order.status != 'Cancelled';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '${order.quantity} × ${order.titleWithVariant}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            StatusPill(
              label: order.statusName,
              tone: marketplaceTone(order.statusTone),
            ),
          ],
        ),
        if (note != null) ...[
          const SizedBox(height: 6),
          Text(note, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DetailRow(
                label: 'Customer',
                value: '${order.customerName} · ${order.customerPhone}',
              ),
            ),
            if (order.customerPhone.isNotEmpty)
              CallIconButton(
                phoneNumber: order.customerPhone,
                tooltip: 'Call customer',
              ),
          ],
        ),
        const SizedBox(height: 12),
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
        DetailRow(
          key: const ValueKey('marketplace-order-payment'),
          label: 'Payment',
          value: marketplaceOrderMoneyLine(order),
        ),
        if (order.dueToBusiness > 0) ...[
          const SizedBox(height: 12),
          DetailRow(
            key: const ValueKey('marketplace-order-due'),
            label: 'Due to you',
            value:
                '${rupees(order.dueToBusiness)} · Zuno collected it online and pays it to you',
          ),
        ],
        if (order.courierLine case final courier?) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DetailRow(label: 'Courier', value: courier),
              ),
              if (order.trackingUrl case final url?)
                TextButton.icon(
                  key: const ValueKey('marketplace-order-track'),
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
        if (shipped) ...[
          const SizedBox(height: 12),
          if (receipt != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: MarketplaceApi.mediaUrl(receipt),
                height: 160,
                fit: BoxFit.cover,
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('marketplace-order-add-receipt'),
              onPressed: () => _addReceipt(context, ref),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(
                receipt == null
                    ? 'Add a photo of the courier receipt'
                    : 'Change the receipt photo',
              ),
            ),
          ),
        ],
        if (order.ratingScore case final stars?) ...[
          const SizedBox(height: 12),
          DetailRow(
            label: "Customer's review",
            value: order.ratingComment == null
                ? '$stars of 5'
                : '$stars of 5 · "${order.ratingComment}"',
          ),
        ],
        if (order.actions.isNotEmpty) ...[
          const SizedBox(height: 20),
          for (final action in order.actions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FilledButton(
                key: ValueKey('marketplace-order-step-${action.toStatus}'),
                onPressed: () =>
                    runMarketplaceOrderAction(context, ref, order, action),
                child: Text(action.name),
              ),
            ),
        ],
        const SizedBox(height: 20),
        MarketplaceOrderHistory(events: order.events),
      ],
    );
  }
}
