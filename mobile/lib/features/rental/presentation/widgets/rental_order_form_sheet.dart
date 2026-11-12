import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/core/utils/validators.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_profile_notifier.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_form_message_banner.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_form_pickers.dart';
import 'package:zuno/features/rental/domain/entities/rental_item.dart';
import 'package:zuno/features/rental/domain/entities/rental_payment.dart';
import 'package:zuno/features/rental/domain/entities/rental_stock.dart';
import 'package:zuno/features/rental/presentation/providers/rental_payment_providers.dart';
import 'package:zuno/features/rental/presentation/providers/rental_providers.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_advance_basis.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_availability_line.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_collect_sheet.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/primary_button.dart';
import 'package:zuno/shared/widgets/stock_count_stepper.dart';

/// Shows the Offline order sheet: booking pieces for a customer who phoned or came in.
Future<void> showRentalOrderFormSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const RentalOrderFormSheet(),
    );

/// The first moment of [day] in the business's own time.
DateTime rentalDayStart(DateTime day) => DateTime(day.year, day.month, day.day);

/// The last minute of [day] — a rental "to 3 Nov" runs through that day.
DateTime rentalDayEnd(DateTime day) =>
    DateTime(day.year, day.month, day.day, 23, 59);

/// A new rent order: which item, which dates, how many — with what those dates leave shown as it is
/// filled in — then who it is for and where it goes.
class RentalOrderFormSheet extends ConsumerStatefulWidget {
  const RentalOrderFormSheet({super.key});

  @override
  ConsumerState<RentalOrderFormSheet> createState() =>
      _RentalOrderFormSheetState();
}

class _RentalOrderFormSheetState extends ConsumerState<RentalOrderFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController(text: '1');
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();

  /// The advance taken now — the item's own until the business types another.
  final _advance = TextEditingController();
  bool _advanceTyped = false;

  String? _itemId;

  /// How the advance was paid; the UPI QR first, as on every collect.
  String _advanceMethod = RentalPaymentMethod.upiQr;
  late DateTimeRange _dates = () {
    final today = rentalDayStart(DateTime.now());
    return DateTimeRange(start: today, end: today.add(const Duration(days: 1)));
  }();
  bool _isSaving = false;
  String? _error;

  /// Set by the first Book: from then on each field's message goes as soon as it is put right.
  bool _submitted = false;

  int get _count => int.tryParse(_quantity.text.trim()) ?? 0;
  DateTime get _start => rentalDayStart(_dates.start);
  DateTime get _end => rentalDayEnd(_dates.end);
  double get _typedAdvance => double.tryParse(_advance.text.trim()) ?? 0;

  /// What the order costs and the least advance its item asks, for the pieces and dates chosen.
  ({double total, double required}) _money(RentalItem item) {
    final total = rentalAmount(
      item.priceType,
      item.price,
      _count,
      _start,
      _end,
    );
    return (
      total: total,
      required: rentalAdvance(
        item.advanceType,
        item.advanceAmount,
        _count,
        total,
      ),
    );
  }

  /// Fills in the item's own advance as the item, pieces or dates change — until one is typed.
  void _syncAdvance() {
    final item =
        (ref.read(businessRentalsProvider).value ?? const <RentalItem>[])
            .firstWhereOrNull((i) => i.id == _itemId);
    if (_advanceTyped || item == null) return;
    final required = _money(item).required;
    _advance.text = required > 0 ? rentalPlainAmount(required) : '';
  }

  @override
  void dispose() {
    _advance.dispose();
    _quantity.dispose();
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  void _step(int delta) {
    final next = (_count + delta).clamp(1, 100000);
    setState(() {
      _quantity.text = '$next';
      _error = null;
      _syncAdvance();
    });
  }

  Future<void> _pickDates() async {
    final today = rentalDayStart(DateTime.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      initialDateRange: _dates,
      helpText: 'Rental dates',
    );
    if (picked != null) {
      setState(() {
        _dates = picked;
        _error = null;
        _syncAdvance();
      });
    }
  }

  Future<void> _pickItem(List<({String id, String name})> items) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Item')),
            for (final item in items)
              ListTile(
                title: Text(item.name),
                trailing: item.id == _itemId ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(item.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _itemId = picked;
        // "Choose the item." — or a server message about the old choice — no longer applies.
        _error = null;
        _syncAdvance();
      });
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    final fieldsValid = _formKey.currentState!.validate();
    if (_itemId == null) {
      setState(() => _error = 'Choose the item.');
      return;
    }
    if (!fieldsValid) return;

    final messenger = AppMessenger.of(context);
    final advance = _typedAdvance;

    // Never booked as paid on a guess: the business says whether the money is really in hand.
    var received = false;
    if (advance > 0) {
      final methods =
          ref.read(rentalPaymentOptionsProvider).value?.methods ??
          const <RentalPaymentOption>[];
      final methodName =
          methods.firstWhereOrNull((m) => m.code == _advanceMethod)?.name ??
          _advanceMethod;
      final answer = await showRentalAdvanceReceivedDialog(
        context,
        amount: advance,
        byUpi: _advanceMethod == RentalPaymentMethod.upiQr,
        methodName: methodName,
      );
      if (answer == null || !mounted) return;
      received = answer;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final order = await ref
          .read(rentalRepositoryProvider)
          .createOrder(
            RentalOrderInput(
              rentalItemId: _itemId!,
              quantity: _count,
              startDate: _start,
              endDate: _end,
              customerName: _name.text.trim(),
              customerPhone: Validators.indianMobileDigits(_phone.text),
              deliveryAddress: _address.text.trim(),
              advanceMethod: advance > 0 ? _advanceMethod : null,
              advanceAmount: advance,
              advanceReceived: received,
            ),
          );
      reloadRentals(ref);
      // An offline order is confirmed whether or not the advance is in hand yet.
      final advanceNote = order.advanceDue <= 0
          ? ''
          : received
          ? ' Advance ${rupees(order.advanceDue)} received.'
          : ' Advance ${rupees(order.advanceDue)} to collect from the order.';
      messenger.showSuccess(
        'Order confirmed: ${order.quantity} × ${order.itemName} for ${order.customerName}.'
        '$advanceNote',
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // The server's own words — "Only 300 Plastic chair available for 1 Nov – 3 Nov".
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Only items switched on can be booked.
    final items = <({String id, String name})>[
      for (final i
          in ref.watch(businessRentalsProvider).value ?? const <RentalItem>[])
        if (i.isAvailable) (id: i.id, name: i.name),
    ];
    final chosen = items.firstWhereOrNull((i) => i.id == _itemId);
    final chosenItem =
        (ref.watch(businessRentalsProvider).value ?? const <RentalItem>[])
            .firstWhereOrNull((i) => i.id == _itemId);
    final overLimit =
        _itemId != null &&
        RentalAvailabilityLine.isOverLimit(
          ref,
          itemId: _itemId!,
          start: _start,
          end: _end,
          quantity: _count,
        );

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
                'Offline order',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'For a customer who phoned, came to the shop or sent a message. '
                'It holds stock the same as an app order.',
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
              ServicePickerField(
                ellipsize: true,
                label: 'Item',
                value: chosen?.name,
                placeholder: items.isEmpty
                    ? 'No items available to book'
                    : 'Choose the item',
                onTap: () {
                  if (items.isNotEmpty) _pickItem(items);
                },
              ),
              const SizedBox(height: 14),
              ServicePickerField(
                ellipsize: true,
                label: 'Dates',
                value:
                    '${formatDayMonth(_dates.start)} – ${formatDayMonth(_dates.end)}',
                placeholder: 'Choose the dates',
                onTap: _pickDates,
              ),
              const SizedBox(height: 14),
              RentalQuantityRow(
                controller: _quantity,
                onStep: _step,
                onChanged: () => setState(_syncAdvance),
              ),
              const SizedBox(height: 8),
              if (_itemId != null)
                RentalAvailabilityLine(
                  itemId: _itemId!,
                  start: _start,
                  end: _end,
                  quantity: _count,
                ),
              if (chosenItem != null && _count > 0) ...[
                const SizedBox(height: 12),
                _OfflineMoney(
                  item: chosenItem,
                  quantity: _count,
                  money: _money(chosenItem),
                  advance: _advance,
                  onAdvance: () => setState(() => _advanceTyped = true),
                  method: _advanceMethod,
                  onMethod: (m) => setState(() => _advanceMethod = m),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                maxLength: 200,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Customer name',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? "Give the customer's name."
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                  LengthLimitingTextInputFormatter(16),
                ],
                decoration: const InputDecoration(
                  labelText: 'Customer mobile',
                  hintText: '98765 43210',
                  border: OutlineInputBorder(),
                ),
                // Required: the business calls this number about delivery and return.
                validator: (v) => Validators.requiredIndianMobile(
                  v,
                  missing: "Give the customer's mobile number.",
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _address,
                maxLength: 500,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Where it goes',
                  hintText: "e.g. St. Mary's Hall, Kakkanad",
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? 'Say where the pieces go.'
                    : null,
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Book',
                onPressed: overLimit || _count < 1 ? null : _save,
                isLoading: _isSaving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// − [count] + with the number typed in the middle, as the stock page has it. Shared by the
/// offline order, the extra-pieces sheet and the customer's booking.
class RentalQuantityRow extends StatelessWidget {
  const RentalQuantityRow({
    required this.controller,
    required this.onStep,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<int> onStep;
  final VoidCallback onChanged;

  /// The − and + buttons' look: the Stock pages' own.
  static ButtonStyle stepStyle(BuildContext context) =>
      StockCountStepper.stepStyle(context);

  @override
  Widget build(BuildContext context) {
    final count = int.tryParse(controller.text.trim()) ?? 0;
    final style = stepStyle(context);
    return Row(
      children: [
        IconButton.filledTonal(
          key: const ValueKey('order-quantity-less'),
          tooltip: 'One less',
          style: style,
          onPressed: count > 1 ? () => onStep(-1) : null,
          icon: const Icon(Icons.remove),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            key: const ValueKey('order-quantity'),
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'How many',
              border: OutlineInputBorder(),
            ),
            validator: (v) => (int.tryParse((v ?? '').trim()) ?? 0) < 1
                ? 'At least 1.'
                : null,
            onChanged: (_) => onChanged(),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          key: const ValueKey('order-quantity-more'),
          tooltip: 'One more',
          style: style,
          onPressed: () => onStep(1),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

/// Shows the sheet that adds pieces to a running [order] — the customer who needs 200 more.
Future<void> showAddPiecesSheet(BuildContext context, RentalOrder order) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddPiecesSheet(order: order),
    );

/// More pieces for a running order: how many, and until when — by default with the first pieces.
/// Saved as a new order linked to the first, so its delivery and return are tracked on their own.
class AddPiecesSheet extends ConsumerStatefulWidget {
  const AddPiecesSheet({required this.order, super.key});

  final RentalOrder order;

  @override
  ConsumerState<AddPiecesSheet> createState() => _AddPiecesSheetState();
}

class _AddPiecesSheetState extends ConsumerState<AddPiecesSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController(text: '1');
  late DateTime _until = widget.order.endDate;
  bool _isSaving = false;
  String? _error;

  /// The extra pieces are needed from now, or from the order's start if that is still ahead.
  /// Taken to the minute, so the availability asked for does not shift on every rebuild.
  late final DateTime _from = () {
    final now = DateTime.now();
    final start = widget.order.startDate.isAfter(now)
        ? widget.order.startDate
        : now;
    return DateTime(
      start.year,
      start.month,
      start.day,
      start.hour,
      start.minute,
    );
  }();

  int get _count => int.tryParse(_quantity.text.trim()) ?? 0;

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _pickUntil() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: rentalDayStart(_from),
      lastDate: rentalDayStart(_from).add(const Duration(days: 365)),
      initialDate: _until.isBefore(_from) ? _from : _until,
      helpText: 'Extra pieces needed until',
    );
    if (picked != null) setState(() => _until = rentalDayEnd(picked));
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final messenger = AppMessenger.of(context);
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final addOn = await ref
          .read(rentalRepositoryProvider)
          .addPieces(
            widget.order.id,
            _count,
            endDate: _until == widget.order.endDate ? null : _until,
          );
      reloadRentals(ref);
      messenger.showSuccess(
        'Added ${addOn.quantity} more ${addOn.itemName} for ${addOn.customerName}.',
      );
      if (mounted) Navigator.of(context).pop();
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
    final overLimit = RentalAvailabilityLine.isOverLimit(
      ref,
      itemId: order.rentalItemId,
      start: _from,
      end: _until,
      quantity: _count,
    );

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
                'Add more pieces',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${order.customerName} has ${order.quantityWithAddOns} × '
                '${order.itemName}. The extra pieces go as a new delivery, '
                'linked to this order.',
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
              RentalQuantityRow(
                controller: _quantity,
                onStep: (delta) => setState(
                  () => _quantity.text = '${(_count + delta).clamp(1, 100000)}',
                ),
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 8),
              RentalAvailabilityLine(
                itemId: order.rentalItemId,
                start: _from,
                end: _until,
                quantity: _count,
              ),
              const SizedBox(height: 14),
              ServicePickerField(
                ellipsize: true,
                label: 'Needed until',
                value: _until == order.endDate
                    ? '${formatDayMonth(_until)} (with the first pieces)'
                    : formatDayMonth(_until),
                placeholder: 'Choose a date',
                onTap: _pickUntil,
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Add pieces',
                onPressed: overLimit || _count < 1 ? null : _save,
                isLoading: _isSaving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the offline order costs, worked out as it is filled in, and the advance taken now: the
/// item's own to start with, or any amount the business types — never below what the item asks, nor
/// above the total. Received as cash or on the business's UPI QR, made for that amount so the
/// customer's UPI app fills it in.
class _OfflineMoney extends ConsumerWidget {
  const _OfflineMoney({
    required this.item,
    required this.quantity,
    required this.money,
    required this.advance,
    required this.onAdvance,
    required this.method,
    required this.onMethod,
  });

  final RentalItem item;
  final int quantity;

  /// The order's total, and the least advance the item asks (0 when it asks none).
  final ({double total, double required}) money;
  final TextEditingController advance;
  final VoidCallback onAdvance;
  final String method;
  final ValueChanged<String> onMethod;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (:total, :required) = money;
    final now = double.tryParse(advance.text.trim()) ?? 0;
    // An amount the order cannot take shows no summary and no QR, so nobody scans to pay it.
    final allowed = now >= required && now <= total;
    final takes = now > 0 && allowed;
    final methods =
        ref.watch(rentalPaymentOptionsProvider).value?.methods ??
        const <RentalPaymentOption>[];
    final upiId = ref.watch(rentalUpiIdProvider).value;

    return Card(
      key: const ValueKey('offline-money'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Total ${rupees(total)}',
              key: const ValueKey('offline-total'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (allowed)
              Text(
                takes
                    ? 'Advance ${rupees(now)} now · ${rupees(total - now)} before the return'
                    : 'No advance: everything is paid before the return.',
                key: const ValueKey('offline-advance'),
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 12),
            Text('Advance payment', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            TextFormField(
              key: const ValueKey('offline-advance-amount'),
              controller: advance,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: 'Advance amount',
                hintText: 'Enter amount',
                prefixText: '₹ ',
                // Says how the item's advance is worked out, so a fixed ₹300 is not read as ₹300 a piece.
                helperText: required > 0
                    ? '${item.name} asks at least ${rupees(required)}: '
                          '${rentalAdvanceBasis(item.advanceType, item.advanceAmount, quantity)}'
                    : 'Leave empty for no advance',
                helperMaxLines: 2,
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                final typed = double.tryParse((v ?? '').trim()) ?? 0;
                if (typed < required) {
                  return 'At least ${rupees(required)}: the item asks it.';
                }
                if (typed > total) {
                  return 'Not more than the total, ${rupees(total)}.';
                }
                return null;
              },
              onChanged: (_) => onAdvance(),
            ),
            if (takes) ...[
              const SizedBox(height: 12),
              Text('Advance received by', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              if (methods.isNotEmpty)
                SegmentedButton<String>(
                  key: const ValueKey('offline-advance-method'),
                  showSelectedIcon: false,
                  segments: [
                    for (final m in methods)
                      ButtonSegment(value: m.code, label: Text(m.name)),
                  ],
                  selected: {method},
                  onSelectionChanged: (s) => onMethod(s.first),
                ),
              if (method == RentalPaymentMethod.upiQr) ...[
                const SizedBox(height: 12),
                if (upiId == null || upiId.isEmpty)
                  RentalUpiMissing(onAdd: () => showRentalUpiSheet(context))
                else
                  RentalUpiQr(
                    upiId: upiId,
                    // The name the customer's UPI app shows: the business's own.
                    payee:
                        ref
                            .watch(businessProfileProvider)
                            .value
                            ?.businessName ??
                        'Rent payment',
                    amount: now,
                    note: 'Advance for $quantity ${item.name}',
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// "Have you received ₹300 by UPI QR?" — asked before a walk-in order with an advance is booked.
///
/// True: the money is in hand, so it is recorded. False ("Not yet"): nothing is recorded, and the
/// advance is collected from the order later. Either way the order is confirmed. Null: the business
/// backed out, and nothing is booked.
Future<bool?> showRentalAdvanceReceivedDialog(
  BuildContext context, {
  required double amount,
  required bool byUpi,
  required String methodName,
}) => showDialog<bool>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    key: const ValueKey('advance-received-dialog'),
    title: Text('Received ${rupees(amount)}?'),
    content: Text(
      byUpi
          ? 'Check your UPI app shows ${rupees(amount)} from the customer before you say yes. '
                'Not yet? The order is still confirmed; collect the advance from the order later.'
          : 'Say yes only once the ${rupees(amount)} in $methodName is in your hand. '
                'Not yet? The order is still confirmed; collect the advance from the order later.',
    ),
    actions: [
      TextButton(
        key: const ValueKey('advance-not-yet'),
        onPressed: () => Navigator.pop(dialogContext, false),
        child: const Text('Not yet'),
      ),
      FilledButton(
        key: const ValueKey('advance-received'),
        onPressed: () => Navigator.pop(dialogContext, true),
        child: Text('Yes, received by $methodName'),
      ),
    ],
  ),
);
