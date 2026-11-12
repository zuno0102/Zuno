import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/router/push_screen.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:zuno/features/marketplace/presentation/screens/marketplace_stock_screen.dart';
import 'package:zuno/features/marketplace/presentation/screens/marketplace_variants_screen.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_post_form_sheet.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_post_lines.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/confirm_dialog.dart';
import 'package:zuno/shared/widgets/empty_state.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/primary_button.dart';
import 'package:zuno/shared/widgets/stock_count_stepper.dart';
import 'package:zuno/shared/widgets/stock_figure_row.dart';

/// One product from the Stock page, in two tabs, as Rent's are: **Stock** — its figures and the
/// quick count change, per colour / size — and **Orders** — its customers' orders.
class MarketplaceStockItemScreen extends ConsumerWidget {
  const MarketplaceStockItemScreen({required this.postId, super.key});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The latest figures, so a saved count shows at once.
    final post = ref
        .watch(marketplaceStockProvider)
        .value
        ?.firstWhereOrNull((p) => p.id == postId);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(post?.title ?? 'Stock'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Stock'),
              Tab(text: 'Orders'),
            ],
          ),
        ),
        body: post == null
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _StockTab(key: ValueKey(post.id), post: post),
                  const _OrdersTab(),
                ],
              ),
      ),
    );
  }
}

/// The figures, then which colour / size and how many of it the business has now.
class _StockTab extends ConsumerStatefulWidget {
  const _StockTab({required this.post, super.key});

  final MarketplacePost post;

  @override
  ConsumerState<_StockTab> createState() => _StockTabState();
}

class _StockTabState extends ConsumerState<_StockTab>
    with AutomaticKeepAliveClientMixin {
  /// The colour / size being counted; null for a product with one stock count.
  late String? _variantId = widget.post.variants.firstOrNull?.id;
  late int _count = _saved;
  late final _countController = TextEditingController(text: '$_count');
  bool _isSaving = false;
  String? _inputError;
  String? _saveError;

  /// Kept while the Orders tab is open, so a half-made change is not lost by a look at orders.
  @override
  bool get wantKeepAlive => true;

  MarketplaceVariant? get _variant =>
      widget.post.variants.firstWhereOrNull((v) => v.id == _variantId);

  /// The saved count of what is chosen.
  int get _saved => _variant?.stock ?? widget.post.quantity ?? 0;

  int get _max =>
      ref.read(marketplaceOptionsProvider).value?.maxQuantity ??
      marketplaceDefaultMaxQuantity;

  bool get _changed => _count != _saved;

  /// The name in messages: "Silk saree · Red · M".
  String get _name => [widget.post.title, ?_variant?.name].join(' · ');

  @override
  void didUpdateWidget(_StockTab old) {
    super.didUpdateWidget(old);
    // The colour / size chosen was removed on Manage variants: the first one left.
    if (_variant == null) _variantId = widget.post.variants.firstOrNull?.id;
    // Saved, or changed elsewhere: show the count as it now is, unless one is being typed.
    if (!_changed || _isSaving) _show(_saved);
  }

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  void _show(int value) {
    _count = value;
    _inputError = null;
    final text = '$value';
    if (_countController.text != text) {
      _countController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _step(int delta) =>
      setState(() => _show((_count + delta).clamp(0, _max)));

  void _typed(String text) {
    final parsed = int.tryParse(text);
    setState(() {
      if (parsed == null) {
        _inputError = 'Enter a number; 0 is out of stock.';
      } else if (parsed > _max) {
        _inputError = 'At most $_max.';
      } else {
        _count = parsed;
        _inputError = null;
      }
    });
  }

  Future<void> _choose(String variantId) async {
    if (variantId == _variantId) return;
    if (_changed && !await _discard()) return;
    setState(() {
      _variantId = variantId;
      _saveError = null;
      _show(_saved);
    });
  }

  Future<bool> _discard() => showConfirmDialog(
    context,
    title: 'Discard changes?',
    message: 'The new stock for "$_name" has not been saved.',
    confirmLabel: 'Discard',
    cancelLabel: 'Keep editing',
    destructive: true,
  );

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_inputError != null || !_changed) return;

    // Before the await, as the app's messages need: the screen's colours and its messenger.
    final messenger = AppMessenger.of(context);
    final name = _name;
    final count = _count;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .updateStock(widget.post.id, count, variantId: _variant?.id);
      reloadMarketplace(ref);
      messenger.showSuccess(
        count == 0 ? '$name: out of stock.' : '$name: $count in stock.',
      );
    } catch (e) {
      if (mounted) setState(() => _saveError = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final post = widget.post;
    final out = marketplaceLinesOut(post);
    final price = marketplacePriceLine(post);

    return PopScope(
      canPop: !_changed || _isSaving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _discard()) navigator.pop();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: [
                  StockFigureRow(
                    label: 'In stock',
                    value: post.quantity ?? 0,
                    tone: (post.quantity ?? 0) > 0
                        ? StatusTone.success
                        : StatusTone.danger,
                  ),
                  if (post.variants.isNotEmpty)
                    StockFigureRow(
                      label: 'Colours / sizes',
                      value: post.variants.length,
                    ),
                  StockFigureRow(
                    label: 'Run out',
                    value: out,
                    tone: out > 0 ? StatusTone.danger : StatusTone.waiting,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(post.categoryLine, style: theme.textTheme.bodyMedium),
          if (price != null) ...[
            const SizedBox(height: 2),
            Text(
              price,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (post.variants.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Which colour / size', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, v) in post.variants.indexed)
                  ChoiceChip(
                    key: ValueKey('marketplace-stock-variant-$i'),
                    label: Text('${v.name} · ${v.stock}'),
                    selected: v.id == _variantId,
                    onSelected: (_) => _choose(v.id!),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Text(
            _variant == null ? 'Stock you have' : 'Stock of ${_variant!.name}',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          StockCountStepper(
            fieldKey: const ValueKey('marketplace-stock-count'),
            controller: _countController,
            onStep: _step,
            onTyped: _typed,
            canLess: _count > 0,
            canMore: _count < _max,
            errorText: _inputError,
          ),
          const SizedBox(height: 8),
          Text(
            'Sold some in the shop? Take them off. A new purchase came in? Add it. '
            '0 shows it as out of stock.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_saveError != null) ...[
            const SizedBox(height: 12),
            ErrorBanner(message: _saveError!),
          ],
          const SizedBox(height: 20),
          PrimaryButton(
            key: const ValueKey('marketplace-stock-save'),
            label: 'Save stock',
            onPressed: _changed && _inputError == null ? _save : null,
            isLoading: _isSaving,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            key: const ValueKey('marketplace-stock-variants'),
            onPressed: () =>
                pushScreen(context, MarketplaceVariantsScreen(post: post)),
            icon: const Icon(Icons.palette_outlined),
            label: const Text('Manage colours and sizes'),
          ),
          TextButton.icon(
            onPressed: () =>
                showMarketplacePostFormSheet(context, existing: post),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit all details'),
          ),
        ],
      ),
    );
  }
}

/// The product's customers' orders. Customers cannot buy on the Marketplace yet, so for now it
/// says where they will be.
class _OrdersTab extends StatelessWidget {
  const _OrdersTab();

  @override
  Widget build(BuildContext context) => const EmptyState(
    icon: Icons.receipt_long_outlined,
    title: 'No orders yet',
    message:
        'When customers can buy on the Marketplace, each order of this product shows here '
        'and takes its stock down by itself.',
  );
}
