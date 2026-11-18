import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zuno/core/utils/upload_image.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_order.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_order_providers.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_order_card.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/primary_button.dart';
import 'package:zuno/shared/widgets/select_field.dart';

/// Opens the ship sheet for [order]; returns the order once shipped, or null when closed.
Future<MarketplaceOrder?> showMarketplaceShipSheet(
  BuildContext context,
  MarketplaceOrder order,
) => showModalBottomSheet<MarketplaceOrder>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => MarketplaceShipSheet(order: order),
);

/// Letters, digits and dashes — what the server accepts as a tracking number.
final _trackingNumberPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9\-]*$');

/// The business sent the parcel with a local courier: which one, the tracking number on its
/// receipt, and a photo of the receipt if it likes. The customer sees the courier and number.
class MarketplaceShipSheet extends ConsumerStatefulWidget {
  const MarketplaceShipSheet({required this.order, super.key});

  final MarketplaceOrder order;

  @override
  ConsumerState<MarketplaceShipSheet> createState() =>
      _MarketplaceShipSheetState();
}

class _MarketplaceShipSheetState extends ConsumerState<MarketplaceShipSheet> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _courierName = TextEditingController();
  String? _courier;
  Uint8List? _receipt;
  bool _isSaving = false;
  String? _error;

  /// The tracking number limit, the same as the server's.
  static const _maxNumber = 40;

  @override
  void dispose() {
    _number.dispose();
    _courierName.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    try {
      final bytes = await compressForUpload(
        await picked.readAsBytes(),
        ref.read(currentAppOptionsProvider),
      );
      if (mounted) setState(() => _receipt = bytes);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not use that photo. Try a different one.',
        );
      }
    }
  }

  Future<void> _save(List<MarketplaceCourier> couriers) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final messenger = AppMessenger.of(context);
    final navigator = Navigator.of(context);
    final repository = ref.read(marketplaceOrderRepositoryProvider);
    final courier = couriers.firstWhere((c) => c.code == _courier);
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      var shipped = await repository.ship(
        widget.order.id,
        courierCode: courier.code,
        trackingNumber: _number.text.trim(),
        courierName: courier.takesCustomName ? _courierName.text.trim() : null,
      );
      final receipt = _receipt;
      if (receipt != null) {
        try {
          shipped = await repository.uploadReceipt(shipped.id, receipt);
        } catch (_) {
          // Shipped is saved; only the photo did not go. It can be added from the order's page.
          messenger.showInfo(
            'Marked shipped. The receipt photo did not upload; add it from the order.',
          );
        }
      }
      reloadMarketplaceOrders(ref);
      messenger.showSuccess(
        'Order #${shipped.number} shipped with ${shipped.courierName}.',
      );
      navigator.pop(shipped);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final couriers =
        ref.watch(marketplaceOptionsProvider).value?.couriers ??
        const <MarketplaceCourier>[];
    final chosen = couriers.where((c) => c.code == _courier).firstOrNull;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'How did you send it?',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${widget.order.quantity} × ${widget.order.titleWithVariant} for ${widget.order.customerName}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                ErrorBanner(message: _error!),
                const SizedBox(height: 12),
              ],
              SelectField<String>(
                key: const ValueKey('marketplace-ship-courier'),
                label: 'Courier',
                initialValue: _courier,
                options: [
                  for (final c in couriers) SelectOption(c.code, c.name),
                ],
                validator: (v) => v == null ? 'Choose the courier.' : null,
                onChanged: (v) => setState(() => _courier = v),
              ),
              if (chosen?.takesCustomName ?? false) ...[
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('marketplace-ship-courier-name'),
                  controller: _courierName,
                  maxLength: 60,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: "Courier's name",
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? "Type the courier's name."
                      : null,
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('marketplace-ship-number'),
                controller: _number,
                maxLength: _maxNumber,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Tracking number',
                  helperText: "As printed on the courier's receipt",
                ),
                validator: (v) {
                  final number = v?.trim() ?? '';
                  if (number.isEmpty) {
                    return "Enter the tracking number from the courier's receipt.";
                  }
                  return _trackingNumberPattern.hasMatch(number)
                      ? null
                      : 'Use only letters, digits and dashes.';
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('marketplace-ship-receipt'),
                onPressed: _isSaving ? null : _pickReceipt,
                icon: Icon(
                  _receipt == null
                      ? Icons.add_a_photo_outlined
                      : Icons.check_circle_outline,
                ),
                label: Text(
                  _receipt == null
                      ? 'Add a photo of the courier receipt (optional)'
                      : 'Receipt photo added · change',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                chosen?.hasTrackingLink ?? false
                    ? "The customer will see the courier and number, with a Track button that opens the courier's page."
                    : 'The customer will see the courier and the number to track it with.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                key: const ValueKey('marketplace-ship-save'),
                label: 'Save · Shipped',
                isLoading: _isSaving,
                onPressed: () => _save(couriers),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
