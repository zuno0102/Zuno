import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_order.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_order_providers.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/primary_button.dart';

Future<void> showMarketplacePaymentSettingsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const MarketplacePaymentSettingsSheet(),
    );

/// How customers may pay for the business's products: cash on delivery, online pay, or both. At
/// least one stays on. The names and the line under each come from the server's table.
class MarketplacePaymentSettingsSheet extends ConsumerStatefulWidget {
  const MarketplacePaymentSettingsSheet({super.key});

  @override
  ConsumerState<MarketplacePaymentSettingsSheet> createState() =>
      _MarketplacePaymentSettingsSheetState();
}

class _MarketplacePaymentSettingsSheetState
    extends ConsumerState<MarketplacePaymentSettingsSheet> {
  /// Null until the saved settings arrive; then what the switches show.
  bool? _cash;
  bool? _online;
  bool _isSaving = false;
  String? _error;

  static const _cashCode = 'CashOnDelivery';
  static const _onlineCode = 'Online';

  Future<void> _save() async {
    final cash = _cash ?? true;
    final online = _online ?? true;
    if (!cash && !online) {
      setState(() => _error = 'Keep at least one way for customers to pay.');
      return;
    }

    final messenger = AppMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await ref
          .read(marketplaceOrderRepositoryProvider)
          .updatePaymentSettings(
            acceptsCashOnDelivery: cash,
            acceptsOnlinePay: online,
          );
      ref.invalidate(marketplacePaymentSettingsProvider);
      messenger.showSuccess('Payment choices saved.');
      navigator.pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = ref.watch(marketplaceOptionsProvider).value;
    final settingsAsync = ref.watch(marketplacePaymentSettingsProvider);
    final settings = settingsAsync.value;
    final cash = _cash ?? settings?.acceptsCashOnDelivery ?? true;
    final online = _online ?? settings?.acceptsOnlinePay ?? true;

    MarketplaceOption? method(String code) =>
        options?.paymentMethods.where((m) => m.code == code).firstOrNull;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'How customers pay',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'For orders of your products. Customers see only the ways that are on.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (_error != null) ...[
            ErrorBanner(message: _error!),
            const SizedBox(height: 8),
          ],
          if (settingsAsync.hasError && settings == null) ...[
            ErrorBanner(message: settingsAsync.error.toString()),
            const SizedBox(height: 8),
          ],
          SwitchListTile(
            key: const ValueKey('marketplace-pay-cash'),
            contentPadding: EdgeInsets.zero,
            title: Text(method(_cashCode)?.name ?? 'Cash on delivery'),
            subtitle: Text(
              method(_cashCode)?.detail ??
                  'The customer pays the courier or you when it arrives.',
            ),
            value: cash,
            onChanged: settings == null
                ? null
                : (v) => setState(() => _cash = v),
          ),
          SwitchListTile(
            key: const ValueKey('marketplace-pay-online'),
            contentPadding: EdgeInsets.zero,
            title: Text(method(_onlineCode)?.name ?? 'Online pay'),
            subtitle: Text(
              method(_onlineCode)?.detail ??
                  'The order is confirmed only after the payment goes through.',
            ),
            value: online,
            onChanged: settings == null
                ? null
                : (v) => setState(() => _online = v),
          ),
          const SizedBox(height: 8),
          Text(
            settings?.onlinePayAvailable ?? true
                ? 'Online payments are collected by Zuno and paid to you. Each order shows the amount due to you.'
                : 'Online pay is not available just now, so customers see cash on delivery only.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            key: const ValueKey('marketplace-pay-save'),
            label: 'Save',
            isLoading: _isSaving,
            onPressed: settings == null ? null : _save,
          ),
        ],
      ),
    );
  }
}

/// The current choice in a few words, for the tile that opens the sheet.
String marketplacePaymentSummary(MarketplacePaymentSettings? settings) {
  if (settings == null) return 'Cash on delivery and online pay';
  return switch ((settings.acceptsCashOnDelivery, settings.acceptsOnlinePay)) {
    (true, true) => 'Cash on delivery and online pay',
    (true, false) => 'Cash on delivery only',
    _ => 'Online pay only',
  };
}
