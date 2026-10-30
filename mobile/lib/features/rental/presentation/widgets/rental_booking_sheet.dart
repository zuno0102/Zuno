import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/router/push_screen.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_form_message_banner.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_form_pickers.dart';
import 'package:zuno/features/customer/presentation/providers/customer_search_filter_provider.dart';
import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/features/rental/domain/entities/rental_payment.dart';
import 'package:zuno/features/rental/presentation/providers/rental_order_providers.dart';
import 'package:zuno/features/rental/presentation/providers/rental_providers.dart';
import 'package:zuno/features/rental/presentation/screens/rental_order_detail_screen.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_availability_line.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_order_form_sheet.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_payment_card.dart';
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
/// where it goes, and the business's questions. The server checks it all again on save.
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
    if (picked != null) setState(() => _dates = picked);
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
    if (picked != null) setState(() => _districtId = picked);
  }

  Future<void> _book() async {
    FocusScope.of(context).unfocus();
    final valid = _formKey.currentState!.validate();
    if (_districtId == null) {
      setState(() => _error = 'Choose the district it goes to.');
      return;
    }
    if (!valid) return;

    final messenger = AppMessenger.of(context);
    final navigator = Navigator.of(context);
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
              answers: {
                for (final entry in _answers.entries)
                  entry.key: entry.value.text,
              },
            ),
          );
      reloadRentals(ref);

      // The item asks an advance: pay it now, while the pieces are held. Closing the window keeps
      // the booking waiting; it can be paid from My rents until the hold runs out.
      if (order.isAwaitingAdvance) {
        if (!mounted) return;
        await payRentalOnline(context, ref, order);
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
                onStep: (delta) => setState(
                  () => _quantity.text = '${(_count + delta).clamp(1, 100000)}',
                ),
                onChanged: () => setState(() {}),
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
                validator: (v) => (v ?? '').trim().isEmpty
                    ? 'Say where the pieces go.'
                    : null,
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
