import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_order.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_order_providers.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_order_card.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/call_icon_button.dart';
import 'package:zuno/shared/widgets/confirm_dialog.dart';
import 'package:zuno/shared/widgets/status_pill.dart';
import 'package:zuno/shared/widgets/status_with_actions.dart';

/// One B2B request on the business's lot: who asks, how much, their note — and Accept or Decline.
/// Once accepted the buyer's contact shows here; the buyer sees the business's while their B2B plan
/// runs. Nothing more happens in the app: the two talk directly.
class MarketplaceB2BRequestCard extends ConsumerWidget {
  const MarketplaceB2BRequestCard({required this.request, super.key});

  final MarketplaceB2BRequest request;

  Future<void> _answer(
    BuildContext context,
    WidgetRef ref, {
    required bool accept,
  }) async {
    if (!accept) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Decline this request?',
        message:
            '${request.buyerName} asked for ${request.quantityLine} of ${request.title}.',
        confirmLabel: 'Decline',
        destructive: true,
      );
      if (!confirmed || !context.mounted) return;
    }

    final messenger = AppMessenger.of(context);
    try {
      await ref
          .read(marketplaceOrderRepositoryProvider)
          .answerB2BRequest(request.id, accept: accept);
      reloadMarketplaceOrders(ref);
      messenger.showSuccess(
        accept
            ? 'Accepted. You can now call ${request.buyerName}.'
            : 'Request declined.',
      );
    } catch (e) {
      messenger.showFailure(e.toString());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final phone = request.buyerPhone;

    return Card(
      key: ValueKey('marketplace-b2b-request-${request.id}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        request.buyerName,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '#${request.number} · ${formatDayMonth(request.createdDate)}',
                        style: muted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusWithActions(
                  status: StatusPill(
                    label: request.statusName,
                    tone: marketplaceTone(request.statusTone),
                    compact: true,
                  ),
                  actions: [
                    if (phone != null)
                      CallIconButton(
                        phoneNumber: phone,
                        tooltip: 'Call ${request.buyerName}',
                        iconSize: 22,
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                request.total == null || request.unitPrice == null
                    ? request.quantityLine
                    : '${request.quantityLine} × ${rupees(request.unitPrice!)} = ${rupees(request.total!)}',
                if (request.minOrderQuantity case final least?)
                  'smallest order $least${request.unit == null ? '' : ' ${request.unit}'}',
              ].join(' · '),
              key: ValueKey('marketplace-b2b-quantity-${request.id}'),
              style: theme.textTheme.bodyMedium,
            ),
            if (request.message case final message?) ...[
              const SizedBox(height: 4),
              Text('"$message"', style: muted),
            ],
            const SizedBox(height: 8),
            if (request.isAccepted && phone != null)
              _ContactBox(name: request.buyerName, phone: phone)
            else if (request.isNew)
              Text('Contact details show once you accept.', style: muted)
            else if (request.isAccepted)
              Text('Accepted. The buyer gave no phone number.', style: muted),
            if (request.isAccepted) ...[
              const SizedBox(height: 6),
              Text(
                'The buyer sees your contact while their B2B plan is active.',
                style: muted,
              ),
            ],
            if (request.isNew) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: ValueKey('marketplace-b2b-decline-${request.id}'),
                      onPressed: () => _answer(context, ref, accept: false),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      key: ValueKey('marketplace-b2b-accept-${request.id}'),
                      onPressed: () => _answer(context, ref, accept: true),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContactBox extends StatelessWidget {
  const _ContactBox({required this.name, required this.phone});

  final String name;
  final String phone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              'Buyer: $name\n$phone',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          IconButton(
            tooltip: 'Copy number',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () async {
              final messenger = AppMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: phone));
              messenger.showSuccess('Number copied.');
            },
          ),
        ],
      ),
    );
  }
}
