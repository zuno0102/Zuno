import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/admin/domain/entities/catalog_category.dart';
import 'package:zuno/features/admin/presentation/providers/admin_catalog_notifier.dart';
import 'package:zuno/shared/widgets/error_banner.dart';

/// The kinds of work the whole product offers.
///
/// Until this existed, adding a category meant a developer hand-writing a migration — which is
/// how "Acrylic painting" was added, and why a business could not list catering work at all.
/// This is the screen that lets the app owner add any new kind of work without one.
class AdminCatalogScreen extends ConsumerWidget {
  const AdminCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(adminCatalogProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Catalogue')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editCategory(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Category'),
      ),
      body: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorBanner(message: error.toString()),
          ),
        ),
        data: (categories) => RefreshIndicator(
          onRefresh: () => ref.refresh(adminCatalogProvider.future),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: categories.length,
            itemBuilder: (_, i) => _CategoryCard(category: categories[i]),
          ),
        ),
      ),
    );
  }

  static Future<void> _editCategory(
    BuildContext context,
    WidgetRef ref, {
    CatalogCategory? existing,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CategorySheet(existing: existing),
  );
}

class _CategoryCard extends ConsumerWidget {
  const _CategoryCard({required this.category});

  final CatalogCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final active = category.subCategories.where((s) => s.isActive).toList();
    final hidden = category.subCategories.where((s) => !s.isActive).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        shape: const Border(),
        title: Row(
          children: [
            Flexible(
              child: Text(
                category.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  // A hidden category is still listed, because this is the only screen it can be
                  // brought back from — but it must not read as live.
                  color: category.isActive
                      ? null
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (!category.isActive) ...[
              const SizedBox(width: 8),
              const _HiddenChip(),
            ],
          ],
        ),
        subtitle: Text(
          [
            category.serviceCount == 1
                ? '1 service'
                : '${category.serviceCount} services',
            if (active.isNotEmpty) '${active.length} sub-categories',
            if (hidden.isNotEmpty) '${hidden.length} hidden',
          ].join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Edit category',
          onPressed: () => AdminCatalogScreen._editCategory(
            context,
            ref,
            existing: category,
          ),
        ),
        children: [
          for (final sub in [...active, ...hidden])
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 28, right: 8),
              title: Text(
                sub.name,
                style: sub.isActive
                    ? null
                    : TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              trailing: sub.isActive
                  ? const Icon(Icons.edit_outlined, size: 19)
                  : const _HiddenChip(),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => _SubCategorySheet(
                  categoryId: category.id,
                  existing: sub,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => _SubCategorySheet(categoryId: category.id),
                ),
                icon: const Icon(Icons.add, size: 19),
                label: const Text('Sub-category'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HiddenChip extends StatelessWidget {
  const _HiddenChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Hidden',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Adding or editing a main category.
class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet({this.existing});

  final CatalogCategory? existing;

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.existing?.name,
  );
  late final _descriptionController = TextEditingController(
    text: widget.existing?.description,
  );
  late final _orderController = TextEditingController(
    text: (widget.existing?.displayOrder ?? 0).toString(),
  );
  late bool _isActive = widget.existing?.isActive ?? true;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(adminCatalogProvider.notifier)
          .saveCategory(
            id: widget.existing?.id,
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            displayOrder: int.tryParse(_orderController.text.trim()) ?? 0,
            isActive: _isActive,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // Kept on the sheet rather than in a snackbar: the message is usually "there is already a
      // category called X", which is only useful next to the field that caused it.
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;

    return _SheetShell(
      title: existing == null ? 'New category' : 'Edit category',
      formKey: _formKey,
      isSaving: _isSaving,
      errorMessage: _errorMessage,
      onSave: _save,
      children: [
        TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Give it a name.' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _descriptionController,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Description (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _orderController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Display order',
            border: OutlineInputBorder(),
            helperText: 'Lower numbers appear first',
          ),
        ),
        const SizedBox(height: 6),
        _VisibilitySwitch(
          value: _isActive,
          onChanged: (v) => setState(() => _isActive = v),
          inUseWarning: existing != null && existing.isInUse && !_isActive
              ? '${existing.serviceCount} service(s) are listed under this. '
                    'Hiding it keeps every one of them working — it only stops '
                    'new services being listed here.'
              : null,
        ),
      ],
    );
  }
}

/// Adding or editing a sub-category.
class _SubCategorySheet extends ConsumerStatefulWidget {
  const _SubCategorySheet({required this.categoryId, this.existing});

  final String categoryId;
  final CatalogSubCategory? existing;

  @override
  ConsumerState<_SubCategorySheet> createState() => _SubCategorySheetState();
}

class _SubCategorySheetState extends ConsumerState<_SubCategorySheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.existing?.name,
  );
  late final _orderController = TextEditingController(
    text: (widget.existing?.displayOrder ?? 0).toString(),
  );
  late bool _isActive = widget.existing?.isActive ?? true;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(adminCatalogProvider.notifier)
          .saveSubCategory(
            id: widget.existing?.id,
            categoryId: widget.categoryId,
            name: _nameController.text.trim(),
            displayOrder: int.tryParse(_orderController.text.trim()) ?? 0,
            isActive: _isActive,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) => _SheetShell(
    title: widget.existing == null ? 'New sub-category' : 'Edit sub-category',
    formKey: _formKey,
    isSaving: _isSaving,
    errorMessage: _errorMessage,
    onSave: _save,
    children: [
      TextFormField(
        controller: _nameController,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Name',
          border: OutlineInputBorder(),
        ),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Give it a name.' : null,
      ),
      const SizedBox(height: 14),
      TextFormField(
        controller: _orderController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Display order',
          border: OutlineInputBorder(),
          helperText: 'Lower numbers appear first',
        ),
      ),
      const SizedBox(height: 6),
      _VisibilitySwitch(
        value: _isActive,
        onChanged: (v) => setState(() => _isActive = v),
      ),
      // There is no "move to another category" control on purpose: items are already priced
      // under this sub-category by services in this category, and the server refuses a move.
      const SizedBox(height: 4),
      Text(
        'A sub-category stays in the category it was created under.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

/// Shared chrome for the two sheets — same title, error slot, and save button.
class _SheetShell extends StatelessWidget {
  const _SheetShell({
    required this.title,
    required this.formKey,
    required this.isSaving,
    required this.errorMessage,
    required this.onSave,
    required this.children,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final bool isSaving;
  final String? errorMessage;
  final VoidCallback onSave;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              ...children,
              if (errorMessage != null) ...[
                const SizedBox(height: 14),
                ErrorBanner(message: errorMessage!),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: isSaving ? null : onSave,
                child: isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Visible-or-hidden, worded so it is clear nothing is being deleted.
class _VisibilitySwitch extends StatelessWidget {
  const _VisibilitySwitch({
    required this.value,
    required this.onChanged,
    this.inUseWarning,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? inUseWarning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: value,
          onChanged: onChanged,
          title: const Text('Visible'),
          subtitle: Text(
            value
                ? 'Businesses can list services under this'
                : 'Hidden from the pickers. Existing services keep working.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        if (inUseWarning != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(inUseWarning!, style: theme.textTheme.bodySmall),
          ),
      ],
    );
  }
}
