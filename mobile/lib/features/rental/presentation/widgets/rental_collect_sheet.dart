import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_form_message_banner.dart';
import 'package:zuno/features/rental/domain/entities/rental_payment.dart';
import 'package:zuno/features/rental/domain/entities/rental_stock.dart';
import 'package:zuno/features/rental/presentation/providers/rental_payment_providers.dart';
import 'package:zuno/features/rental/presentation/providers/rental_providers.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/primary_button.dart';

/// Shows the collect sheet for [order]: take what is due — by the business's UPI QR (the default)
/// or cash — or, with [refund], record money given back on a cancelled order.
Future<void> showRentalCollectSheet(
  BuildContext context,
  RentalOrder order, {
  bool refund = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => RentalCollectSheet(order: order, refund: refund),
);

/// The business takes money for an order. The UPI QR is made for the amount, from the business's own
/// UPI ID: the customer scans it in any UPI app, and the business marks it received. Part payments
/// are fine; more than is due is not.
class RentalCollectSheet extends ConsumerStatefulWidget {
  const RentalCollectSheet({
    required this.order,
    this.refund = false,
    super.key,
  });

  final RentalOrder order;
  final bool refund;

  @override
  ConsumerState<RentalCollectSheet> createState() => _RentalCollectSheetState();
}

class _RentalCollectSheetState extends ConsumerState<RentalCollectSheet> {
  final _formKey = GlobalKey<FormState>();
  late final double _max = widget.refund
      ? widget.order.paid
      : widget.order.balance;
  late final _amount = TextEditingController(text: rentalPlainAmount(_max));

  /// The method chosen; the first the server offers (UPI QR) until one is picked.
  String? _method;
  bool _isSaving = false;
  String? _error;

  double get _value => double.tryParse(_amount.text.trim()) ?? 0;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save(String method) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final messenger = AppMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final updated = await ref
          .read(rentalRepositoryProvider)
          .recordPayment(
            widget.order.id,
            RentalPaymentInput(
              method: method,
              amount: _value,
              isRefund: widget.refund,
            ),
          );
      reloadRentals(ref);
      messenger.showSuccess(
        widget.refund
            ? '${rupees(_value)} given back to ${updated.customerName}.'
            : updated.balance <= 0
            ? '${rupees(_value)} received — ${updated.customerName} has paid in full.'
            : '${rupees(_value)} received. ${rupees(updated.balance)} still due.',
      );
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
    final order = widget.order;
    final methods =
        ref.watch(rentalPaymentOptionsProvider).value?.methods ??
        const <RentalPaymentOption>[];
    final method =
        _method ??
        (methods.isEmpty ? RentalPaymentMethod.upiQr : methods.first.code);
    // The setting, once loaded, wins over the copy on the order: it may have just been added.
    final upiId = ref.watch(rentalUpiIdProvider).value ?? order.upiId;
    final showQr = !widget.refund && method == RentalPaymentMethod.upiQr;

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.refund ? 'Give money back' : 'Collect payment',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${order.customerName} · ${order.quantity} × ${order.itemName} · '
                '${widget.refund ? 'paid' : 'due'} ${rupees(_max)}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                ServiceFormMessageBanner(
                  message: _error!,
                  color: AppColors.error,
                  onColor: theme.colorScheme.onError,
                  icon: Icons.error_outline,
                ),
                const SizedBox(height: 14),
              ],
              if (methods.isNotEmpty)
                SegmentedButton<String>(
                  key: const ValueKey('payment-method'),
                  showSelectedIcon: false,
                  segments: [
                    for (final m in methods)
                      ButtonSegment(
                        value: m.code,
                        label: Text(m.name),
                        icon: Icon(
                          m.code == RentalPaymentMethod.upiQr
                              ? Icons.qr_code_2_rounded
                              : Icons.payments_outlined,
                        ),
                      ),
                  ],
                  selected: {method},
                  onSelectionChanged: (s) => setState(() => _method = s.first),
                ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('payment-amount-field'),
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                  helperText: widget.refund
                      ? 'At most what was paid'
                      : 'Part payments are fine',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final value = double.tryParse((v ?? '').trim());
                  if (value == null || value <= 0) return 'Enter the amount.';
                  if (value > _max + 0.001) {
                    return 'At most ${rupees(_max)}.';
                  }
                  return null;
                },
              ),
              if (showQr) ...[
                const SizedBox(height: 16),
                if (upiId == null || upiId.isEmpty)
                  RentalUpiMissing(onAdd: () => showRentalUpiSheet(context))
                else if (_value > 0 && _value <= _max + 0.001)
                  RentalUpiQr(
                    upiId: upiId,
                    payee: order.businessName ?? 'Zuno Rent',
                    amount: _value,
                    note: 'Rent ${order.quantity} ${order.itemName}',
                  ),
              ],
              const SizedBox(height: 18),
              PrimaryButton(
                label: widget.refund
                    ? 'Record ${rupees(_value)} given back'
                    : 'Mark ${rupees(_value)} received',
                onPressed: _value > 0 ? () => _save(method) : null,
                isLoading: _isSaving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A UPI QR for one amount, made from the business's own UPI ID — any UPI app pays it.
class RentalUpiQr extends StatelessWidget {
  const RentalUpiQr({
    required this.upiId,
    required this.payee,
    required this.amount,
    required this.note,
    super.key,
  });

  final String upiId;
  final String payee;
  final double amount;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('rental-upi-qr'),
      children: [
        // Dark modules on a light backdrop in light and dark mode alike, so any scanner reads it.
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.qrBackdrop,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: QrImageView(
              data: rentalUpiUri(
                upiId: upiId,
                payee: payee,
                amount: amount,
                note: note,
              ),
              size: 200,
              gapless: false,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Scan to pay ${rupees(amount)}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          upiId,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Said where the QR would be, until the business adds its UPI ID.
class RentalUpiMissing extends StatelessWidget {
  const RentalUpiMissing({required this.onAdd, super.key});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add your UPI ID to show a QR customers can scan.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('add-upi-id'),
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add UPI ID'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the sheet where the business sets the UPI ID its order QR is made from.
Future<void> showRentalUpiSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const RentalUpiSheet(),
    );

/// The business's UPI ID, e.g. joyrentals@okhdfcbank. Empty removes it.
class RentalUpiSheet extends ConsumerStatefulWidget {
  const RentalUpiSheet({super.key});

  /// The shape the server accepts: name@bank.
  static final upiPattern = RegExp(
    r'^[a-zA-Z0-9._-]{2,256}@[a-zA-Z][a-zA-Z0-9]{1,63}$',
  );

  @override
  ConsumerState<RentalUpiSheet> createState() => _RentalUpiSheetState();
}

class _RentalUpiSheetState extends ConsumerState<RentalUpiSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _upi = TextEditingController(
    text: ref.read(rentalUpiIdProvider).value ?? '',
  );
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _upi.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final messenger = AppMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final text = _upi.text.trim();
      final saved = await ref
          .read(rentalRepositoryProvider)
          .setUpiId(text.isEmpty ? null : text);
      ref.invalidate(rentalUpiIdProvider);
      reloadRentals(ref);
      messenger.showSuccess(
        saved == null
            ? 'UPI ID removed.'
            : 'UPI ID saved. Order QRs pay $saved.',
      );
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
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'UPI ID for payments',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'The QR on each order is made from it, for the amount due.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              ServiceFormMessageBanner(
                message: _error!,
                color: AppColors.error,
                onColor: theme.colorScheme.onError,
                icon: Icons.error_outline,
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              key: const ValueKey('upi-id-field'),
              controller: _upi,
              maxLength: 100,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'UPI ID',
                hintText: 'e.g. joyrentals@okhdfcbank',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              validator: (v) {
                final value = (v ?? '').trim();
                return value.isEmpty ||
                        RentalUpiSheet.upiPattern.hasMatch(value)
                    ? null
                    : 'Enter a UPI ID like name@bank.';
              },
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'Save',
              onPressed: _save,
              isLoading: _isSaving,
            ),
          ],
        ),
      ),
    );
  }
}
