import 'package:zuno/core/utils/formatting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/worker/domain/entities/worker_profile.dart';
import 'package:zuno/features/worker/presentation/providers/worker_providers.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/section_header.dart';
import 'package:zuno/shared/widgets/status_pill.dart';
import 'package:zuno/shared/widgets/trust_cards.dart';

/// The worker's own profile — the tab that did not exist.
///
/// Getting paid comes first, before earnings or history: a worker with no verified payout
/// destination cannot be paid at all, and that fact was previously invisible.
class WorkerProfileTab extends ConsumerWidget {
  const WorkerProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(workerProfileProvider);

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorBanner(message: error.toString()),
        ),
      ),
      data: (profile) => RefreshIndicator(
        onRefresh: () => ref.refresh(workerProfileProvider.future),
        child: _WorkerProfileBody(profile: profile),
      ),
    );
  }
}

class _WorkerProfileBody extends StatelessWidget {
  const _WorkerProfileBody({required this.profile});

  final WorkerProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = AppColors.status(StatusTone.success, theme.brightness);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (profile.needsPayoutSetup) _PayoutWarning(profile: profile),

        TrustCard(
          title: 'Getting paid',
          headline: profile.canReceivePayouts ? '✓' : '—',
          caption: profile.canReceivePayouts
              ? 'ready to receive\nwages'
              : 'not set up to\nreceive wages',
          rows: [
            TrustRow(
              'UPI',
              profile.maskedUpi ?? 'Not added',
              muted: profile.maskedUpi == null,
            ),
            TrustRow(
              'Status',
              profile.payoutVerificationStatus,
              tone: profile.canReceivePayouts ? tone : theme.colorScheme.error,
            ),
            if (profile.jobsCompleted > 0)
              TrustRow(
                'Received on time',
                '${profile.jobsPaid} of ${profile.jobsCompleted} jobs',
                tone: profile.jobsPaid == profile.jobsCompleted ? tone : null,
              ),
          ],
        ),

        TrustCard(
          title: 'Your work record',
          headline: '${profile.jobsPaid}',
          caption: 'jobs completed\nand paid',
          rows: [
            TrustRow('Total earned', rupees(profile.totalEarned)),
            if (profile.averageSalary case final average?)
              TrustRow('Average per job', rupees(average)),
            TrustRow('Businesses worked for', '${profile.businessesWorkedFor}'),
            TrustRow('Offers declined', '${profile.offersDeclined}'),
            if (profile.openDisputes > 0)
              TrustRow(
                'Unpaid reports open',
                '${profile.openDisputes}',
                tone: theme.colorScheme.error,
              ),
          ],
        ),

        if (profile.owedToYou > 0)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(
                Icons.account_balance_wallet_outlined,
                color: AppColors.status(StatusTone.progress, theme.brightness),
              ),
              title: Text('${rupees(profile.owedToYou)} owed to you'),
              subtitle: const Text('On work you have already finished.'),
            ),
          ),

        const SectionHeader(title: 'Skills & rate', padding: EdgeInsets.fromLTRB(0, 8, 0, 8)),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              _InfoRow(label: 'Experience', value: profile.experienceLabel),
              _InfoRow(
                label: 'Hourly rate',
                value: profile.hourlyRate == null
                    ? 'Not set'
                    : rupees(profile.hourlyRate!),
              ),
              _InfoRow(
                label: 'Availability',
                trailing: StatusPill(
                  label: profile.availabilityStatus,
                  tone: profile.isAvailable
                      ? StatusTone.success
                      : StatusTone.waiting,
                  compact: true,
                ),
              ),
              _InfoRow(
                label: 'Verification',
                trailing: StatusPill(
                  label: profile.verificationStatus,
                  tone: verificationTone(profile.verificationStatus),
                  compact: true,
                ),
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Account', padding: EdgeInsets.fromLTRB(0, 20, 0, 8)),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              _InfoRow(label: 'Name', value: profile.fullName),
              _InfoRow(label: 'Email', value: profile.email),
              _InfoRow(label: 'Phone', value: profile.phoneNumber ?? 'Not set'),
            ],
          ),
        ),
      ],
    );
  }
}

/// Not a nicety: without a verified destination the payout handler refuses, so the wages simply
/// never arrive and nothing on screen explains why.
class _PayoutWarning extends StatelessWidget {
  const _PayoutWarning({required this.profile});

  final WorkerProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final danger = theme.colorScheme.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: danger.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: danger.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 19, color: danger),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              profile.hasPayoutDestination
                  ? 'Your UPI is still being verified. Wages cannot be sent until it clears.'
                  : 'Add your UPI to get paid. Until you do, a business cannot send you wages '
                        'even after you have finished the work.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: danger,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, this.value, this.trailing});

  final String label;
  final String? value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      dense: true,
      title: Text(label, style: theme.textTheme.bodyMedium),
      trailing:
          trailing ??
          Text(
            value ?? '',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
    );
  }
}
