import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/rental/domain/entities/rental_item.dart';
import 'package:zuno/features/rental/presentation/providers/rental_providers.dart';
import 'package:zuno/features/rental/presentation/screens/business_rentals_tab.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_item_form_sheet.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/confirm_dialog.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/primary_button.dart';

/// The most of one item a business can list — the Rent server's `Rent:MaxQuantityOwned`.
const rentalMaxQuantity = 100000;

/// Changes how many of an item the business has — − / +, the quick jumps, or typed — and whether
/// it can be rented now. Saves just those two, so a new delivery of chairs is a few taps, not the
/// full item form. Sits in the item's Stock tab.
///
/// Never goes below [quantityOut]: pieces with customers are still the business's.
class RentalStockManagePanel extends ConsumerStatefulWidget {
  const RentalStockManagePanel({
    required this.item,
    this.quantityOut = 0,
    super.key,
  });

  final RentalItem item;

  /// Pieces out with customers now — the lowest the quantity can be set to.
  final int quantityOut;

  @override
  ConsumerState<RentalStockManagePanel> createState() =>
      _RentalStockManagePanelState();
}

class _RentalStockManagePanelState extends ConsumerState<RentalStockManagePanel>
    with AutomaticKeepAliveClientMixin {
  late int _quantity = widget.item.quantityOwned;
  late bool _isAvailable = widget.item.isAvailable;
  late final _quantityController = TextEditingController(text: '$_quantity');
  bool _isSaving = false;

  /// What is wrong with the typed count, shown under the box.
  String? _inputError;

  /// Why the save failed, shown above the button.
  String? _saveError;

  /// Kept while the Orders tab is open, so a half-made change is not lost by a look at orders.
  @override
  bool get wantKeepAlive => true;

  int get _minimum => math.max(1, widget.quantityOut);

  bool get _changed =>
      _quantity != widget.item.quantityOwned ||
      _isAvailable != widget.item.isAvailable;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  /// Moves the count by [delta], never below the minimum or above the limit.
  void _step(int delta) =>
      _setQuantity((_quantity + delta).clamp(_minimum, rentalMaxQuantity));

  void _setQuantity(int value) {
    setState(() {
      _quantity = value;
      _inputError = null;
    });
    final text = '$value';
    if (_quantityController.text != text) {
      _quantityController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _typed(String text) {
    final parsed = int.tryParse(text);
    setState(() {
      if (parsed == null || parsed < _minimum) {
        _inputError = widget.quantityOut > 1
            ? '${widget.quantityOut} are out with customers, so at least '
                  '${widget.quantityOut}.'
            : 'At least 1.';
      } else if (parsed > rentalMaxQuantity) {
        _inputError = 'At most $rentalMaxQuantity.';
      } else {
        _quantity = parsed;
        _inputError = null;
      }
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_inputError != null || !_changed) return;

    // Before the await, as the app's messages need: the screen's colours and its messenger.
    final messenger = AppMessenger.of(context);
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      await ref
          .read(rentalRepositoryProvider)
          .updateStock(
            widget.item.id,
            quantityOwned: _quantity,
            isAvailable: _isAvailable,
          );
      reloadRentals(ref);
      if (!mounted) return;
      messenger.showSuccess(
        'Stock saved — ${widget.item.name}: $_quantity in total.',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _saveError = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _leave() async {
    final discard = await showConfirmDialog(
      context,
      title: 'Discard changes?',
      message: 'The new stock for "${widget.item.name}" has not been saved.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
      destructive: true,
    );
    if (discard && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final priceTypes =
        ref.watch(rentalPriceTypesProvider).value ??
        const <RentalPriceTypeOption>[];
    final item = widget.item;

    return PopScope(
      canPop: !_changed || _isSaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(item.categoryLine, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 2),
          Text(
            rentalRate(item, priceTypes),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Total you have',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'One less',
                iconSize: 28,
                onPressed: _quantity > _minimum ? () => _step(-1) : null,
                icon: const Icon(Icons.remove),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const ValueKey('stock-quantity'),
                  controller: _quantityController,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    errorText: _inputError,
                    errorMaxLines: 2,
                  ),
                  onChanged: _typed,
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                tooltip: 'One more',
                iconSize: 28,
                onPressed: _quantity < rentalMaxQuantity
                    ? () => _step(1)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // The jumps a stock count really makes: a broken few, a new delivery.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              for (final delta in const [-10, 10, 50])
                ActionChip(
                  label: Text(delta > 0 ? '+$delta' : '$delta'),
                  onPressed: () => _step(delta),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Available now'),
            subtitle: const Text(
              'Turn off while it cannot be rented, e.g. under repair.',
            ),
            value: _isAvailable,
            onChanged: (value) => setState(() => _isAvailable = value),
          ),
          if (_saveError != null) ...[
            const SizedBox(height: 8),
            ErrorBanner(message: _saveError!),
          ],
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Save stock',
            onPressed: _changed && _inputError == null ? _save : null,
            isLoading: _isSaving,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => showRentalItemFormSheet(context, existing: item),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit all details'),
          ),
        ],
      ),
    );
  }
}
