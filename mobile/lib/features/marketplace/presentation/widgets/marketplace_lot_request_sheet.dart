import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_customer.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_customer_providers.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/primary_button.dart';

Future<void> showMarketplaceLotRequestSheet(
  BuildContext context,
  MarketplacePostDetail detail,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => MarketplaceLotRequestSheet(detail: detail),
);

/// A buyer asks for a B2B lot: how much (at least the smallest order, no more than is there) and a
/// note. The seller answers; once accepted the two talk directly.
class MarketplaceLotRequestSheet extends ConsumerStatefulWidget {
  const MarketplaceLotRequestSheet({required this.detail, super.key});

  final MarketplacePostDetail detail;

  @override
  ConsumerState<MarketplaceLotRequestSheet> createState() =>
      _MarketplaceLotRequestSheetState();
}

class _MarketplaceLotRequestSheetState
    extends ConsumerState<MarketplaceLotRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _quantity = TextEditingController(
    text: '${widget.detail.card.minOrderQuantity ?? 1}',
  );
  final _message = TextEditingController();
  bool _submitted = false;
  bool _saving = false;
  String? _error;

  MarketplaceCard get _card => widget.detail.card;

  String get _unit => _card.priceUnit == null ? '' : ' ${_card.priceUnit}';

  int get _count => int.tryParse(_quantity.text.trim()) ?? 0;

  @override
  void dispose() {
    _quantity.dispose();
    _message.dispose();
    super.dispose();
  }

  String? _checkQuantity(String? value) {
    final count = int.tryParse(value?.trim() ?? '');
    final least = _card.minOrderQuantity ?? 1;
    final most = _card.quantity;
    if (count == null || count < least) {
      return 'The smallest order is $least$_unit.';
    }
    if (most != null && count > most) return 'Only $most$_unit available.';
    return null;
  }

  Future<void> _send() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final messenger = AppMessenger.of(context);
    try {
      final message = _message.text.trim();
      await ref
          .read(marketplaceCustomerRepositoryProvider)
          .askForLot(_card.id, _count, message.isEmpty ? null : message);
      ref.invalidate(myMarketplaceRequestsProvider);
      navigator.pop();
      messenger.showSuccess(
        'Request sent to ${_card.businessName}. You will see their answer in Orders.',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = _card.price;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.always
              : AutovalidateMode.disabled,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Request ${_card.title}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                [
                  if (price != null) '${rupees(price)}$_unit',
                  if (_card.minOrderQuantity case final least?)
                    'smallest order $least$_unit',
                  if (_card.quantity case final most?) '$most$_unit available',
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                ErrorBanner(message: _error!),
                const SizedBox(height: 12),
              ],
              TextFormField(
                key: const ValueKey('marketplace-lot-quantity'),
                controller: _quantity,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'How much',
                  suffixText: _card.priceUnit,
                ),
                validator: _checkQuantity,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('marketplace-lot-message'),
                controller: _message,
                minLines: 2,
                maxLines: 4,
                maxLength: _messageLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Note to the seller (optional)',
                  hintText: 'E.g. weekly supply, delivery to your town',
                ),
              ),
              if (price != null && _count > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '$_count$_unit × ${rupees(price)} = ${rupees(price * _count)}',
                  key: const ValueKey('marketplace-lot-total'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'The seller answers in the app. Once they accept, they get your number to call you.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                key: const ValueKey('marketplace-lot-send'),
                label: 'Send request',
                isLoading: _saving,
                onPressed: _saving ? null : _send,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The server's own limit on a note.
  static const _messageLength = 500;
}
