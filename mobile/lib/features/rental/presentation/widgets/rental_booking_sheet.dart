import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/router/push_screen.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/core/utils/validators.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/auth/presentation/providers/auth_state.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_form_message_banner.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_form_pickers.dart';
import 'package:zuno/features/customer/presentation/providers/customer_search_filter_provider.dart';
import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/features/rental/domain/entities/rental_payment.dart';
import 'package:zuno/features/rental/presentation/providers/rental_order_providers.dart';
import 'package:zuno/features/rental/presentation/providers/rental_providers.dart';
import 'package:zuno/features/rental/presentation/screens/rental_order_detail_screen.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_advance_basis.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_availability_line.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_order_form_sheet.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_payment_card.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_phone_verify_field.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/primary_button.dart';

/// Shows the booking sheet for [item].
Future<void> showRentalBookingSheet(
  BuildContext context,
  RentalItemDetail item,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => RentalBookingSheet(item: item),
);

/// A customer books an item: dates, how many — with what those dates leave shown as they choose —
/// where it goes, their mobile (checked with a code once), and the business's questions. The server
/// checks it all again on save.
class RentalBookingSheet extends ConsumerStatefulWidget {
  const RentalBookingSheet({required this.item, super.key});

  final RentalItemDetail item;

  @override
  ConsumerState<RentalBookingSheet> createState() => _RentalBookingSheetState();
}

class _RentalBookingSheetState extends ConsumerState<RentalBookingSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController(text: '1');
  final _address = TextEditingController();

  /// Starts as the number they verified before, or else the one on their account.
  late final _phone = TextEditingController(text: _accountPhone ?? '');

  /// The mobile verified with a code, as its 10 digits; null until one is.
  String? _verifiedPhone;
  late final Map<String, TextEditingController> _answers = {
    for (final q in widget.item.questions) q.id: TextEditingController(),
  };

  late DateTimeRange _dates = () {
    final tomorrow = rentalDayStart(
      DateTime.now(),
    ).add(const Duration(days: 1));
    return DateTimeRange(start: tomorrow, end: tomorrow);
  }();

  /// One of the item's districts — the customer's own, when the item goes there.
  late String? _districtId = () {
    final mine = ref.read(customerSearchFilterProvider).districtIds;
    return widget.item.districts
            .firstWhereOrNull((d) => mine.contains(d.id))
            ?.id ??
        (widget.item.districts.length == 1
            ? widget.item.districts.first.id
            : null);
  }();

  bool _isSaving = false;
  String? _error;

  String? get _accountPhone {
    final auth = ref.read(authProvider).value;
    return Validators.indianMobileDigits(
      auth is AuthAuthenticated ? auth.user.phoneNumber : null,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadVerifiedPhone();
  }

  /// A customer who verified a number before books with it again without a new code.
  Future<void> _loadVerifiedPhone() async {
    try {
      final phone = await ref
          .read(rentalCustomerRepositoryProvider)
          .verifiedPhone();
      if (!mounted || phone == null) return;
      setState(() {
        _verifiedPhone = phone;
        // Only over what was filled in for them: never over a number they are typing.
        final typed = _phone.text.trim();
        if (typed.isEmpty || typed == _accountPhone) _phone.text = phone;
      });
    } catch (_) {
      // Not knowing only means the code is asked for again; the booking still works.
    }
  }

  /// Set on the first Book tap: from then on each field checks itself as it is typed in, so a
  /// message goes the moment the field is put right instead of waiting for the next tap.
  bool _submitted = false;

  /// Any change to the booking makes the banner above stale — "Choose the district" once one is
  /// chosen, "Only 3 available" once the number or dates change — so it goes.
  void _edited() {
    if (_error != null) setState(() => _error = null);
  }

  int get _count => int.tryParse(_quantity.text.trim()) ?? 0;
  DateTime get _start => rentalDayStart(_dates.start);
  DateTime get _end => rentalDayEnd(_dates.end);

  /// What the booking costs, by the server's rule — rate × pieces × days or hours.
  double get _amount => rentalAmount(
    widget.item.card.priceType,
    widget.item.card.price,
    _count,
    _start,
    _end,
  );

  /// The advance paid now, online; 0 when the item asks none.
  double get _advance => rentalAdvance(
    widget.item.advanceType,
    widget.item.advanceAmount,
    _count,
    _amount,
  );

  @override
  void dispose() {
    _quantity.dispose();
    _address.dispose();
    _phone.dispose();
    for (final c in _answers.values) {
      c.dispose();
    }
    super.dispose();
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
      });
    }
  }

  Future<void> _pickDistrict() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Where it goes')),
            for (final d in widget.item.districts)
              ListTile(
                title: Text(d.name),
                subtitle: Text(d.stateName),
                trailing: d.id == _districtId ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(d.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _districtId = picked;
        _error = null;
      });
    }
  }

  Future<void> _book() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    final valid = _formKey.currentState!.validate();
    if (_districtId == null) {
      setState(() => _error = 'Choose the district it goes to.');
      return;
    }
    if (!valid) return;

    final messenger = AppMessenger.of(context);
    final navigator = Navigator.of(context);
    final reload = rentalReloader(ref);
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final order = await ref
          .read(rentalCustomerRepositoryProvider)
          .book(
            RentalBookingInput(
              rentalItemId: widget.item.card.id,
              quantity: _count,
              startDate: _start,
              endDate: _end,
              deliveryAddress: _address.text.trim(),
              districtId: _districtId!,
              customerPhone: Validators.indianMobileDigits(_phone.text)!,
              answers: {
                for (final entry in _answers.entries)
                  entry.key: entry.value.text,
              },
            ),
          );
      reload();

      // The item asks an advance: pay it now, while the pieces are held. Closing the window keeps
      // the booking waiting; it can be paid from My rents until the hold runs out.
      if (order.isAwaitingAdvance) {
        if (!mounted) return;
        await payRentalOnline(context, ref, order);
        // The sheet can close while the payment window is open. Popping then would close the page
        // under it instead — the item page — so stop here: the payment message has been shown,
        // and the booking is in My rents.
        if (!mounted) return;
      } else {
        messenger.showSuccess(
          'Booked: ${order.quantity} × ${order.itemName}. '
          '${order.businessName ?? 'The business'} will confirm the delivery.',
        );
      }
      navigator.pop();
      if (mounted) {
        pushScreen(
          navigator.context,
          RentalOrderDetailScreen(
            order: order,
            audience: RentalAudience.customer,
          ),
        );
      }
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
    final item = widget.item;
    final district = item.districts.firstWhereOrNull(
      (d) => d.id == _districtId,
    );
    final overLimit = RentalAvailabilityLine.isOverLimit(
      ref,
      itemId: item.card.id,
      start: _start,
      end: _end,
      quantity: _count,
      audience: RentalAudience.customer,
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
                'Book ${item.card.name}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${rupees(item.card.price)}${item.card.unitSuffix} · '
                '${item.card.businessName}',
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
                label: 'Dates',
                value:
                    formatDayMonth(_dates.start) == formatDayMonth(_dates.end)
                    ? formatDayMonth(_dates.start)
                    : '${formatDayMonth(_dates.start)} – ${formatDayMonth(_dates.end)}',
                placeholder: 'Choose the dates',
                onTap: _pickDates,
              ),
              const SizedBox(height: 14),
              RentalQuantityRow(
                controller: _quantity,
                onStep: (delta) => setState(() {
                  _quantity.text = '${(_count + delta).clamp(1, 100000)}';
                  _error = null;
                }),
                onChanged: () => setState(() => _error = null),
              ),
              const SizedBox(height: 8),
              RentalAvailabilityLine(
                itemId: item.card.id,
                start: _start,
                end: _end,
                quantity: _count,
                audience: RentalAudience.customer,
              ),
              const SizedBox(height: 16),
              ServicePickerField(
                ellipsize: true,
                label: 'District',
                value: district?.name,
                placeholder: 'Choose where it goes',
                onTap: _pickDistrict,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('booking-address'),
                controller: _address,
                maxLength: 500,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Delivery address',
                  hintText: "e.g. St. Mary's Hall, Kakkanad",
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                onChanged: (_) => _edited(),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? 'Say where the pieces go.'
                    : null,
              ),
              const SizedBox(height: 14),
              RentalPhoneVerifyField(
                controller: _phone,
                verifiedPhone: _verifiedPhone,
                onVerified: (phone) => setState(() {
                  _verifiedPhone = phone;
                  _error = null;
                }),
                onChanged: _edited,
              ),
              // The business's own questions, as on a service booking.
              for (final q in item.questions) ...[
                const SizedBox(height: 14),
                TextFormField(
                  key: ValueKey('booking-answer-${q.id}'),
                  controller: _answers[q.id],
                  maxLength: 1000,
                  decoration: InputDecoration(
                    labelText: q.isRequired ? '${q.prompt} *' : q.prompt,
                    border: const OutlineInputBorder(),
                    counterText: '',
                  ),
                  onChanged: (_) => _edited(),
                  validator: (v) => q.isRequired && (v ?? '').trim().isEmpty
                      ? 'Please answer this.'
                      : null,
                ),
              ],
              if (_count > 0) ...[
                const SizedBox(height: 16),
                Card(
                  key: const ValueKey('booking-money'),
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total ${rupees(_amount)}',
                          key: const ValueKey('booking-total'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _advance > 0
                              ? 'Advance ${rupees(_advance)} now, online · '
                                    '${rupees(_amount - _advance)} before the return'
                              : 'Paid to ${item.card.businessName} before the return',
                          key: const ValueKey('booking-advance'),
                          style: theme.textTheme.bodySmall,
                        ),
                        // How the advance is worked out: a fixed ₹300, or ₹300 a piece × 2.
                        if (_advance > 0)
                          if (rentalAdvanceBasis(
                                widget.item.advanceType,
                                widget.item.advanceAmount,
                                _count,
                              )
                              case final basis?)
                            Text(
                              'Advance: $basis',
                              key: const ValueKey('booking-advance-basis'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.event_busy_rounded,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                rentalBookingCancelLine(
                                  item,
                                  rentalUnits(
                                    item.card.priceType,
                                    _start,
                                    _end,
                                  ),
                                ),
                                key: const ValueKey('booking-cancel-policy'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              PrimaryButton(
                label: _advance > 0 ? 'Book & pay ${rupees(_advance)}' : 'Book',
                onPressed: overLimit || _count < 1 ? null : _book,
                isLoading: _isSaving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The cancellation terms under the booking total, worked out for the dates picked:
/// "If you cancel: 1% for each rental day, 2% for these 2 days", or the steps by time left, or
/// "Free cancellation".
String rentalBookingCancelLine(RentalItemDetail item, int units) {
  if (item.cancelChargeType == RentalCancelChargeType.perRentalDay &&
      item.cancelPercentPerDay != null) {
    final perDay = item.cancelPercentPerDay!;
    final noun = item.cancelUnit == RentalCancelUnit.hour ? 'hour' : 'day';
    final cap = item.maxCancelPercent > 0
        ? item.maxCancelPercent
        : perDay * units;
    final total = rentalPerDayPercent(perDay, units, cap);
    final capped = total < perDay * units;
    return 'If you cancel: ${rentalPercent(perDay)} for each rental $noun, '
        '${rentalPercent(total)} for ${units == 1 ? 'this 1 $noun' : 'these $units ${noun}s'}'
        '${capped ? ' (the most for this item)' : ''} of the order';
  }
  return item.cancelSteps.isEmpty
      ? 'Free cancellation'
      : 'If you cancel: '
            '${rentalCancelPolicy(item.cancelSteps, item.cancelUnit)} of the order';
}
