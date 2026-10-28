import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_draft.dart';
import 'package:zuno/features/vacancy/presentation/providers/vacancy_providers.dart';
import 'package:zuno/features/vacancy/presentation/providers/vacancy_application_actions.dart';
import 'package:zuno/features/vacancy/presentation/widgets/vacancy_labels.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/primary_button.dart';
import 'package:zuno/shared/widgets/confirm_dialog.dart';

/// One full-time job, and the form to apply for it with the documents the business asked for.
class WorkerVacancyDetailScreen extends ConsumerWidget {
  const WorkerVacancyDetailScreen({required this.vacancyId, super.key});

  final String vacancyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vacancyAsync = ref.watch(workerVacancyProvider(vacancyId));

    return Scaffold(
      appBar: AppBar(title: const Text('Job details')),
      body: vacancyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorBanner(message: error.toString()),
          ),
        ),
        data: (v) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Summary(vacancy: v),
            const Divider(height: 32),
            if (v.hasApplied)
              _Applied(vacancy: v)
            else if (v.isLive)
              _ApplyForm(vacancy: v)
            else
              const Text('This job is no longer taking applications.'),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.vacancy});

  final Vacancy vacancy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = vacancy;

    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(v.title, style: theme.textTheme.headlineSmall),
        Text(v.businessName, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          vacancySalaryLabel(v),
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        line(Icons.work_outline, v.jobTypeName),
        line(Icons.calendar_today_outlined, vacancyScheduleLabel(v)),
        line(
          Icons.groups_outlined,
          '${v.openings} ${v.openings == 1 ? 'opening' : 'openings'}',
        ),
        if (v.location != null || v.districtName != null)
          line(
            Icons.place_outlined,
            [
              ?v.location ?? v.districtName,
              if (v.distanceKm != null) '${v.distanceKm} km away',
            ].join(' · '),
          ),
        if (v.description case final d?) ...[
          const SizedBox(height: 16),
          Text(d),
        ],
      ],
    );
  }
}

class _Applied extends ConsumerStatefulWidget {
  const _Applied({required this.vacancy});

  final Vacancy vacancy;

  @override
  ConsumerState<_Applied> createState() => _AppliedState();
}

class _AppliedState extends ConsumerState<_Applied> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.vacancy;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your application', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        applicationStatusPill(v.myApplicationStatus!),
        if (v.myAppliedAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Sent ${formatDate(v.myAppliedAt!)}. The business will call you if they '
              'want to take it further.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        if (v.canWithdraw) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _busy ? null : _withdraw,
            icon: const Icon(Icons.undo),
            label: const Text('Withdraw application'),
          ),
        ],
      ],
    );
  }

  Future<void> _withdraw() async {
    final messenger = AppMessenger.of(context);
    final actions = VacancyApplicationActions(
      ProviderScope.containerOf(context, listen: false),
    );
    final ok = await showConfirmDialog(
      context,
      title: 'Withdraw your application?',
      message:
          'Your documents and answers are deleted from this job. You can apply again '
          'while it is open.',
      confirmLabel: 'Withdraw',
      cancelLabel: 'Keep it',
    );
    if (!ok) return;

    setState(() => _busy = true);
    try {
      await actions.withdraw(widget.vacancy);
      messenger.showSuccess('Application withdrawn.');
    } catch (e) {
      messenger.showFailure(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// A picked document, held in memory until the application is sent.
class _PickedFile {
  const _PickedFile(this.name, this.bytes);

  final String name;
  final Uint8List bytes;
}

class _ApplyForm extends ConsumerStatefulWidget {
  const _ApplyForm({required this.vacancy});

  final Vacancy vacancy;

  @override
  ConsumerState<_ApplyForm> createState() => _ApplyFormState();
}

class _ApplyFormState extends ConsumerState<_ApplyForm> {
  final _formKey = GlobalKey<FormState>();

  /// Typed answers, for Text and Number fields.
  final Map<String, TextEditingController> _answers = {};

  /// "Yes" or "No", for Yes/No fields.
  final Map<String, String> _choices = {};
  final Map<String, _PickedFile> _files = {};
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final r in widget.vacancy.requirements) {
      if (r.kind == VacancyRequirementKind.text ||
          r.kind == VacancyRequirementKind.number) {
        _answers[r.id] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _answers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final requirements = widget.vacancy.requirements;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Apply for this job', style: theme.textTheme.titleMedium),
          if (requirements.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Your details are shared only with the job poster.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          for (final r in requirements)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: switch (r.kind) {
                VacancyRequirementKind.file => _fileField(r),
                VacancyRequirementKind.yesNo => _yesNoField(r),
                _ => _typedField(r),
              },
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Send application',
            isLoading: _sending,
            onPressed: _sending ? null : _send,
          ),
        ],
      ),
    );
  }

  static String _label(VacancyRequirement r) =>
      r.isRequired ? r.prompt : '${r.prompt} (optional)';

  /// A Text or Number field.
  Widget _typedField(VacancyRequirement r) {
    final isNumber = r.kind == VacancyRequirementKind.number;
    return TextFormField(
      controller: _answers[r.id],
      maxLength: isNumber ? 12 : 1000,
      minLines: 1,
      maxLines: isNumber ? 1 : 3,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: isNumber
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
          : null,
      decoration: InputDecoration(labelText: _label(r)),
      validator: (v) {
        final text = (v ?? '').trim();
        if (text.isEmpty) return r.isRequired ? 'Please answer this' : null;
        return isNumber && double.tryParse(text) == null
            ? 'Enter a number'
            : null;
      },
    );
  }

  Widget _yesNoField(VacancyRequirement r) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(_label(r), style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        children: [
          for (final choice in const ['Yes', 'No'])
            ChoiceChip(
              label: Text(choice),
              selected: _choices[r.id] == choice,
              onSelected: (selected) => setState(
                () =>
                    selected ? _choices[r.id] = choice : _choices.remove(r.id),
              ),
            ),
        ],
      ),
    ],
  );

  Widget _fileField(VacancyRequirement r) {
    final picked = _files[r.id];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_label(r), style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => _pick(r),
          icon: Icon(picked == null ? Icons.upload_file : Icons.check_circle),
          label: Text(
            picked?.name ?? 'Choose a photo or PDF',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> _pick(VacancyRequirement r) async {
    final messenger = AppMessenger.of(context);

    // The allowed types and size come from the server's settings, not from this app.
    final rules = await ref.read(vacancyOptionsProvider(asWorker: true).future);
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: rules.allowedFileExtensions,
    );
    if (files.isEmpty) return;

    final file = files.first;
    final size = await file.length() ?? 0;
    final limit = rules.maxFileSizeBytes;

    // Checked here so a worker on a slow connection is not made to upload a file only to have it
    // refused. The server checks again, by the file's real content.
    if (size > limit) {
      messenger.showFailure(
        '${r.prompt} must be ${limit ~/ (1024 * 1024)}MB or smaller.',
      );
      return;
    }

    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _files[r.id] = _PickedFile(file.name, bytes));
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Files and Yes/No are not text fields, so the form's own validators cannot see them.
    final missing = widget.vacancy.requirements
        .where(
          (r) =>
              r.isRequired &&
              switch (r.kind) {
                VacancyRequirementKind.file => !_files.containsKey(r.id),
                VacancyRequirementKind.yesNo => !_choices.containsKey(r.id),
                _ => false,
              },
        )
        .map((r) => r.prompt)
        .toList();
    if (missing.isNotEmpty) {
      setState(() => _error = 'Please complete: ${missing.join(', ')}.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    final messenger = AppMessenger.of(context);
    final actions = VacancyApplicationActions(
      ProviderScope.containerOf(context, listen: false),
    );
    try {
      await actions.apply(widget.vacancy.id, [
        for (final MapEntry(key: id, value: c) in _answers.entries)
          VacancyAnswerDraft(requirementId: id, text: c.text),
        for (final MapEntry(key: id, value: choice) in _choices.entries)
          VacancyAnswerDraft(requirementId: id, text: choice),
        for (final MapEntry(key: id, value: f) in _files.entries)
          VacancyAnswerDraft(
            requirementId: id,
            bytes: f.bytes,
            fileName: f.name,
          ),
      ]);
      messenger.showSuccess('Application sent.');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
