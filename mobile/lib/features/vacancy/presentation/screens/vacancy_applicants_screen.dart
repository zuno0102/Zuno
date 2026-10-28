import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/logging/app_log.dart';
import 'package:zuno/core/share/system_share.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_application.dart';
import 'package:zuno/features/vacancy/presentation/providers/business_vacancies_notifier.dart';
import 'package:zuno/features/vacancy/presentation/providers/vacancy_applicants_notifier.dart';
import 'package:zuno/features/vacancy/presentation/providers/vacancy_providers.dart';
import 'package:zuno/features/vacancy/presentation/widgets/vacancy_labels.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/call_icon_button.dart';
import 'package:zuno/shared/widgets/empty_state.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/confirm_dialog.dart';

/// Applicants in four lists — New, Waiting, Shortlisted, Hired. Opening someone moves them from New
/// to Waiting; rejecting removes them from every list.
///
/// One vacancy's, from its card; or, with no [vacancy], every vacancy's together — what the home
/// screen's tiles open, on the tab of the tile that was tapped.
class VacancyApplicantsScreen extends ConsumerWidget {
  const VacancyApplicantsScreen({
    this.vacancy,
    this.initialStatus = VacancyApplicationStatus.applied,
    super.key,
  });

  final Vacancy? vacancy;

  /// Which list opens first. One of [VacancyApplicationStatus.businessLists].
  final String initialStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = _counts(ref);

    return DefaultTabController(
      length: VacancyApplicationStatus.businessLists.length,
      initialIndex: VacancyApplicationStatus.businessLists
          .indexOf(initialStatus)
          .clamp(0, VacancyApplicationStatus.businessLists.length - 1),
      child: Scaffold(
        appBar: AppBar(
          title: Text(vacancy?.title ?? 'All applicants'),
          bottom: TabBar(
            tabs: [
              for (final status in VacancyApplicationStatus.businessLists)
                Tab(
                  text: counts == null
                      ? businessListLabel(status)
                      : '${businessListLabel(status)} (${counts(status)})',
                ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final status in VacancyApplicationStatus.businessLists)
              _ApplicantList(vacancyId: vacancy?.id, status: status),
          ],
        ),
      ),
    );
  }

  /// Each tab's count, from live data so they move as applicants are opened and decided: the
  /// vacancy's own counts, or the home screen's summary across every vacancy. Null while loading.
  int Function(String)? _counts(WidgetRef ref) {
    final one = vacancy;
    if (one == null) {
      final s = ref.watch(vacancySummaryProvider).value;
      if (s == null) return null;
      return (status) => switch (status) {
        VacancyApplicationStatus.applied => s.newCount,
        VacancyApplicationStatus.viewed => s.waitingCount,
        VacancyApplicationStatus.shortlisted => s.shortlistedCount,
        _ => s.hiredCount,
      };
    }

    final current =
        ref
            .watch(businessVacanciesProvider)
            .value
            ?.items
            .where((v) => v.id == one.id)
            .firstOrNull ??
        one;
    return (status) => switch (status) {
      VacancyApplicationStatus.applied => current.newCount,
      VacancyApplicationStatus.viewed => current.waitingCount,
      VacancyApplicationStatus.shortlisted => current.shortlistedCount,
      _ => current.hiredCount,
    };
  }
}

class _ApplicantList extends ConsumerWidget {
  const _ApplicantList({required this.vacancyId, required this.status});

  /// Null lists every vacancy's applicants, each row then naming its job.
  final String? vacancyId;
  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = vacancyApplicantsProvider(vacancyId, status: status);
    final applicantsAsync = ref.watch(provider);

    return applicantsAsync.when(
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
            icon: Icons.inbox_outlined,
            title: 'Nobody here',
            message: businessListEmptyMessage(status),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(provider.future),
          child: NotificationListener<ScrollEndNotification>(
            onNotification: (n) {
              if (n.metrics.extentAfter < 200) {
                ref.read(provider.notifier).loadMore();
              }
              return false;
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: page.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _ApplicantRow(
                application: page.items[i],
                showJob: vacancyId == null,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ApplicantRow extends StatelessWidget {
  const _ApplicantRow({required this.application, this.showJob = false});

  final VacancyApplication application;

  /// Names the job too — needed when applicants from every job share one list.
  final bool showJob;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = application;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        title: Text(a.workerName, style: theme.textTheme.titleMedium),
        subtitle: Text(
          [
            if (showJob && a.vacancyTitle.isNotEmpty) a.vacancyTitle,
            'Applied ${formatDayMonth(a.appliedAt)}',
            if (a.experienceYears != null)
              '${a.experienceYears} yrs experience',
          ].join(' · '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (a.workerPhone case final phone?)
              CallIconButton(
                phoneNumber: phone,
                tooltip: 'Call ${a.workerName}',
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => _ApplicantSheet(application: a),
        ),
      ),
    );
  }
}

/// One applicant in full. Opening it is what tells the worker their application was viewed.
class _ApplicantSheet extends ConsumerStatefulWidget {
  const _ApplicantSheet({required this.application});

  final VacancyApplication application;

  @override
  ConsumerState<_ApplicantSheet> createState() => _ApplicantSheetState();
}

class _ApplicantSheetState extends ConsumerState<_ApplicantSheet> {
  late VacancyApplication _application = widget.application;
  late final VacancyApplicantActions _actions = VacancyApplicantActions(
    ProviderScope.containerOf(context, listen: false),
  );
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markOpened());
  }

  Future<void> _markOpened() async {
    if (_application.status != VacancyApplicationStatus.applied) return;
    try {
      final opened = await _actions.open(_application);
      if (mounted) setState(() => _application = opened);
    } catch (e, stack) {
      // Logged, not shown: failing to mark it viewed only delays the worker's status, and an error
      // over the applicant would hide what the business opened the sheet to read.
      AppLog.handled('VacancyApplicantSheet.markOpened', e, stack);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = _application;

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(a.workerName, style: theme.textTheme.titleLarge),
              ),
              if (a.workerPhone case final phone?)
                CallIconButton(
                  phoneNumber: phone,
                  tooltip: 'Call ${a.workerName}',
                ),
            ],
          ),
          Text(
            [
              'Applied ${formatDate(a.appliedAt)}',
              if (a.experienceYears != null)
                '${a.experienceYears} yrs experience',
            ].join(' · '),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: businessStatusPill(a.status),
          ),
          for (final answer in a.answers.where((x) => !x.hasFile))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${answer.prompt}\n',
                      style: theme.textTheme.bodySmall,
                    ),
                    TextSpan(text: answer.answerText ?? '—'),
                  ],
                ),
              ),
            ),
          if (a.answers.any((x) => x.hasFile)) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final doc in a.answers.where((x) => x.hasFile))
                  ActionChip(
                    avatar: Icon(
                      doc.isImage
                          ? Icons.image_outlined
                          : Icons.picture_as_pdf_outlined,
                      size: 18,
                    ),
                    label: Text(doc.prompt),
                    onPressed: () => _openDocument(doc),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _editNote,
            icon: const Icon(Icons.edit_note),
            label: Text(
              a.businessNote == null
                  ? 'Add a private note'
                  : 'Note: ${a.businessNote}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(height: 32),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (a.status != VacancyApplicationStatus.shortlisted)
                FilledButton.tonalIcon(
                  onPressed: _busy
                      ? null
                      : () => _decide(VacancyApplicationStatus.shortlisted),
                  icon: const Icon(Icons.star_outline),
                  label: const Text('Shortlist'),
                ),
              if (a.status != VacancyApplicationStatus.hired)
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _decide(VacancyApplicationStatus.hired),
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Hire'),
                ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                onPressed: _busy ? null : _reject,
                icon: const Icon(Icons.block),
                label: const Text('Reject'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _decide(String status) async {
    final messenger = AppMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await _actions.decide(_application.id, status);
      messenger.showSuccess(
        '${_application.workerName}: ${businessListLabel(status)}.',
      );
      navigator.pop();
    } catch (e) {
      messenger.showFailure(e.toString());
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Reject ${_application.workerName}?',
      message:
          'They are removed from your lists and their documents are deleted. '
          'They will see that they were rejected. This cannot be undone.',
      confirmLabel: 'Reject',
      destructive: true,
    );
    if (ok) await _decide(VacancyApplicationStatus.rejected);
  }

  Future<void> _editNote() async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(initial: _application.businessNote),
    );
    if (note == null || !mounted) return;

    final messenger = AppMessenger.of(context);
    try {
      await _actions.saveNote(_application.id, note);
      if (mounted) {
        setState(
          () => _application = _application.copyWith(
            businessNote: note.trim().isEmpty ? null : note.trim(),
          ),
        );
      }
      messenger.showSuccess('Note saved.');
    } catch (e) {
      messenger.showFailure(e.toString());
    }
  }

  /// Downloads the document through the checked endpoint and shows it: a picture in the app, a
  /// PDF in the phone's own viewer. Nothing is saved to the gallery or downloads.
  Future<void> _openDocument(VacancyAnswer doc) async {
    final messenger = AppMessenger.of(context);
    try {
      final bytes = await _actions.download(doc.id);
      if (!mounted) return;

      if (doc.isImage) {
        await showDialog<void>(
          context: context,
          builder: (_) =>
              Dialog(child: InteractiveViewer(child: Image.memory(bytes))),
        );
        return;
      }

      final outcome = await SystemShare.openFile(
        bytes: bytes,
        fileName: doc.fileName ?? 'document.pdf',
        mimeType: doc.contentType ?? 'application/pdf',
      );
      if (outcome == ShareOutcome.unavailable) {
        messenger.showInfo('Open this document from the Zuno phone app.');
      }
    } catch (e) {
      messenger.showFailure(e.toString());
    }
  }
}

/// The private-note dialog. It owns its text controller so the controller outlives the dialog's
/// closing animation; disposing it as soon as showDialog returned crashed the app on Save.
class _NoteDialog extends StatefulWidget {
  const _NoteDialog({this.initial});

  final String? initial;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Private note'),
    content: TextField(
      controller: _controller,
      maxLength: 500,
      maxLines: 3,
      autofocus: true,
      decoration: const InputDecoration(
        hintText: 'Only you see this, e.g. "Call on Monday"',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('Save'),
      ),
    ],
  );
}
