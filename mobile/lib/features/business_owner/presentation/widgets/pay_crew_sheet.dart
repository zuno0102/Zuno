import 'package:zuno/core/utils/formatting.dart';
import 'package:flutter/material.dart';
import 'package:zuno/core/payments/razorpay_checkout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/domain/entities/payout_batch.dart';
import 'package:zuno/features/hiring_post/presentation/providers/business_hiring_posts_notifier.dart';

/// Pays a job's whole crew in one go.
///
/// The business reviews who is owed what, pays once, and every worker is sent their share.
/// One authorisation covers the lot — paying each worker separately would mean a PIN per
/// person, which stops being usable well before a crew of twenty.
///
/// The total shown is always the server's own figure. The sheet sends it back as a
/// cross-check so a stale card is refused rather than paid.
class PayCrewSheet extends ConsumerStatefulWidget {
  const PayCrewSheet({required this.post, super.key});

  final HiringPost post;

  static Future<bool?> show(BuildContext context, HiringPost post) =>
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => PayCrewSheet(post: post),
      );

  @override
  ConsumerState<PayCrewSheet> createState() => _PayCrewSheetState();
}

enum _Stage { review, paying, done }

class _PayCrewSheetState extends ConsumerState<PayCrewSheet> {
  _Stage _stage = _Stage.review;

  /// Crew the run could not include. Empty on every ordinary run.
  List<PayoutExclusion> _excluded = const [];
  PayoutBatch? _batch;
  String? _error;

  Future<void> _pay() async {
    setState(() {
      _stage = _Stage.paying;
      _error = null;
    });

    try {
      final notifier = ref.read(businessHiringPostsProvider.notifier);

      // Two steps on purpose. The first opens the run and locks in who is owed what; the
      // second confirms the money arrived and releases it to the crew. Keeping them apart is
      // what lets an interrupted run resume without anyone being paid twice.
      final opened = await notifier.startPayRun(
        postId: widget.post.id,
        expectedTotal: widget.post.outstandingAmount,
      );

      // Kept for the summary at the end. A run that skips somebody collects less than the job
      // owes, and the business must be able to see who was left out rather than be left working
      // out why the figure dropped.
      _excluded = opened.excludedPayees;

      var paymentId = opened.providerPaymentId ?? '';
      var signature = '';

      // A run reopened after a partial failure has already been paid for, so there is nothing
      // to collect — sending the business back to Checkout would charge them a second time.
      final keyId = opened.razorpayKeyId;
      final orderId = opened.providerOrderId;

      // A simulated run raised no order because it is collecting nothing, so there is no window
      // to open and nothing to sign. The crew is still disbursed to — simulated — which is what
      // makes the whole chain walkable on a phone, where Checkout cannot run at all.
      if (opened.fundedAt == null && !opened.nothingToCollect) {
        // Named explicitly rather than asserted with `!`. A missing key surfaced as a bare
        // TypeError, which told the business nothing about what to do next.
        if (keyId == null || orderId == null) {
          throw Exception(
            'This pay run has no Razorpay order attached, so payment cannot be opened. '
            'Reload the job and try again.',
          );
        }

        // Checkout is Razorpay's own window, so the sheet steps out of the way while it is up.
        if (!mounted) return;
        setState(() => _stage = _Stage.review);

        final result = await RazorpayCheckout.open(
          keyId: keyId,
          orderId: orderId,
          amount: opened.totalAmount,
          description:
              '${widget.post.title} — ${opened.items.length} worker(s)',
          businessName: widget.post.businessName,
        );

        paymentId = result.paymentId;
        signature = result.signature;

        if (!mounted) return;
        setState(() => _stage = _Stage.paying);
      }

      final settled = await notifier.payCrew(
        batchId: opened.id,
        providerPaymentId: paymentId,
        signature: signature,
      );

      if (!mounted) return;
      setState(() {
        _batch = settled;
        _stage = _Stage.done;
      });
    } on RazorpayCancelled catch (e) {
      // Backing out of Checkout is an ordinary thing to do, not a failure to shout about.
      if (!mounted) return;
      setState(() {
        _stage = _Stage.review;
        _error = e.toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.review;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: switch (_stage) {
        _Stage.review => _buildReview(theme),
        _Stage.paying => _buildPaying(theme),
        _Stage.done => _buildDone(theme),
      },
    );
  }

  Widget _buildReview(ThemeData theme) {
    final post = widget.post;
    final unpaid = post.applications
        .where((a) => a.status == 'Accepted' && a.paymentStatus != 'Paid')
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pay the crew', style: theme.textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(
          '${post.title} · ${post.outstandingLabel}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),

        Flexible(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final a in unpaid)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Expanded(child: Text(a.workerName)),
                        Text(
                          rupees(a.agreedSalaryAmount ?? 0),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        const Divider(height: 24),
        Row(
          children: [
            Expanded(
              child: Text('Total', style: theme.textTheme.titleMedium),
            ),
            Text(
              rupees(post.outstandingAmount),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'You authorise this once. Each worker is then sent their share '
            'automatically — no separate payment per person.',
            style: theme.textTheme.bodySmall,
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _pay,
            child: Text('Pay ${rupees(post.outstandingAmount)}'),
          ),
        ),
      ],
    );
  }

  Widget _buildPaying(ThemeData theme) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 44),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 20),
        Text('Sending each worker their share', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'This takes a moment',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );

  Widget _buildDone(ThemeData theme) {
    final batch = _batch!;
    final failed = batch.failedItems;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              failed.isEmpty ? Icons.check_circle : Icons.error_outline,
              color: failed.isEmpty
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                failed.isEmpty
                    ? '${batch.paidCount} workers paid'
                    : '${batch.paidCount} of ${batch.items.length} paid',
                style: theme.textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${rupees(batch.paidAmount)} sent in one payment',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),

        Flexible(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final item in batch.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          item.isPaid ? Icons.check : Icons.close,
                          size: 17,
                          color: item.isPaid
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.workerName),
                              if (item.destination != null)
                                Text(
                                  item.destination!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              // The provider's own words, kept verbatim so the business
                              // can act on it rather than guess.
                              if (item.failureReason != null)
                                Text(
                                  item.failureReason!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(rupees(item.amount)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        if (_excluded.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Not paid in this run — and not charged for',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                for (final e in _excluded)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${e.workerName} — ${e.reason}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (failed.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'This job is not settled until everyone is paid. Fix the details above '
              'and pay again — you are never charged twice for the same worker.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }
}
