import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/primary_button.dart';
import 'package:zuno/shared/widgets/select_field.dart';
import 'package:zuno/shared/widgets/status_pill.dart';
import 'package:zuno/core/theme/app_colors.dart';

/// The Marketplace categories, and the details each asks a post for — set up by the super admin,
/// so a new kind of thing to sell ("Mobiles", "Livestock") needs no release.
class AdminMarketplaceCategoriesScreen extends ConsumerWidget {
  const AdminMarketplaceCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(adminMarketplaceCategoriesProvider);
    final options = ref.watch(marketplaceOptionsProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Marketplace categories')),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('admin-marketplace-add-category'),
        onPressed: () => _showSheet(context, _CategorySheet(options: options)),
        icon: const Icon(Icons.add),
        label: const Text('Category'),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorBanner(message: error.toString()),
          ),
        ),
        data: (categories) => RefreshIndicator(
          onRefresh: () =>
              ref.refresh(adminMarketplaceCategoriesProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            children: [
              for (final c in categories)
                _CategoryCard(category: c, options: options),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showSheet(BuildContext context, Widget sheet) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => sheet,
    );

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.options});

  final MarketplaceCategory category;
  final MarketplaceOptions? options;

  @override
  Widget build(BuildContext context) {
    final fields = [...category.fields]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        key: ValueKey('admin-marketplace-category-${category.slug}'),
        shape: const Border(),
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            options?.kindName(category.kind) ?? category.kind,
            if (category.allowsWholesale) 'Wholesale allowed',
            '${fields.length} detail${fields.length == 1 ? '' : 's'}',
          ].join(' · '),
        ),
        trailing: category.isActive
            ? null
            : const StatusPill(
                label: 'Hidden',
                tone: StatusTone.waiting,
                compact: true,
              ),
        children: [
          for (final f in fields)
            ListTile(
              dense: true,
              title: Text(f.isRequired ? f.label : '${f.label} (optional)'),
              subtitle: Text(
                [
                  f.fieldType,
                  if (f.unit != null) f.unit!,
                  if (f.options.isNotEmpty) f.options.join(', '),
                  if (!f.isActive) 'hidden',
                ].join(' · '),
              ),
              trailing: const Icon(Icons.edit_outlined, size: 18),
              onTap: () => _showSheet(
                context,
                _FieldSheet(categoryId: category.id, existing: f),
              ),
            ),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showSheet(
                  context,
                  _FieldSheet(
                    categoryId: category.id,
                    nextOrder: fields.length + 1,
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Detail'),
              ),
              TextButton.icon(
                onPressed: () => _showSheet(
                  context,
                  _CategorySheet(existing: category, options: options),
                ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit category'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Saves through [save], reloads the category lists, says so and closes — or shows why not.
Future<void> _saveAndClose(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() save,
  String done,
) async {
  final messenger = AppMessenger.of(context);
  final navigator = Navigator.of(context);
  try {
    await save();
    reloadMarketplaceCategories(ref);
    messenger.showSuccess(done);
    navigator.pop();
  } catch (e) {
    messenger.showFailure(e.toString());
  }
}

class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet({required this.options, this.existing});

  final MarketplaceCategory? existing;
  final MarketplaceOptions? options;

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _icon = TextEditingController(text: widget.existing?.iconName);
  late final _order = TextEditingController(
    text: '${widget.existing?.displayOrder ?? 0}',
  );
  late String _kind = widget.existing?.kind ?? MarketplacePostKind.listing;
  late bool _wholesale = widget.existing?.allowsWholesale ?? false;
  late bool _active = widget.existing?.isActive ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _icon.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final input = MarketplaceCategoryInput(
      name: _name.text.trim(),
      iconName: _icon.text.trim().isEmpty ? null : _icon.text.trim(),
      kind: _kind,
      allowsWholesale: _wholesale,
      displayOrder: int.tryParse(_order.text) ?? 0,
      isActive: _active,
    );
    final repository = ref.read(marketplaceRepositoryProvider);
    final existing = widget.existing;
    await _saveAndClose(
      context,
      ref,
      () => existing == null
          ? repository.createCategory(input)
          : repository.updateCategory(existing.id, input),
      '${input.name} saved.',
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final kinds = widget.options?.kinds ?? const <MarketplaceOption>[];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null ? 'New category' : 'Edit category',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('admin-marketplace-category-name'),
                controller: _name,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Name is required.' : null,
              ),
              const SizedBox(height: 14),
              SelectField<String>(
                label: 'Kind',
                options: [
                  for (final k in kinds) SelectOption(k.code, k.name),
                  if (kinds.isEmpty) SelectOption(_kind, _kind),
                ],
                initialValue: _kind,
                onChanged: (v) => setState(() => _kind = v),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _icon,
                      maxLength: 50,
                      decoration: const InputDecoration(
                        labelText: 'Icon name (optional)',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _order,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Order',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allows wholesale (B2B)'),
                value: _wholesale,
                onChanged: (v) => setState(() => _wholesale = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Shown to businesses and customers'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                label: 'Save',
                isLoading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldSheet extends ConsumerStatefulWidget {
  const _FieldSheet({
    required this.categoryId,
    this.existing,
    this.nextOrder = 1,
  });

  final String categoryId;
  final MarketplaceCategoryField? existing;
  final int nextOrder;

  @override
  ConsumerState<_FieldSheet> createState() => _FieldSheetState();
}

class _FieldSheetState extends ConsumerState<_FieldSheet> {
  static const _types = [
    SelectOption(
      MarketplaceFieldType.text,
      'Text',
      detail: 'Any words, e.g. a brand',
    ),
    SelectOption(
      MarketplaceFieldType.number,
      'Number',
      detail: 'e.g. year, km, area',
    ),
    SelectOption(
      MarketplaceFieldType.select,
      'List',
      detail: 'One of the choices you give',
    ),
  ];

  final _formKey = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.existing?.label);
  late final _unit = TextEditingController(text: widget.existing?.unit);
  late final _choices = TextEditingController(
    text: widget.existing?.options.join(', '),
  );
  late final _order = TextEditingController(
    text: '${widget.existing?.displayOrder ?? widget.nextOrder}',
  );
  late String _type = widget.existing?.fieldType ?? MarketplaceFieldType.text;
  late bool _required = widget.existing?.isRequired ?? false;
  late bool _active = widget.existing?.isActive ?? true;
  bool _saving = false;

  List<String> get _options => [
    for (final c in _choices.text.split(','))
      if (c.trim().isNotEmpty) c.trim(),
  ];

  @override
  void dispose() {
    _label.dispose();
    _unit.dispose();
    _choices.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final input = MarketplaceFieldInput(
      label: _label.text.trim(),
      fieldType: _type,
      options: _type == MarketplaceFieldType.select ? _options : const [],
      unit: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
      isRequired: _required,
      displayOrder: int.tryParse(_order.text) ?? widget.nextOrder,
      isActive: _active,
    );
    final repository = ref.read(marketplaceRepositoryProvider);
    final existing = widget.existing;
    await _saveAndClose(
      context,
      ref,
      () => existing == null
          ? repository.createField(widget.categoryId, input)
          : repository.updateField(widget.categoryId, existing.id, input),
      '${input.label} saved.',
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isList = _type == MarketplaceFieldType.select;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null ? 'New detail' : 'Edit detail',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('admin-marketplace-field-label'),
                controller: _label,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  hintText: 'e.g. KM driven',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Label is required.' : null,
              ),
              const SizedBox(height: 14),
              SelectField<String>(
                label: 'Type',
                options: _types,
                initialValue: _type,
                onChanged: (v) => setState(() => _type = v),
              ),
              const SizedBox(height: 14),
              if (isList) ...[
                TextFormField(
                  controller: _choices,
                  decoration: const InputDecoration(
                    labelText: 'Choices, separated by commas',
                    hintText: 'Petrol, Diesel, Electric',
                    border: OutlineInputBorder(),
                  ),
                  validator: (_) {
                    final options = _options;
                    if (options.isEmpty) return 'Give at least one choice.';
                    final distinct = {for (final o in options) o.toLowerCase()};
                    return distinct.length == options.length
                        ? null
                        : 'Each choice must be different.';
                  },
                ),
                const SizedBox(height: 14),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _unit,
                      maxLength: 20,
                      decoration: const InputDecoration(
                        labelText: 'Unit (optional)',
                        hintText: 'km, cents',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _order,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Order',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Required'),
                value: _required,
                onChanged: (v) => setState(() => _required = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Shown on the post form'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                label: 'Save',
                isLoading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
