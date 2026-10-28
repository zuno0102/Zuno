import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy.dart';
import 'package:zuno/features/vacancy/presentation/providers/business_vacancies_notifier.dart';
import 'package:zuno/features/vacancy/presentation/screens/vacancy_applicants_screen.dart';
import 'package:zuno/features/vacancy/presentation/widgets/vacancy_form_sheet.dart';
import 'package:zuno/features/vacancy/presentation/widgets/vacancy_labels.dart';
import 'package:zuno/features/vacancy/presentation/widgets/vacancy_payment_flow.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/confirm_dialog.dart';
import 'package:zuno/shared/widgets/empty_state.dart';
import 'package:zuno/shared/widgets/error_banner.dart';

/// The business's full-time jobs: post one, pay to list it, review who applied.
class BusinessVacanciesTab extends ConsumerWidget {
  const BusinessVacanciesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vacanciesAsync = ref.watch(businessVacanciesProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _post(context, ref),
        icon: const Icon(Icons.work_outline),
        label: const Text('Post a job'),
      ),
      body: vacanciesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorBanner(message: error.toString()),
          ),
        ),
        data: (page) {
          if (page.items.isEmpty) {
            return EmptyState(
              icon: Icons.badge_outlined,
              title: 'No full-time jobs yet',
              message:
                  'Hiring a shop helper, a receptionist or someone for a month? '
                  'Post the job and workers nearby can apply with their documents.',
              actionLabel: 'Post a job',
              onAction: () => _post(context, ref),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(businessVacanciesProvider.future),
            child: NotificationListener<ScrollEndNotification>(
              onNotification: (n) {
                if (n.metrics.extentAfter < 200) {
                  ref.read(businessVacanciesProvider.notifier).loadMore();
                }
                return false;
              },
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: page.items.length + (page.isLoadingMore ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => i == page.items.length
                    ? const Center(child: CircularProgressIndicator())
                    : _VacancyCard(vacancy: page.items[i]),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Saves the job, then goes straight on to paying for it — a job nobody can see is not posted.
  static Future<void> _post(BuildContext context, WidgetRef ref) async {
    final saved = await showVacancyFormSheet(context);
    if (saved == null || !context.mounted) return;
    await payVacancyFee(context, ref, saved);
  }
}

class _VacancyCard extends ConsumerWidget {
  const _VacancyCard({required this.vacancy});

  final Vacancy vacancy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final v = vacancy;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(v.title, style: theme.textTheme.titleMedium),
                ),
                _menu(context, ref),
              ],
            ),
            Text(
              '${v.jobTypeName} · ${vacancySalaryLabel(v)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 2),
            Text(vacancyScheduleLabel(v), style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                vacancyStatusPill(v),
                if (v.applicantCount > 0)
                  Text(
                    '${v.applicantCount} applied'
                    '${v.newCount > 0 ? ' · ${v.newCount} new' : ''}'
                    '${v.shortlistedCount > 0 ? ' · ${v.shortlistedCount} shortlisted' : ''}'
                    '${v.hiredCount > 0 ? ' · ${v.hiredCount} hired' : ''}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
            if (v.isStopped && v.canResume)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Hidden from workers. Your applicants and hires are kept.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (v.needsPayment)
                  FilledButton.icon(
                    onPressed: () => payVacancyFee(context, ref, v),
                    icon: const Icon(Icons.payments_outlined),
                    label: Text(
                      v.status == VacancyStatus.awaitingPayment
                          ? 'Pay & post'
                          : 'Renew',
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => VacancyApplicantsScreen(vacancy: v),
                    ),
                  ),
                  icon: const Icon(Icons.people_outline),
                  label: Text('Applicants (${v.applicantCount})'),
                ),
                if (v.canStop)
                  TextButton(
                    onPressed: () => _stop(context, ref),
                    child: const Text('Stop hiring'),
                  ),
                // One tap, no form: free while the paid period lasts. After it, Renew shows instead.
                if (v.isStopped && v.canResume)
                  FilledButton.icon(
                    onPressed: () => _startAgain(context, ref),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start hiring again'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _menu(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
    onSelected: (value) => switch (value) {
      'edit' => showVacancyFormSheet(context, existing: vacancy),
      'delete' => _delete(context, ref),
      _ => null,
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'edit', child: Text('Edit')),
      PopupMenuItem(value: 'delete', child: Text('Delete')),
    ],
  );

  Future<void> _stop(BuildContext context, WidgetRef ref) async {
    final messenger = AppMessenger.of(context);
    final ok = await showConfirmDialog(
      context,
      title: 'Stop hiring?',
      message:
          'Workers will no longer see this job. Nothing is deleted: your applicants and '
          'hires stay, and you can start hiring again any time while the listing period lasts.',
      confirmLabel: 'Stop hiring',
    );
    if (!ok) return;

    try {
      await ref
          .read(businessVacanciesProvider.notifier)
          .setHiring(vacancy.id, hiring: false);
      messenger.showSuccess('Hiring stopped.');
    } catch (e) {
      messenger.showFailure(e.toString());
    }
  }

  Future<void> _startAgain(BuildContext context, WidgetRef ref) async {
    final messenger = AppMessenger.of(context);
    try {
      await ref
          .read(businessVacanciesProvider.notifier)
          .setHiring(vacancy.id, hiring: true);
      messenger.showSuccess('Hiring again. Workers can see this job.');
    } catch (e) {
      messenger.showFailure(e.toString());
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final messenger = AppMessenger.of(context);
    final ok = await showConfirmDialog(
      context,
      title: 'Delete this job?',
      message:
          'It is deleted at once, together with every applicant\'s documents and answers. '
          'This cannot be undone, and the listing fee is not refunded.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;

    try {
      await ref.read(businessVacanciesProvider.notifier).delete(vacancy.id);
      messenger.showSuccess('Job deleted.');
    } catch (e) {
      messenger.showFailure(e.toString());
    }
  }
}

/// The same list as Workers › Full-time jobs, opened on its own from the home screen's tiles.
class BusinessVacanciesScreen extends StatelessWidget {
  const BusinessVacanciesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Full-time jobs')),
    body: const BusinessVacanciesTab(),
  );
}
