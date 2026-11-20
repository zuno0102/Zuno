import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/payments/razorpay_checkout.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/business_plan/domain/business_plan.dart';
import 'package:zuno/features/business_plan/presentation/business_plan_providers.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/confirm_dialog.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/section_header.dart';

/// The business's plan and the plans it can buy, monthly or yearly. Prices are the Super Admin's.
class BusinessPlansScreen extends ConsumerStatefulWidget {
  const BusinessPlansScreen({super.key});

  @override
  ConsumerState<BusinessPlansScreen> createState() =>
      _BusinessPlansScreenState();
}

class _BusinessPlansScreenState extends ConsumerState<BusinessPlansScreen> {
  bool _annual = false;
  String? _buying;

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(businessPlanProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Plans')),
      body: plan.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ErrorBanner(message: error.toString()),
              TextButton.icon(
                onPressed: () => ref.invalidate(businessPlanProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
        data: (plan) => RefreshIndicator(
          onRefresh: () => ref.refresh(businessPlanProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _CurrentPlanCard(plan: plan),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                key: const ValueKey('plan-period'),
                segments: const [
                  ButtonSegment(value: false, label: Text('Monthly')),
                  ButtonSegment(value: true, label: Text('Annual · save more')),
                ],
                selected: {_annual},
                onSelectionChanged: (s) => setState(() => _annual = s.first),
              ),
              const SectionHeader(title: 'Plans'),
              for (final offer in plan.offers.where(
                (o) => o.isAnnual == _annual,
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OfferCard(
                    offer: offer,
                    saving: offer.isAnnual ? plan.annualSaving(offer) : null,
                    best: offer.areas.length == ListingArea.values.length,
                    busy: _buying == offer.id,
                    onBuy: _buying == null ? () => _buy(offer) : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Confirm, pay in Razorpay's window, and confirm with the server's signature check.
  Future<void> _buy(PlanOffer offer) async {
    final messenger = AppMessenger.of(context);
    final repository = ref.read(businessPlanRepositoryProvider);
    final agreed = await showConfirmDialog(
      context,
      title: 'Buy ${offer.name} · ${offer.period}?',
      message:
          'Unlimited ${_areasText(offer.areas)} listings for ${offer.durationDays} days. '
          'A plan is not refunded once paid.',
      confirmLabel: 'Pay ${rupees(offer.price)}',
      cancelLabel: 'Not now',
    );
    if (!agreed || !mounted) return;
    setState(() => _buying = offer.id);
    try {
      final payment = await repository.startPurchase(offer.id);
      String? paymentId;
      String? signature;
      if (!payment.nothingToCollect) {
        final keyId = payment.razorpayKeyId;
        final orderId = payment.providerOrderId;
        if (keyId == null || orderId == null) {
          throw Exception('The payment could not be opened. Please try again.');
        }
        final result = await RazorpayCheckout.open(
          keyId: keyId,
          orderId: orderId,
          amount: payment.amount,
          description: 'Zuno plan: ${payment.planName}',
          businessName: 'Zuno',
        );
        paymentId = result.paymentId;
        signature = result.signature;
      }
      final updated = await repository.confirmPurchase(
        payment.subscriptionId,
        paymentId: paymentId,
        signature: signature,
      );
      ref.invalidate(businessPlanProvider);
      messenger.showSuccess(
        '${updated.planName} is active till ${formatDate(updated.endsAt!)}.',
      );
    } on RazorpayCancelled catch (e) {
      messenger.showInfo(e.reason ?? 'Payment cancelled. Nothing was charged.');
    } catch (e) {
      messenger.showFailure(e.toString());
    } finally {
      if (mounted) setState(() => _buying = null);
    }
  }
}

String _areasText(Set<ListingArea> areas) => ListingArea.values
    .where(areas.contains)
    .map((a) => a.label.toLowerCase())
    .join(', ');

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.plan});

  final BusinessPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('current-plan'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current plan', style: theme.textTheme.labelMedium),
            const SizedBox(height: 2),
            Text(
              plan.isBasic
                  ? '${plan.planName} (free)'
                  : '${plan.planName} · till ${formatDate(plan.endsAt!)}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              plan.isBasic
                  ? '${plan.totalLive ?? '–'} of ${plan.basicLimit} live listing${plan.basicLimit == 1 ? '' : 's'} used, in any area.'
                  : 'Unlimited ${_areasText(plan.includes)} listings.',
              style: theme.textTheme.bodyMedium,
            ),
            if (plan.pausedCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${plan.pausedCount} listing${plan.pausedCount == 1 ? ' is' : 's are'} paused because a plan ended. '
                'Renew to bring ${plan.pausedCount == 1 ? 'it' : 'them'} back.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final usage in plan.areas)
                  Chip(
                    avatar: Icon(
                      usage.canAdd
                          ? Icons.lock_open_rounded
                          : Icons.lock_rounded,
                      size: 16,
                    ),
                    label: Text(
                      '${usage.area.label} · ${usage.liveCount ?? '–'} live',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.best,
    required this.busy,
    required this.onBuy,
    this.saving,
  });

  final PlanOffer offer;
  final bool best;
  final bool busy;
  final double? saving;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      key: ValueKey('plan-offer-${offer.code}'),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: best
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    best ? '${offer.name} · best value' : offer.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final area in ListingArea.values.where(
                        offer.includes,
                      ))
                        Chip(
                          label: Text(area.label),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  if (saving != null)
                    Text(
                      'Save ${rupees(saving!)} a year',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.tertiary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  rupees(offer.price),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  offer.isAnnual ? 'per year' : 'per month',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                FilledButton(
                  key: ValueKey('plan-buy-${offer.code}'),
                  onPressed: onBuy,
                  child: busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Buy'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
