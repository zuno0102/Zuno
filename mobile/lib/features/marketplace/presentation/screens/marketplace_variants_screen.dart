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
  late final _variants = MarketplaceVariantList(
    widget.post.variants,
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
      await ref
          .read(marketplaceRepositoryProvider)
          .replaceVariants(widget.post.id, _variants.items);
      reloadMarketplace(ref);
      messenger.showSuccess(
        '${widget.post.title}: colours and sizes saved — '
        '${_variants.totalStock} in stock.',
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
            MarketplaceVariantsSection(
              variants: _variants,
              alsoTaken: () => const [],
              mrp: () => post.originalPrice,
              defaultPrice: () => post.price,
              limits: options?.textLimits ?? const MarketplaceTextLimits(),
              maxQuantity:
                  options?.maxQuantity ?? marketplaceDefaultMaxQuantity,
              title: 'Colours and sizes',
              hint:
                  'The same product in another colour or size — a saree in Red and Green, '
                  'a shirt in M, L and XL — each with its own price and stock.',
              addLabel: 'Add colour / size',
            ),
            if (_variants.isEmpty) ...[
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
              onPressed: _changed && !_variants.isEmpty ? _save : null,
              isLoading: _isSaving,
            ),
          ],
        ),
      ),
    );
  }
}
