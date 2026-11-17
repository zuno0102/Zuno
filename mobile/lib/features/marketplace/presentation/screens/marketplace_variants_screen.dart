import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_product_sections.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/confirm_dialog.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/primary_button.dart';

/// "Manage variants": a new product's colours and sizes — a saree in Red and Green, a shirt in M, L
/// and XL — each with its own price and stock, added, edited and removed like a service's items, and
/// saved without the whole form.
class MarketplaceVariantsScreen extends ConsumerStatefulWidget {
  const MarketplaceVariantsScreen({required this.post, super.key});

  final MarketplacePost post;

  @override
  ConsumerState<MarketplaceVariantsScreen> createState() =>
      _MarketplaceVariantsScreenState();
}

class _MarketplaceVariantsScreenState
    extends ConsumerState<MarketplaceVariantsScreen> {
  /// The main product: the first colour / size, typed on the product form. Shown here with its own
  /// stock, but not switched off or removed here — the product's Active switch is its on/off.
  late final MarketplaceVariant? _main = widget.post.variants.firstOrNull;

  /// The colours and sizes added under the main one, each switched on and off on its own.
  late final _variants = MarketplaceVariantList(
    widget.post.variants.skip(1).toList(),
    price: widget.post.price,
  )..addListener(_rebuild);
  bool _changed = false;
  bool _isSaving = false;
  String? _saveError;

  void _rebuild() => setState(() => _changed = true);

  @override
  void dispose() {
    _variants.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Before the await, as the app's messages need: the screen's colours and its messenger.
    final messenger = AppMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      final repository = ref.read(marketplaceRepositoryProvider);
      final saved = await repository.replaceVariants(widget.post.id, [
        // The main product goes back first, unchanged and on sale.
        if (_main case final main?)
          MarketplaceVariant(
            id: main.id,
            colour: main.colour,
            size: main.size,
            price: main.price ?? widget.post.price,
            stock: main.stock,
            isActive: true,
            customDetails: main.customDetails,
          ),
        ..._variants.items,
      ]);
      // Each colour / size's own photos, now that every one has an id.
      await uploadMarketplaceVariantPhotos(
        repository,
        saved,
        _variants.pendingPhotos,
      );
      reloadMarketplace(ref);
      messenger.showSuccess(
        '${widget.post.title}: colours and sizes saved — '
        '${(_main?.stock ?? 0) + _variants.totalStock} in stock.',
      );
      navigator.pop();
    } catch (e) {
      if (mounted) setState(() => _saveError = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = ref.watch(marketplaceOptionsProvider).value;
    final post = widget.post;

    return PopScope(
      canPop: !_changed || _isSaving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final discard = await showConfirmDialog(
          context,
          title: 'Discard changes?',
          message:
              'The colours and sizes of "${post.title}" have not been saved.',
          confirmLabel: 'Discard',
          cancelLabel: 'Keep editing',
          destructive: true,
        );
        if (discard) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(post.title)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            if (_main case final main?) ...[
              _MainProductLine(main: main),
              const SizedBox(height: 16),
            ],
            MarketplaceVariantsSection(
              variants: _variants,
              // The main's colour / size is taken too: the same one twice is refused.
              alsoTaken: () => [?_main],
              mrp: () => post.originalPrice,
              defaultPrice: () => post.price,
              limits: options?.textLimits ?? const MarketplaceTextLimits(),
              maxQuantity:
                  options?.maxQuantity ?? marketplaceDefaultMaxQuantity,
              photoSlots:
                  options?.variantImageSlots ??
                  marketplaceDefaultVariantImageSlots,
              title: 'Colours and sizes',
              hint:
                  'The same product in another colour or size — a saree in Red and Green, '
                  'a shirt in M, L and XL — each with its own price and stock.',
              addLabel: 'Add colour / size',
              onChanged: (change) => AppMessenger.of(context).showSuccess(
                '$change — not saved yet. Tap Save colours and sizes.',
              ),
            ),
            if (_main == null && _variants.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Keep at least one. To sell it as one stock count, use Edit.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (_saveError != null) ...[
              const SizedBox(height: 12),
              ErrorBanner(message: _saveError!),
            ],
            const SizedBox(height: 20),
            PrimaryButton(
              key: const ValueKey('marketplace-variants-save'),
              label: 'Save colours and sizes',
              onPressed: _changed && (_main != null || !_variants.isEmpty)
                  ? _save
                  : null,
              isLoading: _isSaving,
            ),
          ],
        ),
      ),
    );
  }
}

/// The main product at the top of Manage variants: its colour / size and its own stock, with
/// "Out of stock" at 0. Not switched off here — the product's Active switch (Edit) is its on/off.
class _MainProductLine extends StatelessWidget {
  const _MainProductLine({required this.main});

  final MarketplaceVariant main;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empty = main.stock <= 0;
    return Card(
      key: const ValueKey('marketplace-variants-main'),
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.inventory_2_outlined),
        title: Text('Main product · ${main.name}'),
        subtitle: Text(
          empty
              ? 'Out of stock. Change its stock on the Stock page or with Edit.'
              : '${main.stock} in stock. Change it on the Stock page or with Edit.',
          style: empty ? TextStyle(color: theme.colorScheme.error) : null,
        ),
      ),
    );
  }
}
