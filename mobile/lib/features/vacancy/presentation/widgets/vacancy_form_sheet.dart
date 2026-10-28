import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_draft.dart';
import 'package:zuno/features/vacancy/presentation/providers/business_vacancies_notifier.dart';
import 'package:zuno/features/vacancy/presentation/providers/vacancy_providers.dart';
import 'package:zuno/features/vacancy/presentation/widgets/vacancy_labels.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/location_pin_picker.dart';
import 'package:zuno/shared/widgets/primary_button.dart';

/// Opens the vacancy form: blank to post a new job, or filled in to edit [existing].
///
/// Returns the saved vacancy, or null if the business backed out.
Future<Vacancy?> showVacancyFormSheet(
  BuildContext context, {
  Vacancy? existing,
}) => showModalBottomSheet<Vacancy>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => VacancyFormSheet(existing: existing),
);

class VacancyFormSheet extends ConsumerStatefulWidget {
  const VacancyFormSheet({this.existing, super.key});

  final Vacancy? existing;

  @override
  ConsumerState<VacancyFormSheet> createState() => _VacancyFormSheetState();
}

/// One custom field being edited: its name, its type and whether it is a must.
class _FieldRow {
  _FieldRow({
    String label = '',
    this.kind = VacancyRequirementKind.text,
    this.isRequired = true,
  }) : controller = TextEditingController(text: label);

  final TextEditingController controller;
  String kind;
  bool isRequired;
}

class _VacancyFormSheetState extends ConsumerState<VacancyFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _description = TextEditingController(
    text: widget.existing?.description,
  );
  late final _salaryMin = TextEditingController(
    text: _whole(widget.existing?.salaryMin),
  );
  late final _salaryMax = TextEditingController(
    text: _whole(widget.existing?.salaryMax),
  );
  late final _openings = TextEditingController(
    text: '${widget.existing?.openings ?? 1}',
  );
  late final _months = TextEditingController(
    text: widget.existing?.contractMonths?.toString(),
  );
  late final _location = TextEditingController(text: widget.existing?.location);

  String? _jobTypeId;
  late String _payPeriod =
      widget.existing?.payPeriod ?? VacancyPayPeriod.perMonth;
  late int _days = widget.existing?.workingDaysPerWeek ?? 6;
  late TimeOfDay? _shiftStart = _parseTime(widget.existing?.shiftStart);
  late TimeOfDay? _shiftEnd = _parseTime(widget.existing?.shiftEnd);
  late double? _latitude = widget.existing?.latitude;
  late double? _longitude = widget.existing?.longitude;
  String? _locationPrecision;

  /// The business's own fields, in the order applicants see them.
  late final List<_FieldRow> _fields = [
    for (final r
        in widget.existing?.requirements ?? const <VacancyRequirement>[])
      _FieldRow(label: r.prompt, kind: r.kind, isRequired: r.isRequired),
  ];

  /// Taking applications. Only offered when editing a vacancy already paid for.
  late bool _hiring = !(widget.existing?.isStopped ?? false);
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  bool get _canToggleHiring =>
      widget.existing != null &&
      !widget.existing!.needsPayment &&
      widget.existing!.status != VacancyStatus.awaitingPayment;

  @override
  void initState() {
    super.initState();
    _jobTypeId = widget.existing?.jobTypeId;
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _salaryMin,
      _salaryMax,
      _openings,
      _months,
      _location,
      ..._fields.map((f) => f.controller),
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static String? _whole(double? v) => v?.toStringAsFixed(0);

  static TimeOfDay? _parseTime(String? value) {
    if (value == null || value.length < 5) return null;
    final h = int.tryParse(value.substring(0, 2));
    final m = int.tryParse(value.substring(3, 5));
    return h == null || m == null ? null : TimeOfDay(hour: h, minute: m);
  }

  static String? _formatTime(TimeOfDay? t) => t == null
      ? null
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  @override
  Widget build(BuildContext context) {
    final optionsAsync = ref.watch(vacancyOptionsProvider(asWorker: false));
    final limits = ref.watch(currentAppOptionsProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: optionsAsync.when(
        loading: () => const SizedBox(
          height: 240,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorBanner(message: e.toString()),
        ),
        data: (options) {
          final jobType = options.jobTypes
              .where((t) => t.id == _jobTypeId)
              .firstOrNull;

          return Form(
            key: _formKey,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(
                  _isEdit ? 'Edit full-time job' : 'Post a full-time job',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Shown to workers only. You review applicants and call them yourself.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _title,
                  maxLength: limits.vacancyTitleMaxLength,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Job title',
                    hintText: 'e.g. Office receptionist',
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Enter a job title' : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _jobTypeId,
                  decoration: const InputDecoration(labelText: 'Job type'),
                  items: [
                    for (final t in options.jobTypes)
                      DropdownMenuItem(value: t.id, child: Text(t.name)),
                  ],
                  onChanged: (v) => setState(() => _jobTypeId = v),
                  validator: (v) => v == null ? 'Choose a job type' : null,
                ),
                if (jobType?.hasFixedLength ?? false) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _months,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'How many months?',
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return n == null ||
                              n < 1 ||
                              n > limits.vacancyMaxContractMonths
                          ? 'Between 1 and ${limits.vacancyMaxContractMonths} months'
                          : null;
                    },
                  ),
                ],
                const SizedBox(height: 12),
                _salaryRow(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _openings,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Openings',
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          return n == null ||
                                  n < 1 ||
                                  n > limits.vacancyMaxOpenings
                              ? '1 to ${limits.vacancyMaxOpenings}'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _days,
                        decoration: const InputDecoration(
                          labelText: 'Days a week',
                        ),
                        items: [
                          for (var d = 1; d <= 7; d++)
                            DropdownMenuItem(value: d, child: Text('$d')),
                        ],
                        onChanged: (v) => setState(() => _days = v ?? _days),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _shiftRow(context),
                const SizedBox(height: 12),
                _locationField(context),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  maxLength: limits.vacancyDescriptionMaxLength,
                  maxLines: 4,
                  minLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'About the job (optional)',
                    hintText: 'Duties, experience needed, timings, benefits',
                  ),
                ),
                const SizedBox(height: 8),
                _fieldsSection(theme),
                if (_canToggleHiring) ...[
                  const Divider(height: 32),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Taking applications'),
                    subtitle: Text(
                      _hiring
                          ? 'Workers can see and apply for this job.'
                          : 'Hidden from workers. Nothing is deleted.',
                    ),
                    value: _hiring,
                    onChanged: (v) => setState(() => _hiring = v),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 20),
                PrimaryButton(
                  label: _isEdit ? 'Save changes' : 'Save and continue to pay',
                  isLoading: _saving,
                  onPressed: _saving ? null : () => _save(context),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _salaryRow() => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _salaryMin,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Salary',
                prefixText: '₹ ',
              ),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                return n == null || n <= 0 ? 'Enter the salary' : null;
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _salaryMax,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Up to (optional)',
                prefixText: '₹ ',
              ),
              validator: (v) {
                if ((v ?? '').isEmpty) return null;
                final max = double.tryParse(v!);
                final min = double.tryParse(_salaryMin.text) ?? 0;
                return max == null || max < min ? 'Not below the salary' : null;
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: _payPeriod,
        decoration: const InputDecoration(labelText: 'Salary is paid'),
        items: [
          for (final p in payPeriodOptions)
            DropdownMenuItem(value: p, child: Text(payPeriodWords(p))),
        ],
        onChanged: (v) => setState(() => _payPeriod = v ?? _payPeriod),
      ),
    ],
  );

  Widget _shiftRow(BuildContext context) {
    Future<void> pick(bool start) async {
      final picked = await showTimePicker(
        context: context,
        initialTime:
            (start ? _shiftStart : _shiftEnd) ??
            TimeOfDay(hour: start ? 9 : 18, minute: 0),
      );
      if (picked == null) return;
      setState(() => start ? _shiftStart = picked : _shiftEnd = picked);
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => pick(true),
            icon: const Icon(Icons.schedule),
            label: Text(
              _shiftStart == null
                  ? 'Shift starts'
                  : 'From ${_shiftStart!.format(context)}',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => pick(false),
            icon: const Icon(Icons.schedule_outlined),
            label: Text(
              _shiftEnd == null
                  ? 'Shift ends'
                  : 'To ${_shiftEnd!.format(context)}',
            ),
          ),
        ),
        if (_shiftStart != null || _shiftEnd != null)
          IconButton(
            tooltip: 'Clear shift times',
            onPressed: () => setState(() {
              _shiftStart = null;
              _shiftEnd = null;
            }),
            icon: const Icon(Icons.close),
          ),
      ],
    );
  }

  Widget _locationField(BuildContext context) => TextFormField(
    controller: _location,
    maxLength: ref.watch(currentAppOptionsProvider).vacancyLocationMaxLength,
    decoration: InputDecoration(
      labelText: 'Workplace address',
      hintText: 'e.g. Near bus stand, Main road',
      helperText: _latitude != null ? 'Pinned on the map' : null,
      suffixIcon: IconButton(
        tooltip: 'Pin on the map',
        icon: Icon(
          _latitude != null
              ? Icons.location_on
              : Icons.add_location_alt_outlined,
        ),
        onPressed: () async {
          final picked = await showLocationPinPicker(
            context,
            initialLatitude: _latitude,
            initialLongitude: _longitude,
            title: 'Pin the workplace',
          );
          if (picked == null) return;
          setState(() {
            _latitude = picked.latitude;
            _longitude = picked.longitude;
            _locationPrecision = 'Pinned';
            if (_location.text.trim().isEmpty) _location.text = picked.summary;
          });
        },
      ),
    ),
  );

  /// The business's own fields: what to ask, as what kind of answer, and whether it is a must.
  Widget _fieldsSection(ThemeData theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Custom fields', style: theme.textTheme.titleSmall),
      Text(
        'Ask applicants for anything you need: a document like Aadhaar or a resume, '
        'or a question. Name, phone and experience are shared automatically.',
        style: theme.textTheme.bodySmall,
      ),
      for (final (i, f) in _fields.indexed)
        Card(
          margin: const EdgeInsets.only(top: 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: f.controller,
                        maxLength: ref
                            .watch(currentAppOptionsProvider)
                            .vacancyFieldNameMaxLength,
                        decoration: InputDecoration(
                          labelText: 'Field ${i + 1} name',
                          hintText: 'e.g. Aadhaar, Resume, Your area',
                        ),
                        validator: (v) {
                          final name = (v ?? '').trim().toLowerCase();
                          if (name.isEmpty) return 'Give this field a name';
                          final duplicate = _fields.any(
                            (o) =>
                                o != f &&
                                o.controller.text.trim().toLowerCase() == name,
                          );
                          return duplicate ? 'Already used' : null;
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove field',
                      onPressed: () {
                        final removed = _fields[i];
                        setState(() => _fields.removeAt(i));
                        // After the frame that takes its text box off screen, never during it.
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => removed.controller.dispose(),
                        );
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: f.kind,
                        decoration: const InputDecoration(
                          labelText: 'Answer type',
                          isDense: true,
                        ),
                        items: [
                          for (final k in fieldKindOptions)
                            DropdownMenuItem(
                              value: k,
                              child: Text(fieldKindLabel(k)),
                            ),
                        ],
                        onChanged: (v) => setState(() => f.kind = v ?? f.kind),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Checkbox(
                      value: f.isRequired,
                      onChanged: (v) =>
                          setState(() => f.isRequired = v ?? f.isRequired),
                    ),
                    Text('Must', style: theme.textTheme.labelMedium),
                    const SizedBox(width: 8),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      TextButton.icon(
        onPressed:
            _fields.length >=
                ref.watch(currentAppOptionsProvider).vacancyMaxFields
            ? null
            : () => setState(() => _fields.add(_FieldRow())),
        icon: const Icon(Icons.add),
        label: const Text('Add a field'),
      ),
    ],
  );

  VacancyDraft _draft() {
    final description = _description.text.trim();
    final location = _location.text.trim();
    final max = double.tryParse(_salaryMax.text);
    final hasShift = _shiftStart != null && _shiftEnd != null;

    return VacancyDraft(
      title: _title.text.trim(),
      description: description.isEmpty ? null : description,
      jobTypeId: _jobTypeId!,
      openings: int.parse(_openings.text),
      salaryMin: double.parse(_salaryMin.text),
      salaryMax: max,
      payPeriod: _payPeriod,
      workingDaysPerWeek: _days,
      shiftStart: hasShift ? _formatTime(_shiftStart) : null,
      shiftEnd: hasShift ? _formatTime(_shiftEnd) : null,
      contractMonths: int.tryParse(_months.text),
      location: location.isEmpty ? null : location,
      latitude: _latitude,
      longitude: _longitude,
      locationPrecision: _locationPrecision,
      requirements: [
        for (final f in _fields)
          VacancyRequirementDraft(
            kind: f.kind,
            prompt: f.controller.text.trim(),
            isRequired: f.isRequired,
          ),
      ],
    );
  }

  Future<void> _save(BuildContext context) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if ((_shiftStart == null) != (_shiftEnd == null)) {
      setState(() => _error = 'Set both shift times, or clear them.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final notifier = ref.read(businessVacanciesProvider.notifier);
    final navigator = Navigator.of(context);
    final messenger = AppMessenger.of(context);

    try {
      final existing = widget.existing;
      var saved = existing == null
          ? await notifier.create(_draft())
          : await notifier.edit(existing.id, _draft());

      // Stopping and starting again live on this form, as the business asked: one place to change
      // anything about a job.
      if (_canToggleHiring && _hiring != !saved.isStopped) {
        saved = await notifier.setHiring(saved.id, hiring: _hiring);
      }

      messenger.showSuccess(_isEdit ? 'Job updated.' : 'Job saved.');
      navigator.pop(saved);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
