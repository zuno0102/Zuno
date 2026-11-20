import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/payments/razorpay_checkout.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/core/utils/validators.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/auth/presentation/providers/auth_state.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_customer.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_order.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';
import 'package:zuno/features/marketplace/domain/marketplace_customer_repository.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_customer_providers.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/primary_button.dart';

/// Shows the Buy now sheet for [detail] in the colour / size [variant]. Returns the order placed,
/// or null when the customer closed it.
Future<MarketplaceOrder?> showMarketplaceOrderSheet(
  BuildContext context, {
  required MarketplacePostDetail detail,
  MarketplaceVariant? variant,
}) => showModalBottomSheet<MarketplaceOrder>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => MarketplaceOrderSheet(detail: detail, variant: variant),
);

/// After an order changes: the customer's lists and the order's own page read again.
void reloadMyMarketplaceOrders(WidgetRef ref) => ref
  ..invalidate(myMarketplaceOrdersProvider)
  ..invalidate(myMarketplaceOrderProvider);

/// A customer buys a product: how many, where it goes, the mobile the courier calls, and how they
/// pay — only the ways this seller takes. The server checks it all again and holds the stock.
class MarketplaceOrderSheet extends ConsumerStatefulWidget {
  const MarketplaceOrderSheet({required this.detail, this.variant, super.key});

  final MarketplacePostDetail detail;
  final MarketplaceVariant? variant;

  @override
  ConsumerState<MarketplaceOrderSheet> createState() =>
      _MarketplaceOrderSheetState();
}

class _MarketplaceOrderSheetState extends ConsumerState<MarketplaceOrderSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController(text: '1');
  final _address = TextEditingController();
  final _pincode = TextEditingController();
  final _phone = TextEditingController();
  late String _method = widget.detail.paymentMethods.first.code;
  bool _submitted = false;
  bool _saving = false;
  String? _error;

  int get _stock => widget.variant?.stock ?? widget.detail.card.quantity ?? 0;

  double get _unitPrice =>
      widget.variant?.price ?? widget.detail.card.price ?? 0;

  int get _count => int.tryParse(_quantity.text.trim()) ?? 0;

  @override
  void initState() {
    super.initState();
    // The account's mobile, once the account has loaded — unless they have typed one meanwhile.
    ref.read(authProvider.future).then((auth) {
      if (mounted && _phone.text.isEmpty && auth is AuthAuthenticated) {
        _phone.text = auth.user.phoneNumber ?? '';
      }
      // No account to read: the field stays empty and asks the customer for a number.
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    _quantity.dispose();
    _address.dispose();
    _pincode.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? _checkQuantity(String? value) {
    final count = int.tryParse(value?.trim() ?? '');
    if (count == null || count < 1) return 'Order at least 1.';
    if (count > _stock) return 'Only $_stock left. Order $_stock or fewer.';
    return null;
  }

  Future<void> _place() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final navigator = Navigator.of(context);
    final messenger = AppMessenger.of(context);
    try {
      final order = await ref
          .read(marketplaceCustomerRepositoryProvider)
          .placeOrder(
            MarketplaceOrderInput(
              postId: widget.detail.card.id,
              variantId: widget.variant?.id,
              quantity: _count,
              paymentMethod: _method,
              phone: Validators.indianMobileDigits(_phone.text),
              deliveryAddress: _address.text.trim(),
              pincode: _pincode.text.trim(),
            ),
          );
      reloadMyMarketplaceOrders(ref);
      ref.invalidate(marketplacePostProvider(widget.detail.card.id));
      messenger.showSuccess(
        'Order #${order.number} placed with ${widget.detail.card.businessName}.',
      );
      // The page under the sheet takes it on: paying online, then the order's own page.
      navigator.pop(order);
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
    final card = widget.detail.card;
    final methods = widget.detail.paymentMethods;
    final chosen = methods.firstWhere((m) => m.code == _method);

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
                'Buy ${widget.variant == null ? card.title : '${card.title} · ${widget.variant!.name}'}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${rupees(_unitPrice)} each · ${card.businessName} · $_stock left',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                ErrorBanner(message: _error!),
                const SizedBox(height: 12),
              ],
              TextFormField(
                key: const ValueKey('marketplace-order-quantity'),
                controller: _quantity,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'How many'),
                validator: _checkQuantity,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('marketplace-order-address'),
                controller: _address,
                minLines: 2,
                maxLines: 4,
                maxLength: _addressLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Deliver to',
                  hintText: 'House, street, area, town',
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Enter the delivery address.'
                    : null,
              ),
              const SizedBox(height: 4),
              TextFormField(
                key: const ValueKey('marketplace-order-pincode'),
                controller: _pincode,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Pincode'),
                validator: Validators.pincode,
              ),
              const SizedBox(height: 4),
              TextFormField(
                key: const ValueKey('marketplace-order-phone'),
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile the courier calls',
                ),
                validator: (v) => Validators.requiredIndianMobile(
                  v,
                  missing: 'Enter a mobile number the courier can call.',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'How do you want to pay?',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                key: const ValueKey('marketplace-order-method'),
                showSelectedIcon: false,
                segments: [
                  for (final m in methods)
                    ButtonSegment(value: m.code, label: Text(m.name)),
                ],
                selected: {_method},
                onSelectionChanged: (s) => setState(() => _method = s.first),
              ),
              if (chosen.detail case final detail?) ...[
                const SizedBox(height: 6),
                Text(detail, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_count < 1 ? 1 : _count} × ${rupees(_unitPrice)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    rupees(_unitPrice * (_count < 1 ? 1 : _count)),
                    key: const ValueKey('marketplace-order-total'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                key: const ValueKey('marketplace-order-place'),
                label: _method == 'Online'
                    ? 'Place order and pay'
                    : 'Place order',
                isLoading: _saving,
                onPressed: _saving ? null : _place,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The server's own limit on a delivery address.
  static const _addressLength = 300;
}

/// Pays online for [order]: the gateway's own window; the server counts the payment only once its
/// signature checks out. Returns the order as it now stands, or null when it was not paid (the
/// reason is shown).
Future<MarketplaceOrder?> payMarketplaceOnline(
  BuildContext context,
  WidgetRef ref,
  MarketplaceOrder order,
) async {
  final messenger = AppMessenger.of(context);
  final repository = ref.read(marketplaceCustomerRepositoryProvider);
  final window = ref.read(marketplacePaymentWindowProvider);
  try {
    final checkout = await repository.startPayment(order.id);
    // Test mode on the server has no window to open; it accepts the payment only while simulating.
    final result = checkout.nothingToCollect
        ? RazorpayResult(
            paymentId: 'sim_${checkout.providerOrderId}',
            orderId: checkout.providerOrderId,
            signature: 'simulated',
          )
        : await window(checkout, order.sellerName ?? 'Zuno Marketplace');
    final paid = await repository.confirmPayment(
      order.id,
      providerOrderId: checkout.providerOrderId,
      paymentId: result.paymentId,
      signature: result.signature,
    );
    reloadMyMarketplaceOrders(ref);
    if (checkout.nothingToCollect) {
      messenger.showInfo(
        'Test mode: marked ${rupees(checkout.amount)} as paid. No money was taken.',
      );
    } else {
      messenger.showSuccess(
        'Paid ${rupees(checkout.amount)} — order confirmed.',
      );
    }
    return paid;
  } on RazorpayCancelled catch (e) {
    reloadMyMarketplaceOrders(ref);
    // A UPI app can take the money and still come back as "closed"; the server asks the gateway
    // every minute and confirms a paid order by itself, so never promise "nothing was charged".
    messenger.showInfo(
      e.reason ??
          'Payment not finished. If money left your account, the order is '
              'confirmed by itself within a few minutes.',
    );
    return null;
  } catch (e) {
    messenger.showFailure(e.toString());
    return null;
  }
}
