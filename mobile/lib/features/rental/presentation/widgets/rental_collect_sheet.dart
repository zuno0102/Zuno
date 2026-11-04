import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:zuno/core/payments/upi_pay.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_form_message_banner.dart';
import 'package:zuno/features/rental/domain/entities/rental_payment.dart';
import 'package:zuno/features/rental/domain/entities/rental_stock.dart';
import 'package:zuno/features/rental/presentation/providers/rental_payment_providers.dart';
import 'package:zuno/features/rental/presentation/providers/rental_providers.dart';
import 'package:zuno/features/rental/presentation/screens/rental_upi_scan_screen.dart';
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
  // A refund is what is still owed: paid, less the cancellation charge the business keeps.
  late final double _max = widget.refund
      ? widget.order.refundOwed
      : widget.order.balance;
  late final _amount = TextEditingController(text: rentalPlainAmount(_max));

  // A refund by UPI: the customer's UPI ID (scanned or typed) and, once paid, the reference.
  final _customerUpi = TextEditingController();
  final _reference = TextEditingController();

  /// Set when the UPI app came back without a clear answer: the business confirms it went.
  bool _confirmUpi = false;

  /// The method chosen; the first the server offers (UPI QR) until one is picked.
  String? _method;
  bool _isSaving = false;
  String? _error;

  double get _value => double.tryParse(_amount.text.trim()) ?? 0;

  @override
  void dispose() {
    _amount.dispose();
    _customerUpi.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _save(
    String method, {
    String? reference,
    String? payeeUpiId,
  }) async {
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
              reference: reference,
              payeeUpiId: payeeUpiId,
            ),
          );
      reloadRentals(ref);
      messenger.showSuccess(
        widget.refund
            ? reference != null
                  ? '${rupees(_value)} refunded to ${updated.customerName} by UPI · ref $reference.'
                  : '${rupees(_value)} given back to ${updated.customerName}.'
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

  /// Scans the customer's UPI QR (the one their GPay or PhonePe shows) for their UPI ID.
  Future<void> _scanCustomerUpi() async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const RentalUpiScanScreen()),
    );
    if (raw == null || !mounted) return;
    final upiId = rentalUpiIdFrom(raw);
    setState(() {
      if (upiId == null) {
        _error =
            'That is not a UPI QR. Scan the QR in the customer\'s UPI app.';
      } else {
        _customerUpi.text = upiId;
        _error = null;
      }
    });
  }

  /// Opens the business's UPI app on a payment to the customer, already filled in. The UPI app
  /// saying SUCCESS records the refund with its reference; FAILURE records nothing; anything
  /// unclear asks the business to check and confirm.
  Future<void> _payByUpi() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final order = widget.order;
    final upiId = _customerUpi.text.trim();
    setState(() {
      _error = null;
      _confirmUpi = false;
    });
    final result = await ref.read(rentalUpiPayProvider)(
      rentalUpiUri(
        upiId: upiId,
        payee: order.customerName,
        amount: _value,
        note: 'Refund ${order.quantity} ${order.itemName}',
      ),
    );
    if (!mounted) return;

    switch (result.status) {
      case UpiPayStatus.success:
        await _save(
          RentalPaymentMethod.upiQr,
          reference: result.reference,
          payeeUpiId: upiId,
        );
      case UpiPayStatus.failure:
        setState(
          () => _error =
              'The UPI app says ${rupees(_value)} did not go. Nothing was recorded.',
        );
      case UpiPayStatus.unknown:
        setState(() {
          _confirmUpi = true;
          _reference.text = result.reference ?? '';
        });
      case UpiPayStatus.unavailable:
        setState(() {
          _confirmUpi = true;
          _error =
              'No UPI app opened. Pay ${rupees(_value)} to $upiId from any UPI app, '
              'then confirm below.';
        });
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
    // Giving it back by UPI: paid to the customer's UPI ID from the business's own UPI app.
    final refundByUpi = widget.refund && method == RentalPaymentMethod.upiQr;

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
                '${widget.refund ? 'owed back' : 'due'} ${rupees(_max)}',
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
              if (refundByUpi) ...[
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('refund-upi-id'),
                  controller: _customerUpi,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: "Customer's UPI ID",
                    hintText: 'e.g. rahul@okaxis',
                    helperText:
                        "Scan the QR in the customer's UPI app, or type it",
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      key: const ValueKey('refund-upi-scan'),
                      tooltip: "Scan customer's UPI QR",
                      onPressed: _scanCustomerUpi,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                    ),
                  ),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) {
                      return "Scan or type the customer's UPI ID.";
                    }
                    return rentalUpiIdPattern.hasMatch(value)
                        ? null
                        : 'Enter a UPI ID like name@bank.';
                  },
                ),
              ],
              if (refundByUpi && _confirmUpi) ...[
                const SizedBox(height: 16),
                Card(
                  key: const ValueKey('refund-upi-confirm'),
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Did ${rupees(_value)} reach ${order.customerName}? '
                          'Check your UPI app before you confirm.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          key: const ValueKey('refund-upi-reference'),
                          controller: _reference,
                          decoration: const InputDecoration(
                            labelText: 'UPI reference (optional)',
                            hintText: 'From your UPI app, e.g. 431256789012',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final value = (v ?? '').trim();
                            return value.isEmpty ||
                                    RegExp(
                                      r'^[A-Za-z0-9-]{4,50}$',
                                    ).hasMatch(value)
                                ? null
                                : 'Letters and digits, as the UPI app shows it.';
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              if (refundByUpi && !_confirmUpi)
                PrimaryButton(
                  label: 'Pay ${rupees(_value)} by UPI',
                  onPressed: _value > 0 ? _payByUpi : null,
                  isLoading: _isSaving,
                )
              else
                PrimaryButton(
                  label: refundByUpi
                      ? 'Yes, record ${rupees(_value)} given back'
                      : widget.refund
                      ? 'Record ${rupees(_value)} given back'
                      : 'Mark ${rupees(_value)} received',
                  onPressed: _value > 0
                      ? () => _save(
                          method,
                          reference:
                              refundByUpi && _reference.text.trim().isNotEmpty
                              ? _reference.text.trim()
                              : null,
                          payeeUpiId: refundByUpi
                              ? _customerUpi.text.trim()
                              : null,
                        )
                      : null,
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
  static final upiPattern = rentalUpiIdPattern;

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
