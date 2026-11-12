import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/primary_button.dart';
import 'package:zuno/shared/widgets/select_field.dart';
import 'package:zuno/shared/widgets/status_pill.dart';

/// The Marketplace's main categories, their sub-categories, and the details each asks a post for —
/// set up by the super admin, so a new kind of thing to sell ("Mobiles", "Watches") needs no release.
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

/// The name the server's table gives [code], or [code] until the table has loaded.
String _optionName(List<MarketplaceOption>? list, String code) =>
    list?.where((o) => o.code == code).firstOrNull?.name ?? code;

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.options});

  final MarketplaceCategory category;
  final MarketplaceOptions? options;

  @override
  Widget build(BuildContext context) {
    final subs = [...category.subCategories]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    final wholeCategory = category.fieldsFor(null);
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
            _optionName(options?.tradeModes, category.tradeMode),
            if (category.tracksStock) 'New / used, with stock',
            '${subs.length} sub-categor${subs.length == 1 ? 'y' : 'ies'}',
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
          const _Heading('Sub-categories'),
          for (final s in subs)
            ListTile(
              key: ValueKey('admin-marketplace-sub-${s.slug}'),
              dense: true,
              title: Text(s.isActive ? s.name : '${s.name} (hidden)'),
              subtitle: _detailsLine(category.fieldsFor(s.id), s.id),
              trailing: const Icon(Icons.edit_outlined, size: 18),
              onTap: () => _showSheet(
                context,
                _SubCategorySheet(categoryId: category.id, existing: s),
              ),
            ),
          if (wholeCategory.isNotEmpty) ...[
            const _Heading('Details asked in every sub-category'),
            for (final f in wholeCategory)
              _FieldTile(category: category, field: f),
          ],
          for (final s in subs)
            if (category.fields.any((f) => f.subCategoryId == s.id)) ...[
              _Heading('Details for ${s.name}'),
              for (final f in category.fields)
                if (f.subCategoryId == s.id)
                  _FieldTile(category: category, field: f),
            ],
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                key: ValueKey('admin-marketplace-add-sub-${category.slug}'),
                onPressed: () => _showSheet(
                  context,
                  _SubCategorySheet(
                    categoryId: category.id,
                    nextOrder: subs.length + 1,
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Sub-category'),
              ),
              TextButton.icon(
                onPressed: () => _showSheet(
                  context,
                  _FieldSheet(
                    category: category,
                    nextOrder: category.fields.length + 1,
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
                label: const Text('Edit'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "Brand · Model year · KM driven" — what a post in this sub-category is asked beyond the rest.
  static Widget? _detailsLine(
    List<MarketplaceCategoryField> fields,
    String subId,
  ) {
    final own = [
      for (final f in fields)
        if (f.subCategoryId == subId) f.label,
    ];
    return own.isEmpty ? null : Text(own.join(' · '));
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    ),
  );
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({required this.category, required this.field});

  final MarketplaceCategory category;
  final MarketplaceCategoryField field;

  @override
  Widget build(BuildContext context) {
    final f = field;
    return ListTile(
      dense: true,
      title: Text(f.isRequired ? f.label : '${f.label} (optional)'),
      subtitle: Text(
        [
          f.fieldType,
          ?f.unit,
          if (f.options.isNotEmpty) f.options.join(', '),
          if (!f.isActive) 'hidden',
        ].join(' · '),
      ),
      trailing: const Icon(Icons.edit_outlined, size: 18),
      onTap: () =>
          _showSheet(context, _FieldSheet(category: category, existing: f)),
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

/// A whole-number box for a display order.
Widget _orderField(TextEditingController controller) => TextFormField(
  controller: controller,
  keyboardType: TextInputType.number,
  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
  decoration: const InputDecoration(
    labelText: 'Order',
    border: OutlineInputBorder(),
  ),
);

/// The padding and title every admin sheet shares.
Widget _sheet(
  BuildContext context, {
  required GlobalKey<FormState> formKey,
  required String title,
  required List<Widget> children,
}) => Padding(
  padding: EdgeInsets.fromLTRB(
    20,
    0,
    20,
    MediaQuery.of(context).viewInsets.bottom + 20,
  ),
  child: SingleChildScrollView(
    child: Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  ),
);

class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet({required this.options, this.existing});

  final MarketplaceCategory? existing;
  final MarketplaceOptions? options;

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  final _formKey = GlobalKey<FormState>();
  late final MarketplaceCategory? _old = widget.existing;
  late final _name = TextEditingController(text: _old?.name);
  late final _shortName = TextEditingController(
    text: _old == null || _old.shortName == _old.name ? null : _old.shortName,
  );
  late final _description = TextEditingController(text: _old?.description);
  late final _icon = TextEditingController(text: _old?.iconName);
  late final _order = TextEditingController(text: '${_old?.displayOrder ?? 0}');
  late String _kind = _old?.kind ?? MarketplacePostKind.listing;
  late String _tradeMode = _old?.tradeMode ?? MarketplaceTradeMode.retailOnly;
  late bool _active = _old?.isActive ?? true;
  late bool _tracksStock = _old?.tracksStock ?? false;
  bool _saving = false;

  static String? _clean(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  @override
  void dispose() {
    for (final c in [_name, _shortName, _description, _icon, _order]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final input = MarketplaceCategoryInput(
      name: _name.text.trim(),
      shortName: _clean(_shortName),
      description: _clean(_description),
      iconName: _clean(_icon),
      kind: _kind,
      tradeMode: _tradeMode,
      displayOrder: int.tryParse(_order.text) ?? 0,
      isActive: _active,
      tracksStock: _tracksStock,
    );
    final repository = ref.read(marketplaceRepositoryProvider);
    final old = _old;
    await _saveAndClose(
      context,
      ref,
      () => old == null
          ? repository.createCategory(input)
          : repository.updateCategory(old.id, input),
      '${input.name} saved.',
    );
    if (mounted) setState(() => _saving = false);
  }

  /// A choice from one of the server's tables; until it has loaded, the current value alone.
  List<SelectOption<String>> _choices(
    List<MarketplaceOption>? list,
    String current,
  ) => list == null || list.isEmpty
      ? [SelectOption(current, current)]
      : [for (final o in list) SelectOption(o.code, o.name, detail: o.detail)];

  @override
  Widget build(BuildContext context) => _sheet(
    context,
    formKey: _formKey,
    title: _old == null ? 'New category' : 'Edit category',
    children: [
      TextFormField(
        key: const ValueKey('admin-marketplace-category-name'),
        controller: _name,
        maxLength: _limits(ref).categoryName,
        decoration: const InputDecoration(
          labelText: 'Name',
          border: OutlineInputBorder(),
          counterText: '',
        ),
        validator: (v) => (v ?? '').trim().isEmpty ? 'Name is required.' : null,
      ),
      const SizedBox(height: 14),
      TextFormField(
        controller: _shortName,
        maxLength: _limits(ref).categoryShortName,
        decoration: const InputDecoration(
          labelText: 'Short name for the square (optional)',
          hintText: 'e.g. B2B, Food, Ads',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 6),
      TextFormField(
        controller: _description,
        maxLength: _limits(ref).categoryDescription,
        decoration: const InputDecoration(
          labelText: 'What goes in it (optional)',
          hintText: 'e.g. Sarees, shirts, toys',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 6),
      SelectField<String>(
        label: 'Kind',
        options: _choices(widget.options?.kinds, _kind),
        initialValue: _kind,
        onChanged: (v) => setState(() => _kind = v),
      ),
      const SizedBox(height: 14),
      SelectField<String>(
        key: const ValueKey('admin-marketplace-trade-mode'),
        label: 'How it sells',
        options: _choices(widget.options?.tradeModes, _tradeMode),
        initialValue: _tradeMode,
        onChanged: (v) => setState(() => _tradeMode = v),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _icon,
              maxLength: _limits(ref).iconName,
              decoration: const InputDecoration(
                labelText: 'Icon name (optional)',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _orderField(_order)),
        ],
      ),
      SwitchListTile(
        key: const ValueKey('admin-marketplace-tracks-stock'),
        contentPadding: EdgeInsets.zero,
        title: const Text('New / used, with stock'),
        subtitle: const Text(
          'Posts say New or Used: new items keep a stock count, used ones are marked sold.',
        ),
        value: _tracksStock,
        onChanged: (v) => setState(() => _tracksStock = v),
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
  );
}

class _SubCategorySheet extends ConsumerStatefulWidget {
  const _SubCategorySheet({
    required this.categoryId,
    this.existing,
    this.nextOrder = 1,
  });

  final String categoryId;
  final MarketplaceSubCategory? existing;
  final int nextOrder;

  @override
  ConsumerState<_SubCategorySheet> createState() => _SubCategorySheetState();
}

class _SubCategorySheetState extends ConsumerState<_SubCategorySheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _order = TextEditingController(
    text: '${widget.existing?.displayOrder ?? widget.nextOrder}',
  );
  late bool _active = widget.existing?.isActive ?? true;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _order]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final input = MarketplaceSubCategoryInput(
      name: _name.text.trim(),
      displayOrder: int.tryParse(_order.text) ?? widget.nextOrder,
      isActive: _active,
    );
    final repository = ref.read(marketplaceRepositoryProvider);
    final existing = widget.existing;
    await _saveAndClose(
      context,
      ref,
      () => existing == null
          ? repository.createSubCategory(widget.categoryId, input)
          : repository.updateSubCategory(widget.categoryId, existing.id, input),
      '${input.name} saved.',
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) => _sheet(
    context,
    formKey: _formKey,
    title: widget.existing == null ? 'New sub-category' : 'Edit sub-category',
    children: [
      TextFormField(
        key: const ValueKey('admin-marketplace-sub-name'),
        controller: _name,
        maxLength: _limits(ref).categoryName,
        decoration: const InputDecoration(
          labelText: 'Name',
          hintText: 'e.g. Sarees, Fruits, Cricket tournament',
          border: OutlineInputBorder(),
          counterText: '',
        ),
        validator: (v) => (v ?? '').trim().isEmpty ? 'Name is required.' : null,
      ),
      const SizedBox(height: 14),
      _orderField(_order),
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
  );
}

class _FieldSheet extends ConsumerStatefulWidget {
  const _FieldSheet({
    required this.category,
    this.existing,
    this.nextOrder = 1,
  });

  final MarketplaceCategory category;
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

  /// "Applies to" for the whole category — a sub-category id is never empty.
  static const _wholeCategory = '';

  final _formKey = GlobalKey<FormState>();
  late final MarketplaceCategoryField? _old = widget.existing;
  late final _label = TextEditingController(text: _old?.label);
  late final _unit = TextEditingController(text: _old?.unit);
  late final _choices = TextEditingController(text: _old?.options.join(', '));
  late final _order = TextEditingController(
    text: '${_old?.displayOrder ?? widget.nextOrder}',
  );
  late String _type = _old?.fieldType ?? MarketplaceFieldType.text;
  late String _appliesTo = _old?.subCategoryId ?? _wholeCategory;
  late bool _required = _old?.isRequired ?? false;
  late bool _active = _old?.isActive ?? true;
  bool _saving = false;

  List<String> get _options => _commaList(_choices.text);

  @override
  void dispose() {
    for (final c in [_label, _unit, _choices, _order]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final input = MarketplaceFieldInput(
      subCategoryId: _appliesTo == _wholeCategory ? null : _appliesTo,
      label: _label.text.trim(),
      fieldType: _type,
      options: _type == MarketplaceFieldType.select ? _options : const [],
      unit: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
      isRequired: _required,
      displayOrder: int.tryParse(_order.text) ?? widget.nextOrder,
      isActive: _active,
    );
    final repository = ref.read(marketplaceRepositoryProvider);
    final old = _old;
    final categoryId = widget.category.id;
    await _saveAndClose(
      context,
      ref,
      () => old == null
          ? repository.createField(categoryId, input)
          : repository.updateField(categoryId, old.id, input),
      '${input.label} saved.',
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isList = _type == MarketplaceFieldType.select;
    final subs = [...widget.category.subCategories]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return _sheet(
      context,
      formKey: _formKey,
      title: _old == null ? 'New detail' : 'Edit detail',
      children: [
        TextFormField(
          key: const ValueKey('admin-marketplace-field-label'),
          controller: _label,
          maxLength: _limits(ref).fieldLabel,
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
        if (subs.isNotEmpty) ...[
          SelectField<String>(
            key: const ValueKey('admin-marketplace-field-applies-to'),
            label: 'Applies to',
            options: [
              SelectOption(
                _wholeCategory,
                'All of ${widget.category.name}',
                detail: 'Asked in every sub-category',
              ),
              for (final s in subs) SelectOption(s.id, s.name),
            ],
            initialValue: _appliesTo,
            onChanged: (v) => setState(() => _appliesTo = v),
          ),
          const SizedBox(height: 14),
        ],
        SelectField<String>(
          label: 'Type',
          options: _types,
          initialValue: _type,
          onChanged: (v) => setState(() => _type = v),
        ),
        const SizedBox(height: 14),
        if (isList) ...[
          _ChoicesField(
            controller: _choices,
            label: 'Choices, separated by commas',
            hint: 'Petrol, Diesel, Electric',
          ),
          const SizedBox(height: 14),
        ],
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _unit,
                maxLength: _limits(ref).fieldUnit,
                decoration: const InputDecoration(
                  labelText: 'Unit (optional)',
                  hintText: 'km, cents',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _orderField(_order)),
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
    );
  }
}

/// "Red, Maroon , , Pink" → ["Red", "Maroon", "Pink"].
List<String> _commaList(String text) => [
  for (final c in text.split(','))
    if (c.trim().isNotEmpty) c.trim(),
];

/// A detail's choices, typed with commas: at least one, each different.
class _ChoicesField extends StatelessWidget {
  const _ChoicesField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
    ),
    validator: (_) {
      final choices = _commaList(controller.text);
      if (choices.isEmpty) return 'Give at least one choice.';
      final distinct = {for (final c in choices) c.toLowerCase()};
      return distinct.length == choices.length
          ? null
          : 'Each choice must be different.';
    },
  );
}

/// How long each name, label and choice may be, from the server's options.
MarketplaceTextLimits _limits(WidgetRef ref) =>
    ref.watch(marketplaceOptionsProvider).value?.textLimits ??
    const MarketplaceTextLimits();
