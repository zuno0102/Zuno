import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/hiring_post/presentation/providers/hiring_post_providers.dart';
import 'package:zuno/features/worker/domain/entities/worker_dashboard.dart';
import 'package:zuno/features/worker/presentation/providers/worker_dashboard_notifier.dart';
import 'package:zuno/shared/widgets/empty_state.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/status_pill.dart';
import 'package:zuno/shared/widgets/app_messages.dart';

/// Every wage a worker has earned and not received, and the place they answer for it.
///
/// This is the one route to confirming or disputing a payment, so it is reached in a single tap from
/// the awaiting-payment card on Home and nowhere further. It used to sit inline on the dashboard,
/// below the profile and the chart, which is how a worker owed money ended up scrolling past three
/// other cards to say they had never been paid.
///
/// Reads the dashboard rather than taking a list, so answering a row here refreshes what is on screen
/// instead of leaving a settled payment sitting in a stale copy.
class WorkerPaymentsScreen extends ConsumerWidget {
  const WorkerPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(workerDashboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Awaiting payment')),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorBanner(message: error.toString()),
          ),
        ),
        data: (dashboard) {
          if (dashboard.pendingPayments.isEmpty) {
            return const EmptyState(
              icon: Icons.verified_outlined,
              title: 'Nothing waiting',
              message:
                  'Every wage you have earned has been paid. Anything still owed will appear '
                  'here as soon as the work is finished.',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _Total(dashboard: dashboard),
              const SizedBox(height: 14),
              Text(
                // Said once, above the rows, because the two buttons on each row are the point of
                // this screen and a worker should know what they do before using them.
                'Say whether the money reached your account. Reporting a wage as unpaid keeps the '
                'job open and flags the business.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              for (final payment in dashboard.pendingPayments)
                PendingPaymentRow(payment: payment),
            ],
          );
        },
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.dashboard});

  final WorkerDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppColors.status(StatusTone.progress, theme.brightness);
    final jobs = dashboard.pendingPayments.length;

    return Card(
      margin: EdgeInsets.zero,
      color: accent.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 30,
              color: accent,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rupees(dashboard.pendingPaymentTotal),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                  Text(
                    jobs == 1
                        ? 'owed on one finished job'
                        : 'owed across $jobs finished jobs',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A wage that has not arrived, and the worker's answer to it.
///
/// The business marking someone paid is only its own word, and a payout provider reporting success
/// says the instruction was accepted rather than that money landed. The person whose account it
/// should have reached is the one who knows — so this is what finally closes a payment, and
/// reporting it missing is what holds the job open against the business.
class PendingPaymentRow extends ConsumerStatefulWidget {
  const PendingPaymentRow({required this.payment, super.key});

  final WorkerPendingPayment payment;

  @override
  ConsumerState<PendingPaymentRow> createState() => _PendingPaymentRowState();
}

class _PendingPaymentRowState extends ConsumerState<PendingPaymentRow> {
  bool _isResponding = false;

  Future<void> _respond({required bool received}) async {
    String? reason;

    if (!received) {
      final controller = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Report this as unpaid'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'The business will be told the money has not reached you.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Anything to add (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Report it'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;
      reason = controller.text.trim().isEmpty ? null : controller.text.trim();
    }

    setState(() => _isResponding = true);

    // Captured before the await: the reload below can dispose this row while the call is in flight.
    final messenger = AppMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);

    try {
      await container
          .read(hiringPostRepositoryProvider)
          .respondToPayment(
            applicationId: widget.payment.applicationId,
            received: received,
            disputeReason: reason,
          );

      // The dashboard carries this figure, so it has to be reloaded for the row to clear.
      container.invalidate(workerDashboardProvider);

      messenger.showSuccess(
        received ? 'Thanks — marked as received.' : 'Reported as unpaid.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResponding = false);
      messenger.showFailure(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payment = widget.payment;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payment.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    payment.businessName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (payment.workCompletedAt != null)
                    Text(
                      'Finished ${formatDate(payment.workCompletedAt!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rupees(payment.amount),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                StatusPill(
                  label: payment.stateLabel,
                  tone: payment.stateTone,
                  compact: true,
                ),
                if (_isResponding)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else ...[
                  const SizedBox(height: 6),
                  // Offered whatever the state: a worker who was never paid must be able to say so
                  // without waiting for the business to claim it was sent.
                  TextButton(
                    onPressed: () => _respond(received: true),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Got it'),
                  ),
                  TextButton(
                    onPressed: () => _respond(received: false),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      foregroundColor: theme.colorScheme.error,
                    ),
                    child: const Text('Not paid'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
